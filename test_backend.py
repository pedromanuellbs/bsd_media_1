#!/usr/bin/env python3
"""
Test script for the enhanced photo matching backend
"""

import cv2
import numpy as np
import requests
import json
import os
import tempfile
import time
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_test_face_image():
    """Create a simple test image with a face-like rectangle"""
    # Create a simple test image (simulating a face)
    img = np.zeros((200, 200, 3), dtype=np.uint8)
    img.fill(128)  # Gray background
    
    # Draw a simple face-like rectangle
    cv2.rectangle(img, (50, 50), (150, 150), (255, 255, 255), -1)
    cv2.circle(img, (80, 80), 10, (0, 0, 0), -1)  # Left eye
    cv2.circle(img, (120, 80), 10, (0, 0, 0), -1)  # Right eye
    cv2.rectangle(img, (90, 110), (110, 130), (0, 0, 0), -1)  # Nose
    cv2.rectangle(img, (70, 140), (130, 145), (0, 0, 0), -1)  # Mouth
    
    # Save to temporary file
    temp_file = os.path.join(tempfile.gettempdir(), 'test_face.jpg')
    cv2.imwrite(temp_file, img)
    
    logger.info(f"✅ Created test face image: {temp_file}")
    return temp_file

def test_health_endpoint(base_url):
    """Test the health check endpoint"""
    try:
        logger.info("🔍 Testing health endpoint...")
        response = requests.get(f"{base_url}/health", timeout=10)
        response.raise_for_status()
        
        data = response.json()
        logger.info(f"✅ Health check passed: {data}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Health check failed: {e}")
        return False

def test_recognize_endpoint(base_url, test_image_path):
    """Test the single face recognition endpoint"""
    try:
        logger.info("🔍 Testing recognize endpoint...")
        
        with open(test_image_path, 'rb') as f:
            files = {'face': f}
            response = requests.post(f"{base_url}/recognize", files=files, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            logger.info(f"✅ Recognition result: {json.dumps(data, indent=2)}")
            return True
            
    except Exception as e:
        logger.error(f"❌ Recognition test failed: {e}")
        return False

def test_photo_search_workflow(base_url, test_image_path):
    """Test the complete photo search workflow"""
    try:
        logger.info("🔍 Testing photo search workflow...")
        
        # Start photo search job
        with open(test_image_path, 'rb') as f:
            files = {'image': f}
            response = requests.post(f"{base_url}/start_photo_search", files=files, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            if not data.get('success'):
                raise Exception(f"Failed to start photo search: {data}")
                
            job_id = data['job_id']
            logger.info(f"✅ Photo search job started: {job_id}")
        
        # Poll for results
        max_wait = 60  # seconds
        poll_interval = 3  # seconds
        waited = 0
        
        while waited < max_wait:
            response = requests.get(f"{base_url}/get_search_status", params={'job_id': job_id}, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            if not data.get('success'):
                raise Exception(f"Failed to get search status: {data}")
                
            job_data = data['job_data']
            status = job_data['status']
            
            logger.info(f"📊 Job status: {status} - Progress: {job_data.get('progress', 0)}/{job_data.get('total', 0)}")
            
            if status == 'completed':
                results = job_data.get('results', [])
                logger.info(f"✅ Photo search completed! Found {len(results)} matching photos")
                if results:
                    logger.info(f"📋 First result: {json.dumps(results[0], indent=2)}")
                return True
            elif status == 'failed':
                error = job_data.get('error', 'Unknown error')
                logger.error(f"❌ Photo search failed: {error}")
                return False
            
            time.sleep(poll_interval)
            waited += poll_interval
        
        logger.error(f"❌ Photo search timed out after {max_wait} seconds")
        return False
        
    except Exception as e:
        logger.error(f"❌ Photo search workflow failed: {e}")
        return False

def main():
    """Main test function"""
    # Configuration
    base_url = "http://localhost:5000"  # Change to your backend URL
    
    logger.info("🚀 Starting backend tests...")
    
    # Create test image
    test_image_path = create_test_face_image()
    
    try:
        # Test health endpoint
        if not test_health_endpoint(base_url):
            logger.error("❌ Health check failed - backend may not be running")
            return False
        
        # Test recognize endpoint
        if not test_recognize_endpoint(base_url, test_image_path):
            logger.error("❌ Recognition test failed")
            return False
        
        # Test photo search workflow
        if not test_photo_search_workflow(base_url, test_image_path):
            logger.error("❌ Photo search workflow failed")
            return False
        
        logger.info("🎉 All tests passed!")
        return True
        
    finally:
        # Clean up
        if os.path.exists(test_image_path):
            os.remove(test_image_path)
            logger.info(f"🧹 Cleaned up test file: {test_image_path}")

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)