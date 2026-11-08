"""Bangun set uji sawit dari dataset publik Suharjito & Junior (CC BY 4.0).

Sumber : Science Data Bank, DOI 10.57760/sciencedb.j00001.00713
         Junior et al., Scientific Data 10, 72 (2023)
Input  : train_rev2.zip, valid_rev2.zip, test_rev2.zip (format Roboflow/YOLO) di data_public/
Output : <out>/kelapa_sawit/{A,B,C}/<id_sampel>__<frame>.jpg  (siap untuk eval_models.py)

Yang dilakukan:
  1. Hanya memakai VIDEO yang seluruh kotak anotasinya satu kelas (purity = 1.0).
     Video campuran ('kombinasi', 'sawitN' campuran) dilewati: satu foto berisi beberapa kelas
     tidak punya satu label grade.
  2. id_sampel = awalan nama file sebelum '--' (satu video = satu tumpukan fisik).
     Frame dari video yang sama nyaris kembar, jadi jumlah sampel EFEKTIF = jumlah video, bukan jumlah foto.
  3. Memetakan kelas dataset ke A/B/C memakai MAPPING di bawah.

MAPPING adalah DRAF (rubrik v0.1) dan belum disahkan validator mutu. Ubah di sini, jangan di tempat lain.
"""
import argparse
import collections
import re
import shutil
import zipfile
from pathlib import Path

CLASS_NAMES = ["Janjang kosong", "Kurang masak", "TBS abnormal", "TBS masak", "TBS mentah", "Terlalu masak"]

# DRAF. Alasan: rubrik v0.1 -> A = matang (fraksi 2-3); B = kurang matang / lewat matang I; C = mentah, kosong, abnormal.
MAPPING = {
    "TBS masak": "A",
    "Kurang masak": "B",
    "Terlalu masak": "B",   # ambigu: bisa lewat matang I (B) atau II (C). Lihat --overripe-as-c.
    "TBS mentah": "C",
    "Janjang kosong": "C",
    "TBS abnormal": "C",
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--zips", type=Path, default=Path("data_public"))
    ap.add_argument("--out", type=Path, default=Path("dataset_sawit_public"))
    ap.add_argument("--overripe-as-c", action="store_true", help="petakan 'Terlalu masak' ke C, bukan B")
    args = ap.parse_args()

    mapping = dict(MAPPING)
    if args.overripe_as_c:
        mapping["Terlalu masak"] = "C"

    # video -> {class_id: count}, dan daftar (zip, nama jpg)
    hist = collections.defaultdict(collections.Counter)
    frames = collections.defaultdict(list)
    for z in ("train", "valid", "test"):
        zp = args.zips / f"{z}_rev2.zip"
        if not zp.exists():
            raise SystemExit(f"tidak ada: {zp}")
        with zipfile.ZipFile(zp) as zf:
            names = zf.namelist()
            for n in names:
                if not n.endswith(".jpg"):
                    continue
                m = re.match(r".*/(.+?)--(\d+)-_png", n)
                if not m:
                    continue
                vid, fr = m.group(1), m.group(2)
                frames[vid].append((zp, n, fr))
                txt = n[:-4] + ".txt"
                if txt in names:
                    for line in zf.read(txt).decode().splitlines():
                        p = line.split()
                        if p:
                            hist[vid][int(p[0])] += 1

    if args.out.exists():
        shutil.rmtree(args.out)
    per_grade_videos = collections.defaultdict(set)
    per_grade_images = collections.Counter()
    skipped_mixed = 0
    for vid, h in hist.items():
        if len(h) != 1:           # lebih dari satu kelas di video ini
            skipped_mixed += 1
            continue
        cls = CLASS_NAMES[next(iter(h))]
        grade = mapping[cls]
        dest = args.out / "kelapa_sawit" / grade
        dest.mkdir(parents=True, exist_ok=True)
        opened = {}
        for zp, n, fr in frames[vid]:
            zf = opened.setdefault(zp, zipfile.ZipFile(zp))
            (dest / f"{vid}__{fr}.jpg").write_bytes(zf.read(n))
            per_grade_images[grade] += 1
        per_grade_videos[grade].add(vid)
        for zf in opened.values():
            zf.close()

    print(f"video campuran dilewati: {skipped_mixed}")
    for g in "ABC":
        print(f"grade {g}: {per_grade_images[g]} foto dari {len(per_grade_videos[g])} video (sampel efektif)")
    print(f"hasil di: {args.out}")


if __name__ == "__main__":
    main()
