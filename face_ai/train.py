import cv2, os, numpy as np

DATA_DIR = 'face_ai/data/train'
MODEL_PATH = 'face_ai/model/face_model.yml'
HAAR_PATH  = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'

def prepare_data(path):
    faces, labels = [], []
    label_map = {}
    idx = 0

    for user in os.listdir(path):
        user_dir = os.path.join(path, user)
        if not os.path.isdir(user_dir): continue
        label_map[idx] = user

        for fn in os.listdir(user_dir):
            img = cv2.imread(os.path.join(user_dir, fn))
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            faces_rects = cv2.CascadeClassifier(HAAR_PATH).detectMultiScale(gray, 1.1, 5)
            for (x, y, w, h) in faces_rects:
                faces.append(gray[y:y+h, x:x+w])
                labels.append(idx)
        idx += 1

    return faces, labels, label_map

if __name__ == '__main__':
    faces, labels, label_map = prepare_data(DATA_DIR)
    recognizer = cv2.face.LBPHFaceRecognizer_create()
    recognizer.train(faces, np.array(labels))
    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    recognizer.save(MODEL_PATH)
    np.save('face_ai/model/labels.npy', label_map)
    print('✅ Training selesai. Model disimpan di', MODEL_PATH)
