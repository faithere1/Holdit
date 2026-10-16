import AppKit
import SwiftUI

/// Makes a row draggable to Finder, Mail, browsers and other apps, using a real AppKit
/// dragging session. Also handles double-click, since a SwiftUI tap gesture here would
/// swallow the mouse drag. Dragging within the panel reorders (see Store.handleDrop).
struct RowDragSource: NSViewRepresentable {
    let item: HoldItem
    let store: Store
    let tooltip: String

    func makeNSView(context: Context) -> DragSourceView {
        let view = DragSourceView()
        update(view)
        return view
    }

    func updateNSView(_ view: DragSourceView, context: Context) {
        update(view)
    }

    private func update(_ view: DragSourceView) {
        view.item = item
        view.store = store
        view.toolTip = tooltip
    }
}

final class DragSourceView: NSView, NSDraggingSource {
    var item: HoldItem?
    var store: Store?
    private var mouseDownPoint: NSPoint?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = event.locationInWindow
        if event.clickCount == 2, let item, let store {
            store.open(item)
            mouseDownPoint = nil
        }
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownPoint = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint, let item, let store else { return }
        let p = event.locationInWindow
        guard hypot(p.x - start.x, p.y - start.y) > 3 else { return }
        mouseDownPoint = nil

        guard let writer = store.dragWriter(for: item) else { NSSound.beep(); return }
        let dragItem = NSDraggingItem(pasteboardWriter: writer)
        let image = dragImage(for: item, store: store)
        let origin = convert(event.locationInWindow, from: nil)
        dragItem.setDraggingFrame(
            NSRect(x: origin.x - image.size.width / 2, y: origin.y - image.size.height / 2,
                   width: image.size.width, height: image.size.height),
            contents: image)

        store.draggingID = item.id
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : [.copy, .move]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        store?.draggingID = nil
    }

    private func dragImage(for item: HoldItem, store: Store) -> NSImage {
        let image: NSImage
        switch item.kind {
        case .file:
            image = NSWorkspace.shared.icon(forFile: store.fileURL(for: item).path)
        case .text:
            image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil) ?? NSImage()
        }
        image.size = NSSize(width: 48, height: 48)
        return image
    }
}
