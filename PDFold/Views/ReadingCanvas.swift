import SwiftUI
import PDFKit

struct ReadingCanvas: View {
    var viewModel: WorkspaceViewModel

    var body: some View {
        PDFViewRepresentable(pdf: viewModel.combinedPDF)
            .ignoresSafeArea()
    }
}

// MARK: - NSViewRepresentable bridge

struct PDFViewRepresentable: NSViewRepresentable {
    var pdf: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.displaysPageBreaks = false   // boundary pages provide visual separation
        view.backgroundColor = .windowBackgroundColor
        view.document = pdf
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        // Only replace document when content actually changed (identity check).
        if nsView.document !== pdf {
            let previousPage = nsView.currentPage
            nsView.document = pdf
            // Try to restore scroll position to the same logical page
            if let page = previousPage {
                nsView.go(to: page)
            }
        }
    }
}
