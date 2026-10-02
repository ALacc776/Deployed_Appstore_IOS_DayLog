//
//  PhotoManager.swift
//  Jour
//
//  Created by andapple on 16/9/2025.
//

import Foundation
import UIKit
import Photos

/// Manages photo storage and retrieval for journal entries
/// Handles saving photos to disk and generating thumbnails
class PhotoManager {
    // MARK: - Singleton
    
    static let shared = PhotoManager()
    
    // MARK: - Private Properties
    
    /// Directory for storing photos
    private let photosDirectory: URL
    
    /// Maximum thumbnail size
    private let thumbnailSize = CGSize(width: 300, height: 300)
    
    /// Cache for thumbnails to improve performance
    private let imageCache = NSCache<NSString, UIImage>()
    
    // MARK: - Initialization
    
    private init() {
        // Create photos directory in Documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        photosDirectory = documentsPath.appendingPathComponent("photos")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        
        // Configure cache limits (optional but good practice)
        imageCache.countLimit = 100 // Cache up to 100 thumbnails
    }
    
    /// Background queue for photo operations
    private let photoQueue = DispatchQueue(label: "com.jour.photos", qos: .userInitiated)
    
    // MARK: - Public Methods
    
    /// Saves a photo asynchronously and returns the filename
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - completion: Closure called with filename (or nil if failed)
    func savePhoto(_ image: UIImage, completion: @escaping (String?) -> Void) {
        photoQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Generate unique filename
            let filename = "\(UUID().uuidString).jpg"
            let fileURL = self.photosDirectory.appendingPathComponent(filename)
            
            // Compress and save image (heavy operation)
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            do {
                try imageData.write(to: fileURL)
                
                // Cache the full image as thumbnail (or resize and cache) to make it instantly available
                // For now, let's just clear cache for this file to be safe, or cache explicitly if we reasoned
                
                DispatchQueue.main.async {
                    completion(filename)
                }
            } catch {
                print("Failed to save photo: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    /// Returns the on-disk location of a photo (used for backup and restore)
    /// - Parameter filename: The photo filename
    /// - Returns: File URL inside the photos directory
    func photoURL(filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    /// Loads a photo from filename
    /// - Parameter filename: The filename to load
    /// - Returns: UIImage if found, nil otherwise
    func loadPhoto(filename: String) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        
        guard let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }
    
    /// Loads a thumbnail version of a photo
    /// - Parameter filename: The filename to load
    /// - Returns: Resized UIImage if found, nil otherwise
    func loadThumbnail(filename: String) -> UIImage? {
        // Check cache first
        if let cachedImage = imageCache.object(forKey: filename as NSString) {
            return cachedImage
        }
        
        // Load and resize
        guard let fullImage = loadPhoto(filename: filename) else {
            return nil
        }
        
        let thumbnail = fullImage.resized(to: thumbnailSize)
        
        // Cache the result
        imageCache.setObject(thumbnail, forKey: filename as NSString)
        
        return thumbnail
    }
    
    /// Deletes a photo file
    /// - Parameter filename: The filename to delete
    func deletePhoto(filename: String) {
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Saves image to device's Camera Roll
    /// - Parameter image: The UIImage to save
    func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
    
    /// Gets total storage used by photos
    /// - Returns: Size in bytes
    func getTotalPhotoSize() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }
}

// MARK: - UIImage Extension for Resizing

extension UIImage {
    /// Resizes image to fit within specified size while maintaining aspect ratio
    func resized(to targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

