# scripts/extract_casia_fast.py

import os, io
from recordio import IndexedRecordIO
from PIL import Image
from tqdm import tqdm

# 1) Path ke file CASIA RecordIO & IDX
rec_path = '../data/casia-webface/train.rec'
idx_path = '../data/casia-webface/train.idx'

# 2) Path ke file LIST (index → label, filename)
lst_path = '../data/casia-webface/train.lst'

# 3) Output folder
out_root = 'casia_images'
os.makedirs(out_root, exist_ok=True)

# 4) Baca mapping dari train.lst
mapping = {}
with open(lst_path, 'r') as f:
    # format tiap baris: idx \t label \t original_filename
    for line in f:
        idx, label, fname = line.strip().split('\t')
        mapping[int(idx)] = (label, fname)

# 5) Buka RecordIO
reader = IndexedRecordIO(idx_path, rec_path, 'r')

# 6) Loop & extract
for idx in tqdm(sorted(mapping.keys()), desc='Extracting CASIA'):
    header, img_buf = reader.get(idx)       # pure-Python, no NumPy
    label, fname = mapping[idx]

    # Buat folder per label
    dest_dir = os.path.join(out_root, label)
    os.makedirs(dest_dir, exist_ok=True)

    # Decode JPEG bytes via Pillow
    img = Image.open(io.BytesIO(img_buf))
    # Simpan dengan nama aslinya
    img.save(os.path.join(dest_dir, os.path.basename(fname)))

print('Done! Gambar disimpan di:', out_root)
