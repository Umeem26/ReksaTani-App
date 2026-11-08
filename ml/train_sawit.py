"""Latih ulang grader sawit dari dataset publik (Suharjito & Junior, CC BY 4.0). DRAF / PROXY.

Jalankan di Colab atau mesin dengan TensorFlow >= 2.16 (Keras 3):
    python train_sawit.py --zips data_public --work runs/sawit

Desain (alasan di README.md bagian "Latih ulang sawit"):
  * Satu sampel = satu KOTAK anotasi (satu tandan) yang dipotong dari frame, bukan seluruh frame.
    Dengan begini video campuran ikut terpakai dan kelas A (TBS masak) punya cukup video.
  * Split per VIDEO (bukan per frame) dengan 3 kelompok train/valid/test, dipilih dari 300 seed
    agar proporsi kelas A/B/C tiap kelompok paling dekat target. Frame satu video tidak pernah terpisah.
  * Pemetaan kelas dataset -> A/B/C = MAPPING (DRAF rubrik v0.1, belum disahkan ahli).
  * Kontrak input aplikasi: float32 RGB 0-255, 224x224. Penskalaan ke [-1,1] ada DI DALAM model.
  * Urutan keluaran model TETAP A, B, C (labels.txt ikut diekspor).
Hasil: metrik per kotak dan per video + CI Wilson, matriks kebingungan, galat berisiko uang (prediksi
lebih tinggi dari aslinya), temperature scaling, ekspor TFLite float32, report.md.
"""
import argparse, collections, io, json, math, random, re, zipfile
from pathlib import Path

import numpy as np
from PIL import Image

CLASS_NAMES = ["Janjang kosong", "Kurang masak", "TBS abnormal", "TBS masak", "TBS mentah", "Terlalu masak"]
MAPPING = {"TBS masak": "A", "Kurang masak": "B", "Terlalu masak": "B",
           "TBS mentah": "C", "Janjang kosong": "C", "TBS abnormal": "C"}
GRADES = ["A", "B", "C"]
TARGET_SPLIT = {"train": 0.70, "valid": 0.15, "test": 0.15}
IMG = 224
PAD = 0.10          # tambahan konteks di sekeliling kotak
MIN_SIDE = 48       # piksel, kotak lebih kecil dibuang


def wilson(k: int, n: int, z: float = 1.96):
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, c - h), min(1.0, c + h))


def collect_boxes(zips: Path, limit_per_zip: int = 0):
    """-> list of dict(vid, zip, jpg, grade, box=(cx,cy,w,h))"""
    boxes = []
    for part in ("train", "valid", "test"):
        zp = zips / f"{part}_rev2.zip"
        if not zp.exists():
            print(f"[lewati] tidak ada {zp}")
            continue
        with zipfile.ZipFile(zp) as zf:
            names = set(zf.namelist())
            jpgs = sorted(n for n in names if n.endswith(".jpg"))
            if limit_per_zip:
                jpgs = jpgs[:limit_per_zip]
            for n in jpgs:
                m = re.match(r".*/(.+?)--(\d+)-_png", n)
                txt = n[:-4] + ".txt"
                if not m or txt not in names:
                    continue
                for line in zf.read(txt).decode().splitlines():
                    p = line.split()
                    if len(p) < 5:
                        continue
                    grade = MAPPING[CLASS_NAMES[int(p[0])]]
                    boxes.append(dict(vid=m.group(1), zip=str(zp), jpg=n, grade=grade,
                                      box=tuple(float(x) for x in p[1:5])))
    return boxes


