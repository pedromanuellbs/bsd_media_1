"""
Google Drive Photo Session Manager
Handles fetching photos from Google Drive folders for face matching
"""

import os
import json
import logging
import requests
import time
from urllib.parse import urlparse
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)

class GoogleDrivePhotoManager:
    """Manages Google Drive photo operations"""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://www.googleapis.com/drive/v3"
        
    def extract_folder_id(self, folder_url: str) -> Optional[str]:
        """Extract folder ID from Google Drive URL"""
        try:
            # Handle different Google Drive URL formats
            if '/folders/' in folder_url:
                return folder_url.split('/folders/')[1].split('?')[0].split('/')[0]
            elif '/d/' in folder_url:
                return folder_url.split('/d/')[1].split('/')[0]
            elif 'id=' in folder_url:
                return folder_url.split('id=')[1].split('&')[0]
            else:
                logger.error(f"❌ Could not extract folder ID from URL: {folder_url}")
                return None
                
        except Exception as e:
            logger.error(f"❌ Error extracting folder ID: {e}")
            return None
    
    def get_folder_photos(self, folder_url: str, max_photos: int = 100) -> List[Dict]:
        """Get all photos from a Google Drive folder"""
        try:
            folder_id = self.extract_folder_id(folder_url)
            if not folder_id:
                raise ValueError("Could not extract folder ID from URL")
            
            logger.info(f"📁 Fetching photos from folder: {folder_id}")
            
            # Build API request
            url = f"{self.base_url}/files"
            params = {
                'q': f"'{folder_id}' in parents and mimeType contains 'image/'",
                'fields': 'files(id,name,mimeType,thumbnailLink,webContentLink,webViewLink)',
                'key': self.api_key,
                'pageSize': min(max_photos, 1000),
                'orderBy': 'createdTime desc'
            }
            
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            photos = data.get('files', [])
            
            # Filter for image files and add download URLs
            photo_list = []
            for photo in photos:
                if self._is_image_file(photo.get('mimeType', '')):
                    photo_info = {
                        'id': photo['id'],
                        'name': photo['name'],
                        'mimeType': photo['mimeType'],
                        'thumbnailLink': photo.get('thumbnailLink'),
                        'webContentLink': photo.get('webContentLink'),
                        'webViewLink': photo.get('webViewLink'),
                        'downloadUrl': f"https://drive.google.com/uc?export=download&id={photo['id']}"
                    }
                    photo_list.append(photo_info)
            
            logger.info(f"✅ Found {len(photo_list)} photos in folder")
            return photo_list
            
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Network error fetching folder photos: {e}")
            raise
        except Exception as e:
            logger.error(f"❌ Error fetching folder photos: {e}")
            raise
    
    def _is_image_file(self, mime_type: str) -> bool:
        """Check if file is an image based on MIME type"""
        image_types = [
            'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 
            'image/bmp', 'image/tiff', 'image/webp'
        ]
        return mime_type.lower() in image_types
    
    def get_photo_sessions_from_firestore(self, limit: int = 50) -> List[Dict]:
        """Get photo sessions from Firestore (placeholder)"""
        # This would typically connect to Firestore and fetch photo sessions
        # For now, return dummy data
        logger.info("📋 Fetching photo sessions from database...")
        
        # In a real implementation, this would query Firestore
        # and return actual photo session data
        dummy_sessions = [
            {
                'id': 'session_1',
                'title': 'Wedding Photography Session',
                'driveLink': 'https://drive.google.com/drive/folders/1example1',
                'photographerId': 'photographer_1',
                'date': '2024-01-15',
                'location': 'Jakarta Convention Center'
            },
            {
                'id': 'session_2', 
                'title': 'Corporate Event Photography',
                'driveLink': 'https://drive.google.com/drive/folders/1example2',
                'photographerId': 'photographer_2',
                'date': '2024-01-20',
                'location': 'Hotel Mulia Jakarta'
            }
        ]
        
        return dummy_sessions
    
    def download_photo(self, photo_url: str, temp_dir: str) -> str:
        """Download a photo from Google Drive"""
        try:
            logger.info(f"📥 Downloading photo: {photo_url}")
            
            # Extract file ID if needed
            file_id = None
            if '/d/' in photo_url:
                file_id = photo_url.split('/d/')[1].split('/')[0]
            elif 'id=' in photo_url:
                file_id = photo_url.split('id=')[1].split('&')[0]
            
            if file_id:
                download_url = f"https://drive.google.com/uc?export=download&id={file_id}"
            else:
                download_url = photo_url
            
            # Download the file
            response = requests.get(download_url, timeout=30)
            response.raise_for_status()
            
            # Save to temporary file
            filename = f"photo_{file_id or 'unknown'}_{int(time.time())}.jpg"
            filepath = os.path.join(temp_dir, filename)
            
            with open(filepath, 'wb') as f:
                f.write(response.content)
            
            logger.info(f"✅ Photo downloaded: {filename}")
            return filepath
            
        except Exception as e:
            logger.error(f"❌ Error downloading photo: {e}")
            raise

def get_all_photos_for_matching(api_key: str, max_photos_per_session: int = 100) -> List[Dict]:
    """Get all photos from all photo sessions for face matching"""
    try:
        manager = GoogleDrivePhotoManager(api_key)
        
        # Get all photo sessions
        sessions = manager.get_photo_sessions_from_firestore()
        
        all_photos = []
        for session in sessions:
            try:
                session_photos = manager.get_folder_photos(
                    session['driveLink'], 
                    max_photos_per_session
                )
                
                # Add session info to each photo
                for photo in session_photos:
                    photo['sessionId'] = session['id']
                    photo['sessionTitle'] = session['title']
                    photo['sessionDate'] = session['date']
                    photo['sessionLocation'] = session['location']
                    
                all_photos.extend(session_photos)
                
            except Exception as e:
                logger.error(f"❌ Error fetching photos from session {session['id']}: {e}")
                continue
        
        logger.info(f"✅ Total photos collected: {len(all_photos)}")
        return all_photos
        
    except Exception as e:
        logger.error(f"❌ Error getting photos for matching: {e}")
        return []

if __name__ == "__main__":
    # Test the Google Drive manager
    import time
    
    logging.basicConfig(level=logging.INFO)
    
    api_key = "AIzaSyC_vPd6yPwYQ60Pn-tuR3Nly_7mgXZcxGk"
    
    # Test folder photo retrieval
    manager = GoogleDrivePhotoManager(api_key)
    
    # Test URL (replace with actual Google Drive folder URL)
    test_folder_url = "https://drive.google.com/drive/folders/1example"
    
    try:
        photos = manager.get_folder_photos(test_folder_url, max_photos=10)
        print(f"Found {len(photos)} photos")
        for photo in photos[:3]:  # Show first 3 photos
            print(f"- {photo['name']} ({photo['mimeType']})")
    except Exception as e:
        print(f"Test failed: {e}")