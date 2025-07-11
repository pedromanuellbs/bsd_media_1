"""
Enhanced Photo Matching Backend Service
Uses MTCNN for face detection and LBPH for face recognition
Includes comprehensive logging and error handling
"""

import os
import cv2
import json
import logging
import requests
import tempfile
import traceback
import numpy as np
from datetime import datetime
from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
from urllib.parse import urlparse
import time
import threading
from queue import Queue
import uuid
from google_drive_manager import GoogleDrivePhotoManager, get_all_photos_for_matching

# Configure logging to appear in Railway logs
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),  # Console output for Railway
        logging.FileHandler('photo_matching.log')  # File backup
    ]
)
logger = logging.getLogger(__name__)

# Flask setup
app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Global configuration
CONFIG = {
    'MODEL_PATH': 'face_ai/model/face_model.yml',
    'LABELS_NPY': 'face_ai/model/labels.npy',
    'HAAR_CASCADE_PATH': None,  # Will be set on startup
    'TEMP_DIR': tempfile.mkdtemp(),
    'GOOGLE_DRIVE_API_KEY': 'AIzaSyC_vPd6yPwYQ60Pn-tuR3Nly_7mgXZcxGk',
    'MAX_PHOTOS_PER_SESSION': 100,
    'LBPH_CONFIDENCE_THRESHOLD': 50.0,
    'MTCNN_MIN_FACE_SIZE': 40
}

# Global variables
face_recognizer = None
label_map = {}
job_queue = Queue()
job_results = {}
mtcnn_detector = None

def setup_face_detection():
    """Initialize face detection (MTCNN preferred, Haar Cascade fallback)"""
    global mtcnn_detector
    
    try:
        # Try to import and initialize MTCNN
        from mtcnn import MTCNN
        mtcnn_detector = MTCNN(min_face_size=CONFIG['MTCNN_MIN_FACE_SIZE'])
        logger.info("✅ MTCNN face detector initialized successfully")
        return True
    except ImportError:
        logger.warning("⚠️ MTCNN not available, falling back to Haar Cascade")
        CONFIG['HAAR_CASCADE_PATH'] = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        if os.path.exists(CONFIG['HAAR_CASCADE_PATH']):
            logger.info("✅ Haar Cascade face detector initialized as fallback")
            return True
        else:
            logger.error("❌ Neither MTCNN nor Haar Cascade available")
            return False
    except Exception as e:
        logger.error(f"❌ Error initializing MTCNN: {e}")
        logger.info("🔄 Falling back to Haar Cascade")
        CONFIG['HAAR_CASCADE_PATH'] = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        return os.path.exists(CONFIG['HAAR_CASCADE_PATH'])

def setup_face_recognition():
    """Initialize LBPH face recognizer"""
    global face_recognizer, label_map
    
    try:
        if not os.path.exists(CONFIG['MODEL_PATH']):
            logger.error(f"❌ Face recognition model not found: {CONFIG['MODEL_PATH']}")
            return False
            
        if not os.path.exists(CONFIG['LABELS_NPY']):
            logger.error(f"❌ Label mapping not found: {CONFIG['LABELS_NPY']}")
            return False
            
        # Load LBPH face recognizer
        face_recognizer = cv2.face.LBPHFaceRecognizer_create()
        face_recognizer.read(CONFIG['MODEL_PATH'])
        
        # Load label mapping
        label_map = np.load(CONFIG['LABELS_NPY'], allow_pickle=True).item()
        
        logger.info(f"✅ LBPH face recognizer loaded with {len(label_map)} known users")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error loading face recognition model: {e}")
        return False

def detect_faces_mtcnn(image):
    """Detect faces using MTCNN"""
    try:
        if mtcnn_detector is None:
            raise Exception("MTCNN detector not initialized")
            
        # Convert BGR to RGB for MTCNN
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # Detect faces
        faces = mtcnn_detector.detect_faces(rgb_image)
        
        # Convert to OpenCV format (x, y, w, h)
        face_locations = []
        for face in faces:
            x, y, w, h = face['box']
            # Ensure positive dimensions
            if w > 0 and h > 0:
                face_locations.append((x, y, w, h))
                
        logger.info(f"🔍 MTCNN detected {len(face_locations)} faces")
        return face_locations
        
    except Exception as e:
        logger.error(f"❌ MTCNN face detection error: {e}")
        return []