def choose_split(boxes, tries: int = 300):
    vids = sorted({b["vid"] for b in boxes})
    per_vid = collections.defaultdict(collections.Counter)
    for b in boxes:
        per_vid[b["vid"]][b["grade"]] += 1
    total = collections.Counter(b["grade"] for b in boxes)
    best = None
    for seed in range(tries):
        rnd = random.Random(seed)
        order = vids[:]
        rnd.shuffle(order)
        n = len(order)
        cut1, cut2 = int(n * TARGET_SPLIT["train"]), int(n * (TARGET_SPLIT["train"] + TARGET_SPLIT["valid"]))
        assign = {}
        for i, v in enumerate(order):
            assign[v] = "train" if i < cut1 else ("valid" if i < cut2 else "test")
        cnt = {s: collections.Counter() for s in TARGET_SPLIT}
        for v, c in per_vid.items():
            cnt[assign[v]].update(c)
        score, ok = 0.0, True
        for s, tgt in TARGET_SPLIT.items():
            for g in GRADES:
                if cnt[s][g] == 0:
                    ok = False
                score += abs(cnt[s][g] / max(1, total[g]) - tgt)
        if ok and (best is None or score < best[0]):
            best = (score, seed, assign)
    if best is None:
        raise SystemExit("tidak ada split yang memuat semua kelas di tiap kelompok; tambah data")
    return best[2], best[1]


def write_crops(boxes, assign, out: Path):
    if out.exists():
        import shutil
        shutil.rmtree(out)
    opened = {}
    counters = collections.Counter()
    for b in boxes:
        zf = opened.setdefault(b["zip"], zipfile.ZipFile(b["zip"]))
        im = Image.open(io.BytesIO(zf.read(b["jpg"]))).convert("RGB")
        W, H = im.size
        cx, cy, w, h = b["box"]
        x0, x1 = (cx - w / 2) * W, (cx + w / 2) * W
        y0, y1 = (cy - h / 2) * H, (cy + h / 2) * H
        px, py = (x1 - x0) * PAD, (y1 - y0) * PAD
        x0, y0, x1, y1 = max(0, x0 - px), max(0, y0 - py), min(W, x1 + px), min(H, y1 + py)
        if min(x1 - x0, y1 - y0) < MIN_SIDE:
            continue
        crop = im.crop((int(x0), int(y0), int(x1), int(y1))).resize((IMG, IMG), Image.BILINEAR)
        split = assign[b["vid"]]
        d = out / split / b["grade"]
        d.mkdir(parents=True, exist_ok=True)
        counters[(split, b["grade"])] += 1
        crop.save(d / f'{b["vid"]}__{counters[(split, b["grade"])]}.jpg', quality=92)
    for zf in opened.values():
        zf.close()
    return counters


