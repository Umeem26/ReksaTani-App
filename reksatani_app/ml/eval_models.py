#!/usr/bin/env python3
"""Evaluate the ReksaTani TFLite models (router + 3 graders) on a labelled folder of photos.

Why this exists: the repo has no accuracy numbers. Run this on a FROZEN field validation set
(never used for training) to get honest metrics before deciding to keep, fix or retrain the models.

Folder layout (see DATASET_SPEC.md):
    DATA/gabah/A|B|C/*.jpg
    DATA/kopi/A|B|C/*.jpg
    DATA/kelapa_sawit/A|B|C/*.jpg
    DATA/bukan_komoditas/*.jpg            (hard negatives, any subfolders)
File name convention: <id_sampel>__<anything>.jpg  (photos of the same physical sample share id_sampel).

Usage:
    python eval_models.py --data D:/dataset/validation --models ../assets/models
    python eval_models.py --data ... --preprocess crop --metadata metadata.csv --group-by cahaya

Needs: numpy, pillow, and ONE of ai-edge-litert / tflite-runtime / tensorflow.
Caveat: preprocessing here approximates the app (RGB float [0,255], 224x224, bilinear resize).
The app's exact resize differs slightly; a golden-tensor parity test is a separate step.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import sys
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

# ASSUMED class order (alphabetical, as the app code assumes). Unverified: no training notebook exists.
ROUTER_CLASSES = ["bukan_komoditas", "gabah", "kelapa_sawit", "kopi"]
GRADES = ["A", "B", "C"]
COMMODITIES = ["gabah", "kelapa_sawit", "kopi"]
GRADER_FILE = {
    "gabah": "gabah_grader.tflite",
    "kelapa_sawit": "kelapa_sawit_grader.tflite",
    "kopi": "kopi_grader.tflite",
}
ROUTER_FILE = "router_model.tflite"
IMG_EXT = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
THRESHOLDS = [0.50, 0.60, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95]


# ---------------------------------------------------------------- interpreter
def make_interpreter(path: Path):
    try:
        from ai_edge_litert.interpreter import Interpreter  # type: ignore
    except Exception:
        try:
            from tflite_runtime.interpreter import Interpreter  # type: ignore
        except Exception:
            try:
                from tensorflow.lite.python.interpreter import Interpreter  # type: ignore
            except Exception as e:  # pragma: no cover
                sys.exit("No TFLite interpreter found. Install one of: ai-edge-litert, tflite-runtime, tensorflow. "
                         f"({e})")
    it = Interpreter(model_path=str(path))
    it.allocate_tensors()
    inp = it.get_input_details()[0]
    if list(inp["shape"]) != [1, 224, 224, 3]:
        sys.exit(f"{path.name}: unexpected input shape {inp['shape']} (expected [1,224,224,3])")
    return it


def run_model(it, x: np.ndarray) -> np.ndarray:
    inp = it.get_input_details()[0]
    out = it.get_output_details()[0]
    it.set_tensor(inp["index"], x.astype(inp["dtype"]))
    it.invoke()
    p = it.get_tensor(out["index"])[0].astype(np.float64)
    if not (abs(p.sum() - 1.0) < 1e-3 and p.min() >= 0):  # not probabilities -> softmax
        e = np.exp(p - p.max())
        p = e / e.sum()
    return p


# ---------------------------------------------------------------- data
def load_image(path: Path, mode: str) -> np.ndarray:
    im = Image.open(path)
    im = ImageOps.exif_transpose(im).convert("RGB")
    if mode == "crop":
        w, h = im.size
        s = min(w, h)
        l, t = (w - s) // 2, (h - s) // 2
        im = im.crop((l, t, l + s, t + s))
    im = im.resize((224, 224), Image.BILINEAR)
    return np.asarray(im, dtype=np.float32)[None, ...]  # float RGB in [0,255]


def sample_id_of(path: Path) -> str:
    stem = path.stem
    return stem.split("__")[0] if "__" in stem else stem


def scan_dataset(root: Path):
    samples = []
    for p in sorted(root.rglob("*")):
        if not p.is_file() or p.suffix.lower() not in IMG_EXT:
            continue
        rel = p.relative_to(root).parts
        top = rel[0]
        if top == "bukan_komoditas":
            samples.append(dict(path=p, router="bukan_komoditas", grade=None, sid=sample_id_of(p)))
        elif top in COMMODITIES and len(rel) >= 3 and rel[1] in GRADES:
            samples.append(dict(path=p, router=top, grade=rel[1], sid=sample_id_of(p)))
        else:
            print(f"[skip] unexpected location: {p}", file=sys.stderr)
    return samples


# ---------------------------------------------------------------- metrics
def wilson(k: int, n: int, z: float = 1.96):
    if n == 0:
        return (float("nan"), float("nan"))
    ph = k / n
    d = 1 + z * z / n
    c = (ph + z * z / (2 * n)) / d
    h = z * math.sqrt(ph * (1 - ph) / n + z * z / (4 * n * n)) / d
    return (max(0.0, c - h), min(1.0, c + h))


def confusion(y_true, y_pred, labels):
    idx = {l: i for i, l in enumerate(labels)}
    m = np.zeros((len(labels), len(labels)), dtype=int)
    for t, p in zip(y_true, y_pred):
        m[idx[t], idx[p]] += 1
    return m


def prf(m: np.ndarray, labels):
    rows = []
    for i, l in enumerate(labels):
        tp = m[i, i]
        fn = m[i].sum() - tp
        fp = m[:, i].sum() - tp
        n = m[i].sum()
        rec = tp / n if n else float("nan")
        prec = tp / (tp + fp) if (tp + fp) else float("nan")
        f1 = 2 * prec * rec / (prec + rec) if (prec + rec) and not math.isnan(prec) and not math.isnan(rec) else float("nan")
        lo, hi = wilson(int(tp), int(n))
        rows.append(dict(label=l, n=int(n), recall=rec, precision=prec, f1=f1, recall_ci=(lo, hi)))
    return rows


def macro_f1(rows):
    v = [r["f1"] for r in rows if not math.isnan(r["f1"])]
    return float(np.mean(v)) if v else float("nan")


def ece(conf, correct, bins: int = 10):
    conf = np.asarray(conf, dtype=float)
    correct = np.asarray(correct, dtype=float)
    if len(conf) == 0:
        return float("nan")
    edges = np.linspace(0, 1, bins + 1)
    total = 0.0
    for i in range(bins):
        mask = (conf > edges[i]) & (conf <= edges[i + 1]) if i else (conf >= edges[i]) & (conf <= edges[i + 1])
        if mask.any():
            total += mask.mean() * abs(correct[mask].mean() - conf[mask].mean())
    return float(total)


def fmt_matrix(m, labels, title):
    w = max(len(l) for l in labels + ["true\\pred"]) + 1
    lines = [f"**{title}** (rows = true, columns = predicted)", "", "```"]
    lines.append("true\\pred".ljust(w) + "".join(l.rjust(w) for l in labels))
    for i, l in enumerate(labels):
        lines.append(l.ljust(w) + "".join(str(m[i, j]).rjust(w) for j in range(len(labels))))
    lines.append("```")
    return "\n".join(lines)


def fmt_pct(x):
    return "n/a" if x is None or (isinstance(x, float) and math.isnan(x)) else f"{100 * x:.1f}%"


def fmt_rows(rows):
    out = ["| class | n | recall (95% CI) | precision | F1 |", "|---|---|---|---|---|"]
    for r in rows:
        lo, hi = r["recall_ci"]
        ci = "n/a" if math.isnan(lo) else f"{fmt_pct(r['recall'])} ({fmt_pct(lo)} to {fmt_pct(hi)})"
        warn = " (n<30, CI too wide)" if 0 < r["n"] < 30 else ""
        out.append(f"| {r['label']} | {r['n']}{warn} | {ci} | {fmt_pct(r['precision'])} | {fmt_pct(r['f1'])} |")
    return "\n".join(out)



def sample_level_section(recs):
    """Majority vote per id_sampel. Photos of the same physical sample are near-duplicates, so the number of
    independent observations is the number of distinct samples, not the number of photos."""
    from collections import Counter
    lines = ["## Sample-level view (majority vote per id_sampel)", "",
             "Photos from one sample look alike, so the effective n is the number of samples. "
             "Wilson intervals below are computed on samples, not photos.", "",
             "| task | class | samples | majority-vote correct (95% CI) |", "|---|---|---|---|"]
    def block(task, sub, truth, pred):
        by = defaultdict(list)
        for r in sub:
            by[(truth(r), r["sid"])].append(pred(r))
        per_class = defaultdict(lambda: [0, 0])
        for (t, _sid), preds in by.items():
            top = Counter(preds).most_common(1)[0][0]
            per_class[t][1] += 1
            per_class[t][0] += int(top == t)
        for t, (k, n) in sorted(per_class.items()):
            lo, hi = wilson(k, n)
            warn = " (n<30)" if n < 30 else ""
            lines.append(f"| {task} | {t} | {n}{warn} | {k}/{n} = {fmt_pct(k / n)} ({fmt_pct(lo)} to {fmt_pct(hi)}) |")
    block("router", recs, lambda r: r["router"], lambda r: r["r_pred"])
    for c in COMMODITIES:
        sub = [r for r in recs if r["router"] == c and r["grade"]]
        if sub:
            block(f"grader {c}", sub, lambda r: r["grade"], lambda r, c=c: GRADES[int(np.argmax(r["gp"][c]))])
    return "\n".join(lines) + "\n"

# ---------------------------------------------------------------- near-duplicate check
def dhash(path: Path) -> int:
    im = Image.open(path)
    im = ImageOps.exif_transpose(im).convert("L").resize((9, 8), Image.BILINEAR)
    a = np.asarray(im, dtype=np.int16)
    bits = (a[:, 1:] > a[:, :-1]).flatten()
    return int("".join("1" if b else "0" for b in bits), 2)


def near_duplicates(samples, max_hamming=8, limit=25):
    hs = [dhash(s["path"]) for s in samples]
    pairs = []
    for i in range(len(samples)):
        for j in range(i + 1, len(samples)):
            if samples[i]["sid"] == samples[j]["sid"]:
                continue  # same physical sample is expected to look alike
            d = bin(hs[i] ^ hs[j]).count("1")
            if d <= max_hamming:
                pairs.append((d, str(samples[i]["path"]), str(samples[j]["path"])))
    pairs.sort()
    return len(pairs), pairs[:limit]


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data", required=True, type=Path, help="labelled photo folder (see DATASET_SPEC.md)")
    ap.add_argument("--models", type=Path, default=Path(__file__).resolve().parent.parent / "assets" / "models")
    ap.add_argument("--preprocess", choices=["squash", "crop"], default="squash",
                    help="squash = resize whole image to 224x224 (app default); crop = centre square crop first")
    ap.add_argument("--out", type=Path, default=None, help="output folder (default: ml/reports/<timestamp>)")
    ap.add_argument("--metadata", type=Path, default=None, help="optional CSV with a 'file' column (relative path)")
    ap.add_argument("--group-by", default=None, help="metadata column to break results down by (e.g. cahaya, perangkat)")
    ap.add_argument("--no-dup-check", action="store_true")
    args = ap.parse_args()

    samples = scan_dataset(args.data)
    if not samples:
        sys.exit(f"No images found under {args.data}")
    out_dir = args.out or (Path(__file__).resolve().parent / "reports" / time.strftime("%Y%m%d-%H%M%S"))
    out_dir.mkdir(parents=True, exist_ok=True)

    router = make_interpreter(args.models / ROUTER_FILE)
    graders = {c: make_interpreter(args.models / f) for c, f in GRADER_FILE.items()}

    meta = {}
    if args.metadata:
        with open(args.metadata, newline="", encoding="utf-8-sig") as fh:
            for row in csv.DictReader(fh):
                meta[row["file"].replace("\\", "/")] = row

    # ---- inference
    recs = []
    for k, s in enumerate(samples, 1):
        x = load_image(s["path"], args.preprocess)
        rp = run_model(router, x)
        gp = {c: run_model(graders[c], x) for c in COMMODITIES}
        rel = str(s["path"].relative_to(args.data)).replace("\\", "/")
        recs.append(dict(s, rel=rel, rp=rp, gp=gp, meta=meta.get(rel, {})))
        if k % 25 == 0:
            print(f"  {k}/{len(samples)}", file=sys.stderr)

    for r in recs:
        r["r_pred"] = ROUTER_CLASSES[int(np.argmax(r["rp"]))]
        r["r_conf"] = float(np.max(r["rp"]))

    # ---- router metrics
    r_true = [r["router"] for r in recs]
    r_pred = [r["r_pred"] for r in recs]
    r_m = confusion(r_true, r_pred, ROUTER_CLASSES)
    r_rows = prf(r_m, ROUTER_CLASSES)
    r_acc = float(np.mean([t == p for t, p in zip(r_true, r_pred)]))
    r_ece = ece([r["r_conf"] for r in recs], [t == p for t, p in zip(r_true, r_pred)])

    # ---- grader metrics (oracle: grader of the TRUE commodity, so router errors do not hide grader quality)
    g_sections, g_json = [], {}
    over_total, over_n = 0, 0
    for c in COMMODITIES:
        sub = [r for r in recs if r["router"] == c and r["grade"]]
        if not sub:
            continue
        gt = [r["grade"] for r in sub]
        gpred = [GRADES[int(np.argmax(r["gp"][c]))] for r in sub]
        m = confusion(gt, gpred, GRADES)
        rows = prf(m, GRADES)
        acc = float(np.mean([a == b for a, b in zip(gt, gpred)]))
        e = ece([float(np.max(r["gp"][c])) for r in sub], [a == b for a, b in zip(gt, gpred)])
        over = sum(1 for a, b in zip(gt, gpred) if GRADES.index(b) < GRADES.index(a))  # predicted better than truth
        over_total += over
        over_n += len(sub)
        a_for_bc = sum(1 for a, b in zip(gt, gpred) if a in ("B", "C") and b == "A")
        bc_n = sum(1 for a in gt if a in ("B", "C"))
        g_sections.append(
            f"### Grader: {c}\n\nn = {len(sub)}, accuracy = {fmt_pct(acc)}, macro-F1 = {fmt_pct(macro_f1(rows))}, "
            f"ECE = {e:.3f}\n\nOver-grading (predicted better than truth): **{over}/{len(sub)} = {fmt_pct(over / len(sub))}**; "
            f"true B/C predicted as A: **{a_for_bc}/{bc_n}**\n\n{fmt_matrix(m, GRADES, 'Confusion ' + c)}\n\n{fmt_rows(rows)}")
        g_json[c] = dict(n=len(sub), accuracy=acc, macro_f1=macro_f1(rows), ece=e, over_grade=over,
                         confusion=m.tolist())

    # ---- end-to-end accept sweep: router commodity + both confidences >= t
    sweep = ["| threshold | accepted | coverage (commodity photos) | end-to-end correct among accepted | "
             "over-graded among accepted | negatives falsely accepted |", "|---|---|---|---|---|---|"]
    pos = [r for r in recs if r["router"] in COMMODITIES and r["grade"]]
    neg = [r for r in recs if r["router"] == "bukan_komoditas"]
    for t in THRESHOLDS:
        acc_pos, ok, over = 0, 0, 0
        for r in pos:
            if r["r_pred"] in COMMODITIES and r["r_conf"] >= t:
                g = r["gp"][r["r_pred"]]
                gp_ = GRADES[int(np.argmax(g))]
                if float(np.max(g)) >= t:
                    acc_pos += 1
                    ok += int(r["r_pred"] == r["router"] and gp_ == r["grade"])
                    if r["r_pred"] == r["router"] and GRADES.index(gp_) < GRADES.index(r["grade"]):
                        over += 1
        fa = 0
        for r in neg:
            if r["r_pred"] in COMMODITIES and r["r_conf"] >= t and float(np.max(r["gp"][r["r_pred"]])) >= t:
                fa += 1
        sweep.append(f"| {t:.2f} | {acc_pos} | {fmt_pct(acc_pos / len(pos)) if pos else 'n/a'} | "
                     f"{fmt_pct(ok / acc_pos) if acc_pos else 'n/a'} | {fmt_pct(over / acc_pos) if acc_pos else 'n/a'} | "
                     f"{fa}/{len(neg)} ({fmt_pct(fa / len(neg)) if neg else 'n/a'}) |")

    # ---- group-by breakdown
    grp_txt = ""
    if args.group_by:
        buckets = defaultdict(list)
        for r in recs:
            buckets[r["meta"].get(args.group_by, "(no metadata)")].append(r)
        lines = [f"## Breakdown by `{args.group_by}`", "", "| group | n | router accuracy | grade accuracy (true commodity grader) |",
                 "|---|---|---|---|"]
        for gname, rs in sorted(buckets.items()):
            ra = np.mean([x["router"] == x["r_pred"] for x in rs])
            gs = [x for x in rs if x["grade"]]
            ga = np.mean([GRADES[int(np.argmax(x["gp"][x["router"]]))] == x["grade"] for x in gs]) if gs else float("nan")
            lines.append(f"| {gname} | {len(rs)} | {fmt_pct(ra)} | {fmt_pct(ga)} |")
        grp_txt = "\n".join(lines) + "\n"

    # ---- duplicates
    dup_txt = ""
    if not args.no_dup_check:
        n_pairs, top = near_duplicates(samples)
        dup_txt = f"## Near-duplicate check (dHash, Hamming <= 8, different id_sampel)\n\nPairs found: **{n_pairs}**\n"
        if top:
            dup_txt += "\n```\n" + "\n".join(f"d={d}  {a}  <->  {b}" for d, a, b in top) + "\n```\n"
            dup_txt += "\nIf pairs appear, the same photo may sit under two ids. Fix the ids (or drop one) before trusting any number.\n"

    # ---- counts
    counts = defaultdict(int)
    for r in recs:
        counts[(r["router"], r["grade"] or "-")] += 1
    count_lines = ["| commodity | grade | images | distinct samples |", "|---|---|---|---|"]
    for (c, g), n in sorted(counts.items()):
        sids = len({r["sid"] for r in recs if r["router"] == c and (r["grade"] or "-") == g})
        flag = "  (below 30)" if n < 30 and c != "bukan_komoditas" else ""
        count_lines.append(f"| {c} | {g} | {n}{flag} | {sids} |")

    report = [
        "# ReksaTani model evaluation",
        "",
        f"- Data: `{args.data}` ({len(recs)} images), preprocess = `{args.preprocess}`, input = RGB float [0,255], 224x224",
        f"- Models: `{args.models}`",
        f"- Router class order ASSUMED: {ROUTER_CLASSES}; grader order ASSUMED: {GRADES} (no training notebook exists to confirm)",
        "- Read the numbers with their confidence intervals. Small n means wide intervals. No claim without a frozen field set.",
        "",
        "## Data counts", "", "\n".join(count_lines), "",
        "## Router (4 classes)", "",
        f"accuracy = {fmt_pct(r_acc)}, macro-F1 = {fmt_pct(macro_f1(r_rows))}, ECE = {r_ece:.3f}", "",
        fmt_matrix(r_m, ROUTER_CLASSES, "Confusion router"), "", fmt_rows(r_rows), "",
        "## Graders (oracle commodity)", "", "\n\n".join(g_sections) if g_sections else "_no graded images_", "",
        f"Overall over-grading rate (money risk): **{over_total}/{over_n} = {fmt_pct(over_total / over_n) if over_n else 'n/a'}**", "",
        "## Auto-accept sweep (router conf and grader conf both >= threshold)", "", "\n".join(sweep), "",
        sample_level_section(recs), grp_txt, dup_txt,
    ]
    (out_dir / "report.md").write_text("\n".join(report), encoding="utf-8")

    with open(out_dir / "predictions.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["file", "id_sampel", "true_router", "true_grade", "router_pred", "router_conf"]
                   + [f"p_{c}" for c in ROUTER_CLASSES] + [f"grade_{c}_pred" for c in COMMODITIES]
                   + [f"grade_{c}_conf" for c in COMMODITIES])
        for r in recs:
            w.writerow([r["rel"], r["sid"], r["router"], r["grade"] or "", r["r_pred"], f"{r['r_conf']:.4f}"]
                       + [f"{p:.4f}" for p in r["rp"]]
                       + [GRADES[int(np.argmax(r["gp"][c]))] for c in COMMODITIES]
                       + [f"{float(np.max(r['gp'][c])):.4f}" for c in COMMODITIES])
    (out_dir / "metrics.json").write_text(json.dumps(dict(
        n=len(recs), preprocess=args.preprocess, router_accuracy=r_acc, router_macro_f1=macro_f1(r_rows),
        router_ece=r_ece, router_confusion=r_m.tolist(), graders=g_json,
        over_grade_rate=(over_total / over_n if over_n else None)), indent=2), encoding="utf-8")
    print(f"Report written to {out_dir / 'report.md'}")


if __name__ == "__main__":
    main()
