import SwiftUI
import PDFKit

struct SignaturePalette: View {
    @Bindable var viewModel: WorkspaceViewModel
    @State private var savedSignatures: [Data] = SignatureStore.shared.all()
    @State private var isDrawing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Signatures")
                .font(.headline)
                .padding(.horizontal)

            if savedSignatures.isEmpty {
                Text("No saved signatures.\nCreate one below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(savedSignatures.indices, id: \.self) { i in
                            SignatureThumbnail(data: savedSignatures[i])
                                .onTapGesture {
                                    viewModel.pendingSignatureData = savedSignatures[i]
                                    viewModel.currentTool = .signature
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Divider()

            Button {
                isDrawing = true
            } label: {
                Label("Draw Signature", systemImage: "pencil.and.outline")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(width: 300)
        .sheet(isPresented: $isDrawing) {
            SignatureDrawingView { newData in
                SignatureStore.shared.save(newData)
                savedSignatures = SignatureStore.shared.all()
                viewModel.pendingSignatureData = newData
                viewModel.currentTool = .signature
                isDrawing = false
            } onCancel: {
                isDrawing = false
            }
        }
    }
}

// MARK: - Signature thumbnail

struct SignatureThumbnail: View {
    var data: Data

    var body: some View {
        if let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 36)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
    }
}

// MARK: - Signature drawing sheet

struct SignatureDrawingView: View {
    var onSave: (Data) -> Void
    var onCancel: () -> Void

    @State private var paths: [NSBezierPath] = []
    @State private var currentPath: NSBezierPath?

    var body: some View {
        VStack(spacing: 16) {
            Text("Draw your signature")
                .font(.headline)

            SignatureCanvas(paths: $paths)
                .frame(width: 360, height: 140)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.4)))

            HStack {
                Button("Clear") { paths = [] }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    if let data = renderSignature(paths: paths, size: CGSize(width: 360, height: 140)) {
                        onSave(data)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(paths.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func renderSignature(paths: [NSBezierPath], size: CGSize) -> Data? {
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            paths.forEach {
                $0.lineWidth = 2
                $0.stroke()
            }
            return true
        }
        guard let tiff = image.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff) else { return nil }
        return bmp.representation(using: .png, properties: [:])
    }
}

// MARK: - NSView canvas for drawing

struct SignatureCanvas: NSViewRepresentable {
    @Binding var paths: [NSBezierPath]

    func makeNSView(context: Context) -> SignatureCanvasView {
        let v = SignatureCanvasView()
        v.onPathsChanged = { context.coordinator.paths = $0; paths = $0 }
        return v
    }

    func updateNSView(_ nsView: SignatureCanvasView, context: Context) {
        nsView.paths = paths
        nsView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var paths: [NSBezierPath] = [] }
}

final class SignatureCanvasView: NSView {
    var paths: [NSBezierPath] = []
    var onPathsChanged: (([NSBezierPath]) -> Void)?
    private var currentPath: NSBezierPath?

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let path = NSBezierPath()
        path.lineWidth = 2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: p)
        currentPath = path
    }

    override func mouseDragged(with event: NSEvent) {
        guard let path = currentPath else { return }
        path.line(to: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let path = currentPath else { return }
        paths.append(path)
        currentPath = nil
        onPathsChanged?(paths)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        dirtyRect.fill()
        NSColor.black.setStroke()
        paths.forEach { $0.stroke() }
        currentPath?.stroke()
    }
}

// MARK: - Signature persistence

final class SignatureStore {
    static let shared = SignatureStore()
    private let dir: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        dir = support.appendingPathComponent("PDFold/Signatures", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func all() -> [Data] {
        (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))
            .map { $0.compactMap { try? Data(contentsOf: $0) } } ?? []
    }

    func save(_ data: Data) {
        let url = dir.appendingPathComponent("\(UUID().uuidString).png")
        try? data.write(to: url)
    }
}
