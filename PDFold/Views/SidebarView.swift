import SwiftUI
import PDFKit

struct SidebarView: View {
    var viewModel: WorkspaceViewModel
    @State private var expandedDocs: Set<UUID> = []

    var body: some View {
        List {
            ForEach(viewModel.document.workspace.documents) { member in
                MemberDocRow(member: member, viewModel: viewModel, expandedDocs: $expandedDocs)
            }
            .onMove { viewModel.moveDocument(from: $0, to: $1) }
            .onDelete { viewModel.removeDocument(at: $0) }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button { openPDFs() } label: {
                    Image(systemName: "plus")
                }
                .help("Add PDFs to workspace")
            }
        }
    }

    private func openPDFs() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK {
            viewModel.importPDFs(urls: panel.urls)
        }
    }
}

// MARK: - Member document row with expandable thumbnail strip

struct MemberDocRow: View {
    var member: MemberDocument
    var viewModel: WorkspaceViewModel
    @Binding var expandedDocs: Set<UUID>

    private var isExpanded: Bool {
        get { expandedDocs.contains(member.id) }
        nonmutating set { if newValue { expandedDocs.insert(member.id) } else { expandedDocs.remove(member.id) } }
    }

    private var sourcePDF: PDFDocument? {
        viewModel.loadedPDFs.first(where: { $0.0.id == member.id })?.1
    }

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(get: { isExpanded }, set: { isExpanded = $0 })
        ) {
            if let pdf = sourcePDF {
                ThumbnailStrip(pdf: pdf)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.callout)
                        .lineLimit(1)
                    Text("\(member.pageRefs.count) page\(member.pageRefs.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 3)
        }
    }
}

// MARK: - Thumbnail strip

struct ThumbnailStrip: View {
    var pdf: PDFDocument

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<pdf.pageCount, id: \.self) { i in
                if let page = pdf.page(at: i) {
                    ThumbnailCell(page: page, pageNumber: i + 1)
                }
            }
        }
        .padding(.leading, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Individual thumbnail cell with async rendering

struct ThumbnailCell: View {
    var page: PDFPage
    var pageNumber: Int
    @State private var thumbnail: NSImage? = nil

    private static let thumbSize = CGSize(width: 52, height: 68)

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Self.thumbSize.width, height: Self.thumbSize.height)
                        .cornerRadius(3)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: Self.thumbSize.width, height: Self.thumbSize.height)
                }
            }
            Text("p. \(pageNumber)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .task(id: pageNumber) {
            guard thumbnail == nil else { return }
            let size = Self.thumbSize
            let p = page
            thumbnail = await Task.detached(priority: .utility) {
                p.thumbnail(of: size, for: .mediaBox)
            }.value
        }
    }
}