def detect_faces_haar(image):
    """Detect faces using Haar Cascade"""
    try:
        if CONFIG['HAAR_CASCADE_PATH'] is None:
            raise Exception("Haar Cascade path not configured")
            
        # Convert to grayscale
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Load cascade and detect faces
        face_cascade = cv2.CascadeClassifier(CONFIG['HAAR_CASCADE_PATH'])
        faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))
        
        # Convert numpy array to list of tuples
        face_locations = [(x, y, w, h) for x, y, w, h in faces]
        
        logger.info(f"🔍 Haar Cascade detected {len(face_locations)} faces")
        return face_locations
        
    except Exception as e:
        logger.error(f"❌ Haar Cascade face detection error: {e}")
        return []

def detect_faces(image):
    """Detect faces using available method (MTCNN preferred)"""
    if mtcnn_detector is not None:
        return detect_faces_mtcnn(image)
    else:
        return detect_faces_haar(image)

def recognize_faces(image, face_locations):
    """Recognize faces using LBPH"""
    results = []
    
    if face_recognizer is None:
        logger.error("❌ Face recognizer not initialized")
        return results
        
    # Convert to grayscale for LBPH
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    for i, (x, y, w, h) in enumerate(face_locations):
        try:
            # Extract face ROI
            face_roi = gray[y:y+h, x:x+w]
            
            # Perform recognition
            label, confidence = face_recognizer.predict(face_roi)
            
            # Get user name from label mapping
            user_name = label_map.get(label, 'Unknown')
            
            # Determine if it's a match based on confidence threshold
            is_match = confidence <= CONFIG['LBPH_CONFIDENCE_THRESHOLD']
            
            result = {
                'face_index': i,
                'user': user_name,
                'confidence': float(confidence),
                'is_match': is_match,
                'accuracy': max(0, 100 - confidence) if confidence < 100 else 0,
                'bbox': {'x': int(x), 'y': int(y), 'w': int(w), 'h': int(h)}
            }
            
            results.append(result)
            
            # Log recognition result
            status = "✅ MATCH" if is_match else "❌ NO MATCH"
            logger.info(f"👤 Face {i+1}: {user_name} - Confidence: {confidence:.2f} - {status}")
            
        except Exception as e:
            logger.error(f"❌ Error recognizing face {i+1}: {e}")
            results.append({
                'face_index': i,
                'user': 'Error',
                'confidence': 999.0,
                'is_match': False,
                'accuracy': 0,
                'error': str(e),
                'bbox': {'x': int(x), 'y': int(y), 'w': int(w), 'h': int(h)}
            })
    
    return results

def download_image_from_drive(drive_url):
    """Download image from Google Drive URL"""
    try:
        logger.info(f"📥 Downloading image from Google Drive: {drive_url}")
        
        # Extract file ID from Google Drive URL
        file_id = None
        if '/d/' in drive_url:
            file_id = drive_url.split('/d/')[1].split('/')[0]
        elif 'id=' in drive_url:
            file_id = drive_url.split('id=')[1].split('&')[0]
        
        if not file_id:
            raise ValueError("Could not extract file ID from Google Drive URL")
        
        # Create direct download URL
        download_url = f"https://drive.google.com/uc?export=download&id={file_id}"
        
        # Download the image
        response = requests.get(download_url, timeout=30)
        response.raise_for_status()
        
        # Save to temporary file
        temp_filename = f"temp_image_{int(time.time())}_{uuid.uuid4().hex[:8]}.jpg"
        temp_filepath = os.path.join(CONFIG['TEMP_DIR'], temp_filename)
        
        with open(temp_filepath, 'wb') as f:
            f.write(response.content)
        
        logger.info(f"✅ Image downloaded successfully: {temp_filename}")
        return temp_filepath
        
    except requests.exceptions.RequestException as e:
        logger.error(f"❌ Network error downloading image: {e}")
        raise
    except Exception as e:
        logger.error(f"❌ Error downloading image from Google Drive: {e}")
        raise

