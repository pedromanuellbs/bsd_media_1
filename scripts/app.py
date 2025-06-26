# app.py

from flask import Flask, request, jsonify
import joblib, numpy as np
from insightface.app import FaceAnalysis
import io
from PIL import Image

app = Flask(__name__)

# Load classifier & label encoder
clf = joblib.load('models/casia_svm.pkl')
le  = joblib.load('models/label_encoder.pkl')

# Siapkan FaceAnalysis (sudah ter-download model buffalo_l sebelumnya)
fa = FaceAnalysis(name="buffalo_l", providers=['CPUExecutionProvider'])
fa.prepare(ctx_id=0, det_size=(320,320))

@app.route('/recognize', methods=['POST'])
def recognize():
    # terima file form-data key 'face'
    if 'face' not in request.files:
        return jsonify({'error':'no file'}), 400
    f = request.files['face']
    img = Image.open(f).convert('RGB')
    img_arr = np.array(img)

    # 1) Detect & embed
    faces = fa.get(img_arr)
    if not faces:
        return jsonify({'error':'no face detected'}), 400
    emb = faces[0].normed_embedding.reshape(1,-1)  # shape (1,512)

    # 2) Predict
    probs = clf.predict_proba(emb)[0]               # shape (n_classes,)
    idx  = np.argmax(probs)
    label = le.inverse_transform([idx])[0]
    confidence = float(probs[idx])

    return jsonify({'user':label, 'confidence':confidence})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
