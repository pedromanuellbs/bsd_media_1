# scripts/preprocess_casia_insight.py

import os, json
import numpy as np
from PIL import Image
from insightface.app import FaceAnalysis
from tqdm import tqdm

# 1. Folder input (hasil unzip CASIA-WebFace manual)
root = os.path.abspath(os.path.join(os.path.dirname(__file__),
                                    '..', 'data', 'casia-webface'))

# 2. Folder output untuk crop/aligned & embeddings
aligned_root = os.path.abspath(os.path.join(os.path.dirname(__file__),
                                            '..', 'data', 'casia-aligned'))
emb_root     = os.path.abspath(os.path.join(os.path.dirname(__file__),
                                            '..', 'data', 'casia-embeddings'))
os.makedirs(aligned_root, exist_ok=True)
os.makedirs(emb_root,     exist_ok=True)

# 3. Inisialisasi InsightFace (ArcFace + deteksi)
app = FaceAnalysis(name="buffalo_l", providers=['CPUExecutionProvider'])
app.prepare(ctx_id=0, det_size=(320, 320))

all_embeddings = []

# 4. Iterasi folder per ID
for label in os.listdir(root):
    src_dir = os.path.join(root, label)
    dst_dir = os.path.join(aligned_root, label)
    os.makedirs(dst_dir, exist_ok=True)

    for fname in tqdm(os.listdir(src_dir), desc=f"Label {label}"):
        img_path = os.path.join(src_dir, fname)
        try:
            img = np.asarray(Image.open(img_path))
        except:
            continue

        # deteksi & ekstrak face (pilih yang pertama)
        faces = app.get(img)
        if not faces:
            continue
        face = faces[0]

        # crop + simpan aligned 112×112
        x1, y1, x2, y2 = map(int, face.bbox)
        crop = Image.fromarray(img[y1:y2, x1:x2]).resize((112,112))
        crop.save(os.path.join(dst_dir, fname))

        # simpan embedding & label
        all_embeddings.append({
            'label': label,
            'file':  fname,
            'embedding': face.normed_embedding.tolist()
        })

# 5. Dump semua embedding ke JSON
with open(os.path.join(emb_root, 'casia_embeddings.json'), 'w') as f:
    json.dump(all_embeddings, f)

print("✅ Selesai! Aligned images di:", aligned_root)
print("✅ Embeddings JSON di:   ", emb_root)
