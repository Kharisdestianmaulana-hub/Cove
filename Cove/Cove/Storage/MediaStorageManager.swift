import AppKit
import AVFoundation
import Foundation
import ImageIO

/// Handles local media saving, directory scanning, deletion, and thumbnail generation.
final class MediaStorageManager {
    private let fileManager = FileManager.default
    private let supportedPhotoExtensions: Set<String> = ["jpg", "jpeg", "heic", "heif", "png"]
    private let supportedVideoExtensions: Set<String> = ["mov", "mp4", "m4v"]
    private let customBookmarkKey = "cove.customSaveFolderBookmark"
    private var activeSecurityScopedURL: URL?

    deinit {
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }

    private lazy var filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Active save directory (custom user-selected folder if configured, otherwise ~/Pictures/Cove).
    func saveDirectoryURL() throws -> URL {
        if let customURL = resolveCustomSaveDirectory() {
            if !fileManager.fileExists(atPath: customURL.path) {
                try fileManager.createDirectory(at: customURL, withIntermediateDirectories: true)
            }
            return customURL
        }

        guard let picturesURL = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "com.studiokharis.cove.storage",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate the Pictures directory."]
            )
        }
        let coveDirectory = picturesURL.appendingPathComponent("Cove", isDirectory: true)
        if !fileManager.fileExists(atPath: coveDirectory.path) {
            try fileManager.createDirectory(at: coveDirectory, withIntermediateDirectories: true)
        }
        return coveDirectory
    }

    var hasCustomSaveDirectory: Bool {
        UserDefaults.standard.data(forKey: customBookmarkKey) != nil
    }

    func currentSaveDirectoryDisplayPath() -> String {
        if let url = try? saveDirectoryURL() {
            return (url.path as NSString).abbreviatingWithTildeInPath
        }
        return "~/Pictures/Cove"
    }

    /// Prompts the user to select a custom save directory and stores a security-scoped bookmark.
    func chooseCustomSaveDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        panel.message = "Choose where Cove should save captured photos and videos."

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return nil
        }

        do {
            let bookmark = try selectedURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: customBookmarkKey)
            activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
            _ = selectedURL.startAccessingSecurityScopedResource()
            activeSecurityScopedURL = selectedURL
            return selectedURL
        } catch {
            return nil
        }
    }

    /// Clears the custom save directory bookmark and reverts to ~/Pictures/Cove.
    func resetSaveDirectoryToDefault() {
        UserDefaults.standard.removeObject(forKey: customBookmarkKey)
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedURL = nil
    }

    private func resolveCustomSaveDirectory() -> URL? {
        if let active = activeSecurityScopedURL {
            return active
        }
        guard let bookmarkData = UserDefaults.standard.data(forKey: customBookmarkKey) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        activeSecurityScopedURL = url
        return url
    }

    /// Generates a unique destination URL for a captured photo or video.
    func makeMediaURL(fileExtension: String) throws -> URL {
        let directory = try saveDirectoryURL()
        let timestamp = filenameFormatter.string(from: Date())
        let baseName = "Cove_\(timestamp)"
        var candidate = directory.appendingPathComponent("\(baseName).\(fileExtension)")
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)_\(counter).\(fileExtension)")
            counter += 1
        }
        return candidate
    }

    /// Saves still image data atomically and returns the saved file URL.
    func savePhotoData(_ data: Data, fileExtension: String) throws -> URL {
        let destination = try makeMediaURL(fileExtension: fileExtension)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    /// Moves a recorded temporary video file into the Cove save directory.
    func moveRecordedVideo(from tempURL: URL) throws -> URL {
        let destination = try makeMediaURL(fileExtension: "mov")
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempURL, to: destination)
        return destination
    }

    /// Scans the Cove save directory and returns captured media sorted newest first.
    func loadCapturedMedia() -> [MediaItem] {
        guard let directory = try? saveDirectoryURL() else { return [] }

        let keys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var items: [MediaItem] = []
        for url in contents {
            let ext = url.pathExtension.lowercased()
            let isPhoto = supportedPhotoExtensions.contains(ext)
            let isVideo = supportedVideoExtensions.contains(ext)
            guard isPhoto || isVideo else { continue }

            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile != false else { continue }

            let createdAt = values?.creationDate ?? values?.contentModificationDate ?? Date.distantPast
            let fileSize = Int64(values?.fileSize ?? 0)

            items.append(
                MediaItem(
                    id: url,
                    url: url,
                    isVideo: isVideo,
                    createdAt: createdAt,
                    fileSizeBytes: fileSize
                )
            )
        }

        return items.sorted { $0.createdAt > $1.createdAt }
    }

    /// Moves a media file to the macOS Trash.
    func trashMedia(_ item: MediaItem) throws {
        try fileManager.trashItem(at: item.url, resultingItemURL: nil)
    }

    /// Generates a lightweight thumbnail for an image or video URL.
    func generateThumbnail(for url: URL, isVideo: Bool, maxPixelSize: CGFloat = 320) -> NSImage? {
        if !isVideo {
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
                ]
                if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                }
            }
            return NSImage(contentsOf: url)
        }

        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)

        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Reveals the specified media file in Finder.
    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens the media file with the default macOS application.
    func openWithSystem(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
