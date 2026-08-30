import Foundation
import UIKit

struct SavedPhotoProject: Codable, Identifiable, Equatable {
    let id: UUID
    var updatedAt: Date
    var projectName: String?
    var sizeID: String
    var customWidth: Double?
    var customHeight: Double?
    var customName: String?
    var backgroundID: String
    var backgroundName: String
    var backgroundStartHex: String
    var backgroundEndHex: String?
    var backgroundGradient: Bool
    var backgroundRadial: Bool
    var backgroundRemoved: Bool
    var cropScale: Double
    var cropOffsetX: Double
    var cropOffsetY: Double
    var cropRotation: Double
    var cropFlipped: Bool
    var skinSmoothing: Double
    var brightness: Double
    var contrast: Double
    var saturation: Double
    var sharpness: Double
    var warmth: Double
    var highlights: Double
    var shadows: Double
    var fade: Double

    var title: String {
        if let projectName, !projectName.isEmpty { return projectName }
        if let customName { return customName }
        return IDPhotoSize.allSizes.first(where: { $0.id == sizeID })?.name ?? "証明写真"
    }
}

@MainActor
final class ProjectStore: ObservableObject {
    static let shared = ProjectStore()
    @Published private(set) var projects: [SavedPhotoProject] = []
    private let fm = FileManager.default
    private let root: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PhotoProjects", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var url = root; try? url.setResourceValues(values)
        reload()
    }

    func reload() {
        let urls = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        projects = urls.compactMap { url -> SavedPhotoProject? in
            guard url.pathExtension == "json", let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(SavedPhotoProject.self, from: data)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ project: SavedPhotoProject, original: UIImage, cutout: UIImage?, preview: UIImage?) throws {
        guard let originalData = original.jpegData(compressionQuality: 0.96) else { throw StoreError.imageEncoding }
        try originalData.write(to: imageURL(project.id, "original.jpg"), options: .atomic)
        if let data = cutout?.pngData() { try data.write(to: imageURL(project.id, "cutout.png"), options: .atomic) }
        if let data = preview?.jpegData(compressionQuality: 0.82) { try data.write(to: imageURL(project.id, "preview.jpg"), options: .atomic) }
        try encoder.encode(project).write(to: metadataURL(project.id), options: .atomic)
        reload()
        for old in projects.dropFirst(12) { delete(old.id) }
    }

    func project(id: UUID) -> SavedPhotoProject? { projects.first { $0.id == id } }
    func loadImages(for id: UUID) -> (original: UIImage, cutout: UIImage?)? {
        guard let original = UIImage(contentsOfFile: imageURL(id, "original.jpg").path) else { return nil }
        return (original, UIImage(contentsOfFile: imageURL(id, "cutout.png").path))
    }
    func thumbnail(for id: UUID) -> UIImage? { UIImage(contentsOfFile: imageURL(id, "preview.jpg").path) }

    func rename(_ id: UUID, to name: String) {
        guard var item = project(id: id) else { return }
        item.projectName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = try? encoder.encode(item) { try? data.write(to: metadataURL(id), options: .atomic) }
        reload()
    }
    func delete(_ id: UUID) {
        for suffix in ["original.jpg", "cutout.png", "preview.jpg"] { try? fm.removeItem(at: imageURL(id, suffix)) }
        try? fm.removeItem(at: metadataURL(id)); reload()
    }
    func deleteAll() { for item in projects { delete(item.id) } }
    var storageBytes: Int64 {
        ((try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey])) ?? []).reduce(0) {
            $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    private func metadataURL(_ id: UUID) -> URL { root.appendingPathComponent("\(id.uuidString).json") }
    private func imageURL(_ id: UUID, _ suffix: String) -> URL { root.appendingPathComponent("\(id.uuidString)-\(suffix)") }
    enum StoreError: Error { case imageEncoding }
}