def process_image(image_path, photo_name=""):
    """Process a single image for face recognition"""
    try:
        logger.info(f"🖼️ Processing image: {photo_name or image_path}")
        
        # Read image
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Could not read image file: {image_path}")
        
        logger.info(f"✅ Image loaded successfully - Shape: {image.shape}")
        
        # Detect faces
        face_locations = detect_faces(image)
        
        if len(face_locations) == 0:
            logger.warning(f"😞 No faces detected in image: {photo_name or image_path}")
            return {
                'photo_name': photo_name or os.path.basename(image_path),
                'faces_detected': 0,
                'recognition_results': [],
                'error': None
            }
        
        # Recognize faces
        recognition_results = recognize_faces(image, face_locations)
        
        result = {
            'photo_name': photo_name or os.path.basename(image_path),
            'faces_detected': len(face_locations),
            'recognition_results': recognition_results,
            'error': None
        }
        
        # Log summary
        matches = sum(1 for r in recognition_results if r.get('is_match', False))
        logger.info(f"📊 Processing complete - {len(face_locations)} faces detected, {matches} matches found")
        
        return result
        
    except Exception as e:
        error_msg = f"Error processing image {photo_name or image_path}: {str(e)}"
        logger.error(f"❌ {error_msg}")
        logger.error(f"📍 Traceback: {traceback.format_exc()}")
        
        return {
            'photo_name': photo_name or os.path.basename(image_path),
            'faces_detected': 0,
            'recognition_results': [],
            'error': error_msg
        }

def process_photo_search_job(job_id, face_image_path, session_limit=10):
    """Process photo search job in background"""
    try:
        logger.info(f"🚀 Starting photo search job: {job_id}")
        
        # Get all photos from Google Drive sessions
        all_photos = get_all_photos_for_matching(
            CONFIG['GOOGLE_DRIVE_API_KEY'], 
            max_photos_per_session=20
        )
        
        # Limit total photos to process
        photos_to_process = all_photos[:CONFIG['MAX_PHOTOS_PER_SESSION']]
        
        # Update job status
        job_results[job_id] = {
            'status': 'processing',
            'progress': 0,
            'total': len(photos_to_process),
            'results': [],
            'error': None
        }
        
        if not photos_to_process:
            job_results[job_id]['status'] = 'completed'
            job_results[job_id]['results'] = []
            logger.info(f"✅ No photos found to process for job: {job_id}")
            return
        
        # Process query face
        query_result = process_image(face_image_path, "query_face")
        if query_result['error']:
            job_results[job_id]['status'] = 'failed'
            job_results[job_id]['error'] = f"Error processing query face: {query_result['error']}"
            return
        
        if query_result['faces_detected'] == 0:
            job_results[job_id]['status'] = 'failed'
            job_results[job_id]['error'] = "No face detected in query image"
            return
        
        logger.info(f"✅ Query face processed successfully")
        
        # Process each photo from Google Drive
        matched_photos = []
        drive_manager = GoogleDrivePhotoManager(CONFIG['GOOGLE_DRIVE_API_KEY'])
        
        for i, photo_info in enumerate(photos_to_process):
            try:
                photo_name = photo_info.get('name', f'photo_{i+1}')
                logger.info(f"📸 Processing photo {i+1}/{len(photos_to_process)}: {photo_name}")
                
                # Download image from Google Drive
                temp_image_path = drive_manager.download_photo(
                    photo_info['downloadUrl'], 
                    CONFIG['TEMP_DIR']
                )
                
                try:
                    # Process the downloaded image
                    result = process_image(temp_image_path, photo_name)
                    
                    # Check if any faces match
                    has_match = any(r.get('is_match', False) for r in result['recognition_results'])
                    
                    if has_match:
                        matched_photo = {
                            'name': photo_name,
                            'id': photo_info['id'],
                            'thumbnailLink': photo_info.get('thumbnailLink'),
                            'webContentLink': photo_info.get('webContentLink'), 
                            'webViewLink': photo_info.get('webViewLink'),
                            'sessionId': photo_info.get('sessionId'),
                            'sessionTitle': photo_info.get('sessionTitle'),
                            'sessionDate': photo_info.get('sessionDate'),
                            'sessionLocation': photo_info.get('sessionLocation'),
                            'faces_detected': result['faces_detected'],
                            'matching_faces': [r for r in result['recognition_results'] if r.get('is_match', False)]
                        }
                        matched_photos.append(matched_photo)
                        
                        # Log detailed match results
                        for match in matched_photo['matching_faces']:
                            logger.info(f"🎯 MATCH FOUND: {photo_name} - User: {match['user']} - "
                                      f"Confidence: {match['confidence']:.2f} - "
                                      f"Accuracy: {match['accuracy']:.1f}%")
                    else:
                        logger.info(f"❌ No match in photo: {photo_name}")
                        
                finally:
                    # Clean up downloaded file
                    if os.path.exists(temp_image_path):
                        os.remove(temp_image_path)
                
            except Exception as e:
                logger.error(f"❌ Error processing photo {i+1} ({photo_name}): {e}")
                # Continue processing other photos
                
            # Update progress
            job_results[job_id]['progress'] = i + 1
        
        # Complete job
        job_results[job_id]['status'] = 'completed'
        job_results[job_id]['results'] = matched_photos
        
        logger.info(f"🎉 Photo search job completed: {job_id} - Found {len(matched_photos)} matching photos")
        
    except Exception as e:
        logger.error(f"❌ Error in photo search job {job_id}: {e}")
        logger.error(f"📍 Traceback: {traceback.format_exc()}")
        job_results[job_id]['status'] = 'failed'
        job_results[job_id]['error'] = str(e)

