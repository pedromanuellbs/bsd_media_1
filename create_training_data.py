#!/usr/bin/env python3
"""
Generate example training data for LBPH face recognition
This creates dummy training data for testing the backend
"""

import os
import cv2
import numpy as np
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_synthetic_faces(num_users=5, faces_per_user=10):
    """Create synthetic face data for testing"""
    
    # Create directories
    model_dir = 'face_ai/model'
    data_dir = 'face_ai/data/train'
    
    os.makedirs(model_dir, exist_ok=True)
    os.makedirs(data_dir, exist_ok=True)
    
    faces = []
    labels = []
    label_map = {}
    
    for user_id in range(num_users):
        user_name = f"user_{user_id + 1}"
        user_dir = os.path.join(data_dir, user_name)
        os.makedirs(user_dir, exist_ok=True)
        
        label_map[user_id] = user_name
        
        logger.info(f"Creating faces for {user_name}...")
        
        for face_id in range(faces_per_user):
            # Create a synthetic face image
            face_img = create_synthetic_face(user_id, face_id)
            
            # Save as training image
            face_filename = f"{user_name}_face_{face_id:02d}.jpg"
            face_path = os.path.join(user_dir, face_filename)
            cv2.imwrite(face_path, face_img)
            
            # Convert to grayscale for training
            gray_face = cv2.cvtColor(face_img, cv2.COLOR_BGR2GRAY)
            
            # Resize to standard size
            gray_face = cv2.resize(gray_face, (100, 100))
            
            faces.append(gray_face)
            labels.append(user_id)
    
    return faces, labels, label_map

def create_synthetic_face(user_id, face_id):
    """Create a synthetic face image with variations"""
    
    # Create base image
    img = np.zeros((120, 120, 3), dtype=np.uint8)
    
    # User-specific base color
    base_color = (100 + user_id * 20, 120 + user_id * 15, 140 + user_id * 10)
    img.fill(128)
    
    # Face oval
    center = (60, 60)
    axes = (35, 45)
    cv2.ellipse(img, center, axes, 0, 0, 360, base_color, -1)
    
    # Add some variation based on face_id
    variation = face_id * 5
    
    # Eyes
    eye_color = (50 + variation, 50 + variation, 50 + variation)
    cv2.circle(img, (45, 45), 6, eye_color, -1)
    cv2.circle(img, (75, 45), 6, eye_color, -1)
    
    # Nose
    nose_points = np.array([[60, 55], [58, 70], [62, 70]], np.int32)
    cv2.fillPoly(img, [nose_points], (80 + variation, 80 + variation, 80 + variation))
    
    # Mouth
    mouth_color = (60 + variation, 40 + variation, 40 + variation)
    cv2.ellipse(img, (60, 85), (12, 6), 0, 0, 180, mouth_color, -1)
    
    # Add some noise for realism
    noise = np.random.normal(0, 10, img.shape).astype(np.uint8)
    img = cv2.add(img, noise)
    
    return img

def train_lbph_model():
    """Train the LBPH face recognizer"""
    try:
        logger.info("🏋️ Training LBPH face recognizer...")
        
        # Create synthetic training data
        faces, labels, label_map = create_synthetic_faces(num_users=5, faces_per_user=10)
        
        # Create and train LBPH recognizer
        recognizer = cv2.face.LBPHFaceRecognizer_create()
        recognizer.train(faces, np.array(labels))
        
        # Save model
        model_path = 'face_ai/model/face_model.yml'
        recognizer.save(model_path)
        
        # Save label mapping
        labels_path = 'face_ai/model/labels.npy'
        np.save(labels_path, label_map)
        
        logger.info(f"✅ LBPH model trained and saved:")
        logger.info(f"   - Model: {model_path}")
        logger.info(f"   - Labels: {labels_path}")
        logger.info(f"   - Users: {len(label_map)}")
        logger.info(f"   - Training samples: {len(faces)}")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Error training LBPH model: {e}")
        return False

def main():
    """Main function"""
    logger.info("🚀 Generating example training data for LBPH...")
    
    # Check if OpenCV is available
    try:
        import cv2
        logger.info(f"✅ OpenCV version: {cv2.__version__}")
    except ImportError:
        logger.error("❌ OpenCV not available - please install opencv-python")
        return False
    
    # Check if contrib module is available
    try:
        recognizer = cv2.face.LBPHFaceRecognizer_create()
        logger.info("✅ OpenCV contrib module (face recognition) available")
    except AttributeError:
        logger.error("❌ OpenCV contrib module not available - please install opencv-contrib-python")
        return False
    
    # Train the model
    if train_lbph_model():
        logger.info("🎉 Training data generation completed successfully!")
        return True
    else:
        logger.error("❌ Training data generation failed")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)