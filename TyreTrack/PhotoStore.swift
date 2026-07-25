//
//  PhotoStore.swift
//  TyreTrack
//
//  Vehicle photos live on disk in Documents/VehiclePhotos, never inside
//  the UserDefaults JSON blob. A vehicle stores only its file name.
//
//  · JPEG, longest edge capped at 2048px
//  · atomic writes
//  · deleted with the vehicle and on every photo replace
//  · orphans pruned once at launch
//

import UIKit

enum PhotoStore {

    private static let folderName = "VehiclePhotos"

    /// Documents/VehiclePhotos, created on first use.
    private static var directory: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory,
                                                  in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for fileName: String) -> URL? {
        directory?.appendingPathComponent(fileName)
    }

    // MARK: - Write

    /// Downscale to ≤2048px on the longest edge and write atomically.
    /// Returns the stored file name.
    @discardableResult
    static func save(_ image: UIImage) -> String? {
        guard let data = jpegData(from: image) else { return nil }
        return save(data: data)
    }

    /// Store already-encoded image data (used by the one-time migration of
    /// photos that used to live inside the defaults blob).
    @discardableResult
    static func save(data: Data) -> String? {
        guard let dir = directory else { return nil }
        let name = UUID().uuidString + ".jpg"
        let target = dir.appendingPathComponent(name)
        do {
            try data.write(to: target, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    // MARK: - Read

    /// Decoded images are cached so scrolling a garage list doesn't hit
    /// the disk on every frame.
    private static let cache = NSCache<NSString, UIImage>()

    static func image(named fileName: String?) -> UIImage? {
        guard let fileName = fileName else { return nil }
        if let cached = cache.object(forKey: fileName as NSString) { return cached }
        guard let url = url(for: fileName),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    // MARK: - Delete

    static func delete(_ fileName: String?) {
        guard let fileName = fileName, let url = url(for: fileName) else { return }
        cache.removeObject(forKey: fileName as NSString)
        try? FileManager.default.removeItem(at: url)
    }

    /// Remove any file no longer referenced by a vehicle. Called once at launch.
    static func pruneOrphans(keeping referenced: Set<String>) {
        guard let dir = directory,
              let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for file in files where !referenced.contains(file) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
        }
    }

    // MARK: - Encoding

    static func jpegData(from image: UIImage,
                         maxDimension: CGFloat = 2048,
                         quality: CGFloat = 0.8) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / max(longest, 1))
        let newSize = CGSize(width: (image.size.width * scale).rounded(),
                             height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return scaled.jpegData(compressionQuality: quality)
    }
}
