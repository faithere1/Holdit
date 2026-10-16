import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let dropTypes: [UTType] = [.fileURL, .image, .plainText, .utf8PlainText, .text]

struct PanelView: View {
    @ObservedObject var store: Store
    var onClose: () -> Void
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.items) { item in
                        ItemRow(item: item, store: store)
                    }
                    .onInsert(of: dropTypes) { index, providers in
                        store.handleDrop(providers, at: index)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 360, height: 460)
        .onDrop(of: dropTypes, isTargeted: $dropTargeted) { providers in
            store.handleDrop(providers)
            return true
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 3)
                .opacity(dropTargeted ? 1 : 0)
                .allowsHitTesting(false)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.full.fill")
                .foregroundStyle(Color.accentColor)
            Text("Holdit").font(.headline)
            Text("\(store.items.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                store.pasteFromClipboard()
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .help("Add what you copied as a new row")
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Hide panel (app keeps running)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Drop files here")
                .font(.title3)
            Text("or press Paste to add what you copied")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

struct ItemRow: View {
    let item: HoldItem
    @ObservedObject var store: Store
    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                icon
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
            }
            .overlay(RowDragSource(item: item, store: store, tooltip: tooltip))
            HStack(spacing: 6) {
                Button {
                    store.copyToClipboard(item)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .help("Copy to clipboard")
                if item.kind == .file {
                    Button { store.reveal(item) } label: { Image(systemName: "folder") }
                        .help("Show in Finder")
                }
                Button { store.remove(item) } label: {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
                .help("Remove")
            }
            .buttonStyle(.borderless)
            .opacity(hovering ? 1 : 0.35)
        }
        .padding(.vertical, 3)
        .onHover { hovering = $0 }
    }

    private var tooltip: String {
        item.kind == .text ? (item.text ?? "") : "Double-click to open · drag out to use"
    }

    @ViewBuilder private var icon: some View {
        switch item.kind {
        case .file:
            Image(nsImage: NSWorkspace.shared.icon(forFile: store.fileURL(for: item).path))
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var title: String {
        switch item.kind {
        case .file: return item.name
        case .text:
            let firstLine = (item.text ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            return firstLine.trimmingCharacters(in: .whitespaces)
        }
    }

    private var subtitle: String {
        let when = RelativeDateTimeFormatter().localizedString(for: item.added, relativeTo: Date())
        switch item.kind {
        case .text:
            return "Text · \((item.text ?? "").count) chars · \(when)"
        case .file:
            let url = store.fileURL(for: item)
            let size = (try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize)
                ?? (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            let sizeText = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            return "\(sizeText) · \(when)"
        }
    }
}
