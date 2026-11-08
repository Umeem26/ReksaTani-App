"""Segmentasi biji kopi hijau pada latar polos (pengolahan citra klasik, tanpa pelatihan).

Keluaran per foto: jumlah biji, fraksi biji gelap, fraksi biji kecil/pecah.
Uji awal pada CBD (acuan: ~50 biji per foto). Ambang adalah DRAF, bukan standar.
"""
import argparse, csv, io, zipfile
import cv2
import numpy as np

W = 1000  # lebar kerja (px)


def load(buf: bytes) -> np.ndarray:
    img = cv2.imdecode(np.frombuffer(buf, np.uint8), cv2.IMREAD_REDUCED_COLOR_2)
    h, w = img.shape[:2]
    return cv2.resize(img, (W, int(h * W / w)), interpolation=cv2.INTER_AREA)


def segment(img: np.ndarray):
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB).astype(np.float32)
    bg = np.stack([cv2.medianBlur(lab[..., c].astype(np.uint8), 121) for c in range(3)], -1).astype(np.float32)
    d = lab - bg
    diff = np.sqrt(d[..., 0] ** 2 + 2.0 * d[..., 1] ** 2 + 2.0 * d[..., 2] ** 2)
    diff = cv2.GaussianBlur(diff, (0, 0), 1.5)
    diff8 = np.clip(diff * 4, 0, 255).astype(np.uint8)
    t, mask = cv2.threshold(diff8, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, k)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, k)
    # isi lubang (alur biji)
    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    filled = np.zeros_like(mask)
    cv2.drawContours(filled, cnts, -1, 255, -1)
    return filled, lab


def split_touching(filled: np.ndarray):
    dist = cv2.distanceTransform(filled, cv2.DIST_L2, 5)
    if dist.max() == 0:
        return np.zeros(filled.shape, np.int32), 0
    _, fg = cv2.threshold(dist, 0.5 * dist.max() * 0.6, 255, cv2.THRESH_BINARY)
    fg = fg.astype(np.uint8)
    n, markers = cv2.connectedComponents(fg)
    markers = markers + 1
    markers[(filled > 0) & (fg == 0)] = 0
    markers[filled == 0] = 1
    ws = cv2.watershed(cv2.cvtColor(filled, cv2.COLOR_GRAY2BGR), markers.astype(np.int32))
    ws[ws == 1] = 0
    ws[ws == -1] = 0
    return ws, n


def analyse(img):
    filled, lab = segment(img)
    ws, _ = split_touching(filled)
    ids = [i for i in np.unique(ws) if i > 1]
    beans = []
    for i in ids:
        m = ws == i
        a = int(m.sum())
        beans.append((i, a, float(lab[..., 0][m].mean()), m))
    if not beans:
        return [], ws
    areas = np.array([b[1] for b in beans])
    med = np.median(areas)
    keep = [b for b in beans if 0.25 * med <= b[1] <= 3.0 * med]
    return keep, ws


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--zip", required=True)
    ap.add_argument("--out", default="reports/coffee_cv_cbd.csv")
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()
    z = zipfile.ZipFile(a.zip)
    names = sorted(n for n in z.namelist() if n.lower().endswith(".jpg"))
    if a.limit:
        names = names[:: max(1, len(names) // a.limit)][: a.limit]
    rows = []
    for n in names:
        img = load(z.read(n))
        beans, _ = analyse(img)
        L = np.array([b[2] for b in beans]) if beans else np.array([])
        areas = np.array([b[1] for b in beans]) if beans else np.array([])
        medL = float(np.median(L)) if len(L) else 0
        medA = float(np.median(areas)) if len(areas) else 0
        rows.append({
            "file": n.split("CBD_Coffee Bean Dataset/")[-1],
            "cls": n.split("/")[-2],
            "count": len(beans),
            "medL": round(medL, 1),
            "dark_abs": int((L < 60).sum()) if len(L) else 0,
            "dark_rel": int((L < medL - 25).sum()) if len(L) else 0,
            "small": int((areas < 0.5 * medA).sum()) if len(areas) else 0,
        })
    with open(a.out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader(); w.writerows(rows)
    print("rows", len(rows), "->", a.out)


if __name__ == "__main__":
    main()
