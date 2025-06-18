import os
from PIL import Image

RAW_DIR = "face_ai/raw_gif"
TRAIN_DIR = "face_ai/data/train"

def convert_and_group():
    if not os.path.exists(RAW_DIR):
        print(f"Folder {RAW_DIR} tidak ditemukan.")
        return

    os.makedirs(TRAIN_DIR, exist_ok=True)
    counter_per_subject = {}

    for filename in os.listdir(RAW_DIR):
        if not filename.endswith(".gif"):
            continue

        filepath = os.path.join(RAW_DIR, filename)
        subject_name = filename.split('.')[0]  # e.g., subject01.glasses.gif → subject01

        # Update counter
        count = counter_per_subject.get(subject_name, 0) + 1
        counter_per_subject[subject_name] = count

        # Buat folder tujuan jika belum ada
        subject_folder = os.path.join(TRAIN_DIR, subject_name)
        os.makedirs(subject_folder, exist_ok=True)

        # Konversi & simpan ke jpg
        img = Image.open(filepath).convert("L")  # grayscale
        out_path = os.path.join(subject_folder, f"{subject_name}_{count}.jpg")
        img.save(out_path)
        print(f"✔️ {filename} → {out_path}")

    print("✅ Semua file berhasil diproses!")

if __name__ == '__main__':
    convert_and_group()
