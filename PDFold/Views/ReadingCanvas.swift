import SwiftUI
import PDFKit

struct ReadingCanvas: View {
    @Bindable var viewModel: WorkspaceViewModel

    var body: some View {
        PDFViewRepresentable(viewModel: viewModel)
            .ignoresSafeArea()
    }
}

// MARK: - NSViewRepresentable

struct PDFViewRepresentable: NSViewRepresentable {
    @Bindable var viewModel: WorkspaceViewModel

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.displaysPageBreaks = false
        view.backgroundColor = .windowBackgroundColor

        let click = NSClickGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handleClick(_:)))
        click.numberOfClicksRequired = 1
        view.addGestureRecognizer(click)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: view
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.jumpToSelection(_:)),
            name: .pdfoldJumpToSelection,
            object: nil
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.jumpToPageIndex(_:)),
            name: .pdfoldJumpToPageIndex,
            object: nil
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.printDocument(_:)),
            name: .pdfoldPrint,
            object: nil
        )

        context.coordinator.pdfView = view
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== viewModel.combinedPDF {
            nsView.document = viewModel.combinedPDF
        }
        context.coordinator.viewModel = viewModel

        // Update ink overlay visibility
        context.coordinator.inkOverlay.isHidden = (viewModel.currentTool != .ink)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var viewModel: WorkspaceViewModel
        weak var pdfView: PDFView?
        let inkOverlay = InkOverlayView()

        init(viewModel: WorkspaceViewModel) {
            self.viewModel = viewModel
        }

        @objc func selectionChanged(_ notification: Notification) {
            // Auto-apply highlight when tool is active and there's a selection
            guard viewModel.currentTool == .highlight,
                  let pdfView,
                  let selection = pdfView.currentSelection,
                  !(selection.string?.isEmpty ?? true) else { return }
            viewModel.applyHighlight(to: selection)
            pdfView.clearSelection()
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard viewModel.currentTool == .note,
                  let pdfView else { return }
            let viewPoint = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: viewPoint, nearest: false) else { return }
            let pagePoint = pdfView.convert(viewPoint, to: page)
            viewModel.addNote(at: pagePoint, on: page)
        }

        @objc func jumpToSelection(_ notification: Notification) {
            guard let selection = notification.object as? PDFSelection else { return }
            pdfView?.go(to: selection)
            pdfView?.setCurrentSelection(selection, animate: true)
        }

        @objc func jumpToPageIndex(_ notification: Notification) {
            guard let idx = notification.object as? Int,
                  let page = pdfView?.document?.page(at: idx) else { return }
            pdfView?.go(to: page)
        }

        @objc func printDocument(_ notification: Notification) {
            guard let pdfView else { return }
            viewModel.printWorkspace(pdfView: pdfView)
        }
    }
}

// MARK: - Ink drawing overlay

final class InkOverlayView: NSView {
    var onStrokeCommitted: ((NSBezierPath) -> Void)?

    private var currentPath: NSBezierPath?
    private var committedPaths: [NSBezierPath] = []
    private let strokeColor: NSColor = .systemBlue
    private let lineWidth: CGFloat = 2.0

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.move(to: point)
        currentPath = path
    }

    override func mouseDragged(with event: NSEvent) {
        guard let path = currentPath else { return }
        let point = convert(event.locationInWindow, from: nil)
        path.line(to: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let path = currentPath, path.elementCount > 1 else {
            currentPath = nil
            return
        }
        let committed = path
        committedPaths.append(committed)
        currentPath = nil
        onStrokeCommitted?(committed)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        strokeColor.withAlphaComponent(0.8).setStroke()
        committedPaths.forEach { $0.stroke() }
        currentPath?.stroke()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isHidden ? nil : super.hitTest(point)
    }
}
