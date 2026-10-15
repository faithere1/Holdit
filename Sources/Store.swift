import AppKit
import Foundation
import UniformTypeIdentifiers

enum ItemKind: String, Codable {
    case file
    case text
}

struct HoldItem: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: ItemKind
    var name: String
    var text: String?
    var added: Date
}

/// Keeps the list and the copied files on disk:
///   ~/Library/Application Support/Holdit/items.json   – the ordered list
///   ~/Library/Application Support/Holdit/files/<id>/  – a private copy of each dropped file
final class Store: ObservableObject {
    @Published var items: [HoldItem] = []

    let root: URL
    let filesDir: URL
    let dragDir: URL
    private let indexURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        root = support.appendingPathComponent("Holdit", isDirectory: true)
        filesDir = root.appendingPathComponent("files", isDirectory: true)
        dragDir = root.appendingPathComponent("drag-out", isDirectory: true)
        indexURL = root.appendingPathComponent("items.json")

        try? FileManager.default.removeItem(at: dragDir)
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dragDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([HoldItem].self, from: data) else { return }
        items = decoded.filter { $0.kind == .text || FileManager.default.fileExists(atPath: fileURL(for: $0).path) }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(items) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    func fileURL(for item: HoldItem) -> URL {
        filesDir.appendingPathComponent(item.id.uuidString, isDirectory: true)
            .appendingPathComponent(item.name)
    }

    // MARK: Adding

    private func insert(_ item: HoldItem, at index: Int?) {
        let i = min(max(index ?? 0, 0), items.count)
        items.insert(item, at: i)
        save()
    }

    func addFile(from url: URL, at index: Int? = nil) {
        // Ignore our own files being dragged back in.
        if url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path) { return }

        let id = UUID()
        let dir = filesDir.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: dir.appendingPathComponent(url.lastPathComponent))
        } catch {
            try? FileManager.default.removeItem(at: dir)
            NSSound.beep()
            return
        }
        insert(HoldItem(id: id, kind: .file, name: url.lastPathComponent, text: nil, added: Date()), at: index)
    }

    func addText(_ text: String, at index: Int? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        insert(HoldItem(id: UUID(), kind: .text, name: "Text", text: text, added: Date()), at: index)
    }

    func addImage(_ image: NSImage, at index: Int? = nil) {
        guard let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let name = "Pasted image \(formatter.string(from: Date())).png"

        let id = UUID()
        let dir = filesDir.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try png.write(to: dir.appendingPathComponent(name))
        } catch {
            NSSound.beep()
            return
        }
        insert(HoldItem(id: id, kind: .file, name: name, text: nil, added: Date()), at: index)
    }

    /// Paste button: files, then text, then images from the clipboard.
    func pasteFromClipboard() {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            for url in urls.reversed() { addFile(from: url) }
            return
        }
        if let text = pb.string(forType: .string), !text.isEmpty {
            addText(text)
            return
        }
        if let image = NSImage(pasteboard: pb) {
            addImage(image)
            return
        }
        NSSound.beep()
    }

    /// Drops coming from Finder, browsers, editors, etc.
    func handleDrop(_ providers: [NSItemProvider], at index: Int? = nil) {
        for provider in providers.reversed() {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    var url: URL?
                    if let data = data as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else if let u = data as? URL { url = u }
                    guard let url else { return }
                    DispatchQueue.main.async { self.addFile(from: url, at: index) }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self),
                      !provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    guard let image = image as? NSImage else { return }
                    DispatchQueue.main.async { self.addImage(image, at: index) }
                }
            } else if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                    guard let string = string as? String else { return }
                    DispatchQueue.main.async { self.addText(string, at: index) }
                }
            }
        }
    }

    // MARK: Using items

    func remove(_ item: HoldItem) {
        if item.kind == .file {
            try? FileManager.default.removeItem(at: filesDir.appendingPathComponent(item.id.uuidString))
        }
        items.removeAll { $0.id == item.id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func copyToClipboard(_ item: HoldItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text: pb.setString(item.text ?? "", forType: .string)
        case .file: pb.writeObjects([fileURL(for: item) as NSURL])
        }
    }

    func open(_ item: HoldItem) {
        switch item.kind {
        case .file: NSWorkspace.shared.open(fileURL(for: item))
        case .text: copyToClipboard(item)
        }
    }

    func reveal(_ item: HoldItem) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL(for: item)])
    }

    /// What gets handed to Finder/other apps when a row is dragged out.
    /// Files are handed over as a fresh copy so the stored one is never moved away.
    func dragProvider(for item: HoldItem) -> NSItemProvider {
        switch item.kind {
        case .text:
            return NSItemProvider(object: (item.text ?? "") as NSString)
        case .file:
            let source = fileURL(for: item)
            let dir = dragDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let dest = dir.appendingPathComponent(item.name)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: source, to: dest)
                return NSItemProvider(contentsOf: dest) ?? NSItemProvider()
            } catch {
                return NSItemProvider(contentsOf: source) ?? NSItemProvider()
            }
        }
    }
}
