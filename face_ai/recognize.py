from flask import Flask, request, jsonify
import os
import cv2
import numpy as np
from werkzeug.utils import secure_filename

# Flask setup
app = Flask(__name__)

# Path constants
MODEL_PATH = 'face_ai/model/face_model.yml'
HAAR_PATH = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
LABELS_NPY = 'face_ai/model/labels.npy'
SAVE_DIR = 'face_dataset'

# Load model once (efisien)
recognizer = cv2.face.LBPHFaceRecognizer_create()
recognizer.read(MODEL_PATH)
label_map = np.load(LABELS_NPY, allow_pickle=True).item()

@app.route('/recognize', methods=['POST'])
def recognize_route():
    if 'face' not in request.files:
        return jsonify({'error': 'No face image uploaded'}), 400

    # Simpan file upload
    face_file = request.files['face']
    filename = secure_filename(face_file.filename)
    os.makedirs(SAVE_DIR, exist_ok=True)
    save_path = os.path.join(SAVE_DIR, filename)
    face_file.save(save_path)

    # Jalankan face recognition
    results = recognize(save_path)

    return jsonify({'results': results})


def recognize(image_path):
    img = cv2.imread(image_path)
    if img is None:
        return [{'user': 'Unknown', 'confidence': 999.0, 'error': 'Invalid image'}]

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = cv2.CascadeClassifier(HAAR_PATH).detectMultiScale(gray, 1.1, 5)

    response = []

    for (x, y, w, h) in faces:
        roi = gray[y:y + h, x:x + w]
        label, conf = recognizer.predict(roi)
        name = label_map.get(label, 'Unknown')
        response.append({'user': name, 'confidence': round(conf, 2)})

    if not response:
        response.append({'user': 'No face detected', 'confidence': 999.0})

    return response


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
