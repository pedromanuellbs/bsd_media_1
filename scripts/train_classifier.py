# scripts/train_classifier.py

import os, json, numpy as np
from sklearn.preprocessing import LabelEncoder
from sklearn.svm import SVC
import joblib

# Tentukan path absolut ke JSON embeddings
BASE = os.path.dirname(__file__)  # …/bsd_media/scripts
EMB_PATH = os.path.abspath(os.path.join(
    BASE, '..', 'data', 'casia-embeddings', 'casia_embeddings.json'
))

# 1) Load embeddings
with open(EMB_PATH, 'r') as f:
    data = json.load(f)

X = np.vstack([d['embedding'] for d in data])
y = [d['label'] for d in data]

# 2) Encode label & train SVM
le = LabelEncoder().fit(y)
y_enc = le.transform(y)
clf = SVC(kernel='linear', probability=True, class_weight='balanced')
clf.fit(X, y_enc)

# 3) Pastikan direktori models/ ada
MODEL_DIR = os.path.abspath(os.path.join(BASE, '..', 'models'))
os.makedirs(MODEL_DIR, exist_ok=True)

# 4) Simpan model dan encoder
joblib.dump(clf, os.path.join(MODEL_DIR, 'casia_svm.pkl'))
joblib.dump(le,  os.path.join(MODEL_DIR, 'label_encoder.pkl'))

print("✅ Training selesai")
print(f"   - SVM model  : {os.path.join(MODEL_DIR, 'casia_svm.pkl')}")
print(f"   - Label enc. : {os.path.join(MODEL_DIR, 'label_encoder.pkl')}")