def build_models(weights):
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras import layers
    base = keras.applications.MobileNetV2(input_shape=(IMG, IMG, 3), include_top=False,
                                          weights=weights, pooling="avg")
    inp = keras.Input((IMG, IMG, 3), dtype="float32", name="rgb_0_255")
    x = layers.Rescaling(1 / 127.5, offset=-1.0)(inp)
    x = base(x)
    x = layers.Dropout(0.3)(x)
    out = layers.Dense(3, activation="softmax", name="grade_ABC")(x)
    core = keras.Model(inp, out, name="grader_sawit")
    aug = keras.Sequential([
        layers.RandomFlip("horizontal_and_vertical"), layers.RandomRotation(0.08),
        layers.RandomZoom(0.15), layers.RandomContrast(0.2),
        layers.RandomBrightness(0.2, value_range=(0, 255)),
    ])
    t_in = keras.Input((IMG, IMG, 3), dtype="float32")
    train_model = keras.Model(t_in, core(aug(t_in)))
    return core, train_model, base


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--zips", type=Path, default=Path("data_public"))
    ap.add_argument("--work", type=Path, default=Path("runs/sawit"))
    ap.add_argument("--epochs-head", type=int, default=5)
    ap.add_argument("--epochs-ft", type=int, default=10)
    ap.add_argument("--weights", default="imagenet", help="imagenet atau none (smoke test)")
    ap.add_argument("--limit-per-zip", type=int, default=0, help="batasi jumlah frame per zip (smoke test)")
    ap.add_argument("--seed", type=int, default=0)
    a = ap.parse_args()

    import tensorflow as tf
    from tensorflow import keras
    tf.keras.utils.set_random_seed(a.seed)
    a.work.mkdir(parents=True, exist_ok=True)
    weights = None if a.weights == "none" else "imagenet"

    boxes = collect_boxes(a.zips, a.limit_per_zip)
    assign, split_seed = choose_split(boxes)
    counters = write_crops(boxes, assign, a.work / "crops")
    print("split seed", split_seed)
    sizes = {s: {g: counters[(s, g)] for g in GRADES} for s in TARGET_SPLIT}
    vids_per_split = {s: len({v for v, sp in assign.items() if sp == s}) for s in TARGET_SPLIT}
    print("kotak per split/kelas", sizes, "video per split", vids_per_split)

    def ds(split, shuffle):
        return keras.utils.image_dataset_from_directory(
            a.work / "crops" / split, class_names=GRADES, label_mode="categorical",
            image_size=(IMG, IMG), batch_size=32, shuffle=shuffle, seed=a.seed)

    d_train, d_val, d_test = ds("train", True), ds("valid", False), ds("test", False)
    n_tr = np.array([sizes["train"][g] for g in GRADES], float)
    cw = {i: float(n_tr.sum() / (3 * max(1, n_tr[i]))) for i in range(3)}

    core, model, base = build_models(weights)
    loss = keras.losses.CategoricalCrossentropy(label_smoothing=0.1)
    base.trainable = False
    model.compile(keras.optimizers.Adam(1e-3), loss=loss, metrics=["accuracy"])
    cb = [keras.callbacks.EarlyStopping(patience=3, restore_best_weights=True, monitor="val_loss")]
    if a.epochs_head:
        model.fit(d_train, validation_data=d_val, epochs=a.epochs_head, class_weight=cw, callbacks=cb)
    if a.epochs_ft:
        base.trainable = True
        for l in base.layers[:-30]:
            l.trainable = False
        model.compile(keras.optimizers.Adam(1e-5), loss=loss, metrics=["accuracy"])
        model.fit(d_train, validation_data=d_val, epochs=a.epochs_ft, class_weight=cw, callbacks=cb)

    # ---- evaluasi
    def probs(dset):
        return np.concatenate([core.predict(x, verbose=0) for x, _ in dset])

    def labels(dset):
        return np.concatenate([y.numpy().argmax(1) for _, y in dset])

    pv, yv = probs(d_val), labels(d_val)
    # temperature scaling di validasi (grid), log p ~ logit sampai konstanta
    lv = np.log(np.clip(pv, 1e-9, 1))
    best_T, best_nll = 1.0, 1e9
    for T in np.arange(0.5, 5.01, 0.05):
        z = lv / T
        z = z - z.max(1, keepdims=True)
        p = np.exp(z) / np.exp(z).sum(1, keepdims=True)
        nll = -np.log(np.clip(p[np.arange(len(yv)), yv], 1e-9, 1)).mean()
        if nll < best_nll:
            best_T, best_nll = float(T), float(nll)

    pt, yt = probs(d_test), labels(d_test)
    files = [Path(f).name for f in d_test.file_paths]
    vid_of = [f.split("__")[0] for f in files]
    pred = pt.argmax(1)
    conf = np.zeros((3, 3), int)
    for t, p in zip(yt, pred):
        conf[t, p] += 1
    n = len(yt)
    acc = float((pred == yt).mean())
    recalls = [conf[i, i] / max(1, conf[i].sum()) for i in range(3)]
    precs = [conf[i, i] / max(1, conf[:, i].sum()) for i in range(3)]
    f1 = [2 * p * r / (p + r) if p + r else 0 for p, r in zip(precs, recalls)]
    over = int(sum(conf[t, p] for t in range(3) for p in range(3) if p < t))  # indeks kecil = grade tinggi
    # per video: rata-rata probabilitas
    byv = collections.defaultdict(list)
    for v, p, t in zip(vid_of, pt, yt):
        byv[v].append((p, t))
    vid_rows = []
    for v, l in byv.items():
        mp = np.mean([p for p, _ in l], 0)
        tc = collections.Counter(t for _, t in l).most_common(1)[0][0]
        vid_rows.append((v, int(mp.argmax()), int(tc), len(l)))
    vk = sum(1 for _, p, t, _ in vid_rows if p == t)

    metrics = dict(n_test_crops=n, accuracy=acc, accuracy_wilson95=wilson(int((pred == yt).sum()), n),
                   macro_f1=float(np.mean(f1)), recall=dict(zip(GRADES, map(float, recalls))),
                   confusion_rows_true_cols_pred=conf.tolist(), over_grade_count=over,
                   over_grade_rate=over / max(1, n), n_test_videos=len(vid_rows), video_accuracy=vk / max(1, len(vid_rows)),
                   video_accuracy_wilson95=wilson(vk, len(vid_rows)), temperature=best_T,
                   split_seed=split_seed, kotak_per_split=sizes, video_per_split=vids_per_split,
                   class_weights=cw, mapping=MAPPING)
    (a.work / "metrics.json").write_text(json.dumps(metrics, indent=2))

    # ---- ekspor TFLite + cek paritas
    conv = tf.lite.TFLiteConverter.from_keras_model(core)
    tfl = conv.convert()
    (a.work / "kelapa_sawit_grader.tflite").write_bytes(tfl)
    (a.work / "labels.txt").write_text("\n".join(GRADES) + "\n")
    it = tf.lite.Interpreter(model_content=tfl)
    it.allocate_tensors()
    i0, o0 = it.get_input_details()[0]["index"], it.get_output_details()[0]["index"]
    xb, _ = next(iter(d_test))
    diffs = []
    for k in range(min(5, len(xb))):
        it.set_tensor(i0, xb[k:k + 1].numpy())
        it.invoke()
        diffs.append(float(np.abs(it.get_tensor(o0)[0] - core.predict(xb[k:k + 1], verbose=0)[0]).max()))
    parity = max(diffs) if diffs else float("nan")

    lines = ["# Latih ulang grader sawit (PROXY, bukan validasi lapangan)", "",
             f"Split per video, seed {split_seed}. Video per kelompok: {vids_per_split}. Kotak per kelompok/kelas: {sizes}.",
             "Pemetaan kelas -> A/B/C = DRAF rubrik v0.1 (belum disahkan ahli). Foto = pabrik, bukan petani.", "",
             f"## Uji (kotak, n={n}; terlalu optimis karena kotak dari video yang sama berkorelasi)",
             f"- Akurasi {acc:.3f}, CI Wilson 95% {metrics['accuracy_wilson95'][0]:.3f}-{metrics['accuracy_wilson95'][1]:.3f}",
             f"- Macro-F1 {np.mean(f1):.3f}; recall A/B/C = {recalls[0]:.2f}/{recalls[1]:.2f}/{recalls[2]:.2f}",
             f"- Galat berisiko uang (prediksi lebih tinggi dari asli): {over} dari {n} ({over / max(1, n):.3%})",
             "- Matriks kebingungan (baris=asli A,B,C; kolom=prediksi):", "```", str(conf), "```", "",
             f"## Per video (n={len(vid_rows)}; sampel efektif)",
             f"- Akurasi video {vk}/{len(vid_rows)} = {vk / max(1, len(vid_rows)):.3f}, CI Wilson 95% {metrics['video_accuracy_wilson95'][0]:.3f}-{metrics['video_accuracy_wilson95'][1]:.3f}", "",
             f"## Kalibrasi: temperature T = {best_T:.2f} (dari validasi; terapkan sebelum membaca keyakinan)",
             f"## Ekspor: kelapa_sawit_grader.tflite (urutan A,B,C). Selisih maks TFLite vs Keras = {parity:.2e}", "",
             "Batas: sampel efektif = video; kelas A sedikit; domain pabrik; klaim hanya 'proxy'."]
    (a.work / "report.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
