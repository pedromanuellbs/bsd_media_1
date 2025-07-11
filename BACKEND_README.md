# Enhanced Photo Matching Backend

This is the enhanced backend service for the BSD Media photo matching system, featuring MTCNN for face detection, LBPH for face recognition, and comprehensive logging.

## Features

### 🔍 Face Detection
- **MTCNN** (Multi-task CNN) for accurate face detection (preferred)
- **Haar Cascade** fallback for compatibility
- Configurable face size thresholds
- Detailed detection logging

### 👤 Face Recognition
- **LBPH** (Local Binary Patterns Histograms) for face recognition
- Configurable confidence thresholds
- Accuracy scoring and match determination
- Support for multiple users

### 📊 Comprehensive Logging
- **Download errors**: Detailed logging when Google Drive photos can't be fetched
- **Read errors**: Logging when photos can't be loaded by OpenCV
- **Face detection errors**: Logging when no faces are detected
- **Matching results**: Detailed logs including:
  - Photo filename
  - Whether a match was found
  - Recognized user
  - LBPH confidence score
  - Accuracy percentage
  - Match/no match status

### 🌐 Google Drive Integration
- Automatic photo download from Google Drive folders
- Support for multiple photo sessions
- Error handling for individual photo failures
- Continues processing even if some photos fail

### 🚀 Background Processing
- Job queue system for photo matching tasks
- Progress tracking and status updates
- Asynchronous processing with real-time status

## API Endpoints

### Health Check
```
GET /health
```
Returns backend status and configuration.

### Single Face Recognition
```
POST /recognize
Content-Type: multipart/form-data
Body: face=<image_file>
```
Recognizes faces in a single uploaded image.

### Start Photo Search
```
POST /start_photo_search
Content-Type: multipart/form-data
Body: image=<query_face_image>
```
Starts a background job to search for matching photos in Google Drive.

### Get Search Status
```
GET /get_search_status?job_id=<job_id>
```
Gets the current status and results of a photo search job.

### Face Registration
```
POST /register_face
Content-Type: multipart/form-data
Body: image=<face_image>, user_id=<user_id>
```
Registers a new face for future recognition (placeholder).

## Installation

### Prerequisites
```bash
pip install -r requirements.txt
```

### Required Dependencies
- Flask==3.1.1
- opencv-python==4.12.0.88
- opencv-contrib-python==4.12.0.88
- numpy==2.2.6
- requests==2.31.0
- Pillow==11.3.0
- mtcnn==1.0.0 (optional, for better face detection)
- tensorflow==2.19.0 (optional, for MTCNN)

### Setup Training Data
```bash
python create_training_data.py
```
This creates synthetic training data for testing the LBPH model.

## Running the Backend

### Development Mode
```bash
python backend_service.py
```

### Production Mode
```bash
gunicorn --bind 0.0.0.0:5000 --workers 2 --timeout 300 backend_service:app
```

### Docker
```bash
docker build -t photo-matching-backend .
docker run -p 5000:5000 photo-matching-backend
```

## Configuration

### Environment Variables
- `GOOGLE_DRIVE_API_KEY`: Google Drive API key for photo access
- `LBPH_CONFIDENCE_THRESHOLD`: Confidence threshold for face matching (default: 50.0)
- `MTCNN_MIN_FACE_SIZE`: Minimum face size for MTCNN detection (default: 40)
- `MAX_PHOTOS_PER_SESSION`: Maximum photos to process per session (default: 100)

### File Structure
```
face_ai/
├── model/
│   ├── face_model.yml      # LBPH trained model
│   └── labels.npy          # User label mappings
└── data/
    └── train/              # Training data directory
        ├── user_1/
        ├── user_2/
        └── ...
```

## Testing

### Run Backend Tests
```bash
python test_backend.py
```

### Manual Testing
```bash
# Health check
curl http://localhost:5000/health

# Face recognition
curl -X POST -F "face=@test_image.jpg" http://localhost:5000/recognize
```

## Deployment

### Railway
1. Create a new Railway project
2. Connect your repository
3. Set environment variables
4. Deploy using the provided `railway.json` configuration

### Manual Deployment
1. Build the Docker image
2. Push to your container registry
3. Deploy to your hosting platform
4. Set appropriate environment variables

## Logging

The backend provides detailed logging for all operations:

### Download Errors
```
❌ Network error downloading image: ConnectionError
❌ Error downloading image from Google Drive: Invalid file ID
```

### Read Errors
```
❌ Error processing image photo_1.jpg: Could not read image file
❌ Invalid image format: photo_2.jpg
```

### Face Detection Errors
```
😞 No faces detected in image: photo_3.jpg
❌ MTCNN face detection error: Model not loaded
```

### Matching Results
```
🎯 MATCH FOUND: photo_4.jpg - User: john_doe - Confidence: 35.42 - Accuracy: 64.6%
❌ No match in photo: photo_5.jpg
👤 Face 1: jane_smith - Confidence: 25.18 - ✅ MATCH
```

### Job Processing
```
🚀 Starting photo search job: abc123-def456
📸 Processing photo 5/20: wedding_photo_05.jpg
🎉 Photo search job completed: abc123-def456 - Found 3 matching photos
```

## Architecture

### Face Detection Pipeline
1. **MTCNN Detection** (preferred)
   - Uses deep learning for accurate face detection
   - Handles various face orientations and sizes
   - Provides confidence scores for detected faces

2. **Haar Cascade Fallback**
   - Classical computer vision approach
   - Lightweight and fast
   - Good compatibility across systems

### Face Recognition Pipeline
1. **LBPH Recognition**
   - Local Binary Patterns for texture analysis
   - Robust to illumination changes
   - Configurable confidence thresholds

2. **Match Determination**
   - Confidence-based matching
   - Accuracy scoring (100 - confidence)
   - Configurable match thresholds

### Google Drive Integration
1. **Photo Session Management**
   - Fetches photos from multiple Drive folders
   - Supports photo session metadata
   - Handles API rate limits and errors

2. **Download Management**
   - Temporary file handling
   - Automatic cleanup
   - Error recovery for individual photos

## Error Handling

The backend implements comprehensive error handling:

### Individual Photo Failures
- Continue processing remaining photos
- Log specific errors for each failed photo
- Maintain job progress even with failures

### Network Errors
- Retry logic for transient failures
- Detailed error logging
- Graceful degradation

### Model Errors
- Fallback detection methods
- Error logging for debugging
- Graceful failure responses

## Performance Considerations

### Resource Usage
- Memory: ~500MB for base model + temporary images
- CPU: Multi-core support via worker processes
- Disk: Temporary storage for downloaded images

### Scalability
- Horizontal scaling via multiple workers
- Job queue for background processing
- Stateless design for load balancing

### Optimization
- Image resize for processing efficiency
- Batch processing capabilities
- Cleanup of temporary files

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is part of the BSD Media Photography Community app.