# Flask routes
@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'face_detector': 'MTCNN' if mtcnn_detector else 'Haar Cascade',
        'face_recognizer': 'LBPH' if face_recognizer else 'Not loaded'
    })

@app.route('/recognize', methods=['POST'])
def recognize_single_face():
    """Recognize faces in a single uploaded image"""
    try:
        if 'face' not in request.files:
            return jsonify({'error': 'No face image uploaded'}), 400
        
        face_file = request.files['face']
        if face_file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        # Save uploaded file
        filename = secure_filename(face_file.filename)
        filepath = os.path.join(CONFIG['TEMP_DIR'], filename)
        face_file.save(filepath)
        
        try:
            # Process the image
            result = process_image(filepath, filename)
            return jsonify(result)
            
        finally:
            # Clean up uploaded file
            if os.path.exists(filepath):
                os.remove(filepath)
                
    except Exception as e:
        logger.error(f"❌ Error in recognize endpoint: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/start_photo_search', methods=['POST'])
def start_photo_search():
    """Start a photo search job"""
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image uploaded'}), 400
        
        image_file = request.files['image']
        if image_file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        # Save uploaded image
        filename = secure_filename(image_file.filename)
        filepath = os.path.join(CONFIG['TEMP_DIR'], f"query_{filename}")
        image_file.save(filepath)
        
        # Generate job ID
        job_id = str(uuid.uuid4())
        
        # Start background job
        threading.Thread(
            target=process_photo_search_job,
            args=(job_id, filepath),
            daemon=True
        ).start()
        
        logger.info(f"📋 Photo search job started: {job_id}")
        
        return jsonify({
            'success': True,
            'job_id': job_id,
            'message': 'Photo search job started'
        })
        
    except Exception as e:
        logger.error(f"❌ Error starting photo search: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/get_search_status', methods=['GET'])
def get_search_status():
    """Get the status of a photo search job"""
    try:
        job_id = request.args.get('job_id')
        if not job_id:
            return jsonify({'error': 'job_id parameter required'}), 400
        
        if job_id not in job_results:
            return jsonify({'error': 'Job not found'}), 404
        
        return jsonify({
            'success': True,
            'job_data': job_results[job_id]
        })
        
    except Exception as e:
        logger.error(f"❌ Error getting search status: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/register_face', methods=['POST'])
def register_face():
    """Register a new face (placeholder for now)"""
    try:
        # This would typically add a new face to the training dataset
        # For now, return success
        return jsonify({
            'success': True,
            'message': 'Face registration endpoint (not implemented)'
        })
        
    except Exception as e:
        logger.error(f"❌ Error in face registration: {e}")
        return jsonify({'error': str(e)}), 500

def initialize_app():
    """Initialize the application"""
    logger.info("🚀 Initializing Enhanced Photo Matching Backend...")
    
    # Create temp directory if it doesn't exist
    os.makedirs(CONFIG['TEMP_DIR'], exist_ok=True)
    logger.info(f"📁 Temp directory: {CONFIG['TEMP_DIR']}")
    
    # Initialize face detection
    if not setup_face_detection():
        logger.error("❌ Failed to initialize face detection")
        return False
    
    # Initialize face recognition
    if not setup_face_recognition():
        logger.error("❌ Failed to initialize face recognition")
        return False
    
    logger.info("✅ Enhanced Photo Matching Backend initialized successfully!")
    return True

if __name__ == '__main__':
    if initialize_app():
        logger.info("🌟 Starting Enhanced Photo Matching Backend Server...")
        app.run(host='0.0.0.0', port=5000, debug=False)
    else:
        logger.error("❌ Failed to initialize application")
        exit(1)