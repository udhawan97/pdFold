import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct SidebarView: View {
    var viewModel: WorkspaceViewModel
    @State private var expandedDocs: Set<UUID> = []

    var body: some View {
        List {
            ForEach(viewModel.memberDocuments) { member in
                MemberDocRow(member: member, viewModel: viewModel, expandedDocs: $expandedDocs)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
            }
            .onMove { viewModel.moveDocument(from: $0, to: $1) }
            .onDelete { viewModel.removeDocument(at: $0) }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.dsSurface)
    }
}

// MARK: - Member document row

struct MemberDocRow: View {
    var member: MemberDocument
    var viewModel: WorkspaceViewModel
    @Binding var expandedDocs: Set<UUID>
    @State private var isHovered = false

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
                ThumbnailStrip(member: member, pdf: pdf, viewModel: viewModel)
            }
        } label: {
            HStack(spacing: .dsSM) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsAccent)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.dsTextPrimary)
                        .lineLimit(1)
                    Text("\(member.pageRefs.count) page\(member.pageRefs.count == 1 ? "" : "s")")
                        .font(.dsCaption())
                        .foregroundStyle(Color.dsTextTertiary)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.horizontal, .dsSM)
        .padding(.vertical, 5)
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: .dsRadiusSm, style: .continuous)
                    .fill(Color.dsAccentSoft)
            }
        }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Thumbnail strip

struct ThumbnailStrip: View {
    var member: MemberDocument
    var pdf: PDFDocument
    var viewModel: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(zip(member.pageRefs.indices, member.pageRefs)), id: \.1) { i, refId in
                if let page = pdf.page(at: i),
                   let ref = viewModel.document.workspace.pageOrder.first(where: { $0.id == refId }) {
                    ThumbnailCell(page: page, pageRef: ref, pageNumber: i + 1, viewModel: viewModel)
                }
            }
        }
        .padding(.leading, 4)
        .padding(.vertical, 4)
    }
}

// MARK: - Individual thumbnail cell

struct ThumbnailCell: View {
    var page: PDFPage
    var pageRef: PageRef
    var pageNumber: Int
    var viewModel: WorkspaceViewModel
    @State private var thumbnail: NSImage? = nil
    @State private var isHovered = false

    private static let thumbSize = CGSize(width: 48, height: 64)
    private var isSelected: Bool { viewModel.selectedPageRefID == pageRef.id }

    var body: some View {
        HStack(spacing: .dsSM) {
            // Thumbnail image
            Group {
                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Self.thumbSize.width, height: Self.thumbSize.height)
                } else {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.dsSeparator)
                        .frame(width: Self.thumbSize.width, height: Self.thumbSize.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.dsAccent : Color.dsSeparator,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            }
            .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 1)
            .background(Color.dsCard, in: RoundedRectangle(cornerRadius: 3))
            .contextMenu {
                Button("Rotate 90° CW")  { viewModel.rotatePage(pageRef, by: 90);  thumbnail = nil }
                Button("Rotate 90° CCW") { viewModel.rotatePage(pageRef, by: -90); thumbnail = nil }
                Divider()
                Button("Delete Page", role: .destructive) { viewModel.deletePage(pageRef) }
            }

            // Label
            Text("p. \(pageNumber)")
                .font(.dsCaption())
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.dsAccent : Color.dsTextSecondary)

            Spacer()

            Image(systemName: "line.3.horizontal")
                .font(.caption2)
                .foregroundStyle(Color.dsTextTertiary)
                .opacity(isHovered || isSelected ? 1 : 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background {
            RoundedRectangle(cornerRadius: .dsRadiusSm, style: .continuous)
                .fill(isSelected ? Color.dsAccentSoft : (isHovered ? Color.dsSeparator : Color.clear))
        }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .animation(.easeInOut(duration: 0.10), value: isHovered)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { viewModel.selectPage(pageRef) }
        .onDrag {
            viewModel.beginDraggingPage(pageRef)
            return NSItemProvider(object: pageRef.id.uuidString as NSString)
        }
        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
            viewModel.moveDraggedPage(to: pageRef)
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
