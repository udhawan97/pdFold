import SwiftUI
import PDFKit

struct InspectorView: View {
    var viewModel: WorkspaceViewModel
    @State private var selectedTab: Tab = .info

    enum Tab: String, CaseIterable {
        case info = "Info"
        case comments = "Comments"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(12)

            Divider()

            ScrollView {
                switch selectedTab {
                case .info:    WorkspaceInfoView(viewModel: viewModel)
                case .comments: CommentsView(viewModel: viewModel)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Info tab

private struct WorkspaceInfoView: View {
    var viewModel: WorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoRow(label: "Documents", value: "\(viewModel.document.workspace.documents.count)")
            InfoRow(label: "Total pages", value: "\(viewModel.document.workspace.pageOrder.count)")
            InfoRow(label: "Signatures", value: "\(viewModel.document.workspace.signatures.count)")
            InfoRow(label: "Created", value: viewModel.document.workspace.createdAt.formatted(
                date: .abbreviated, time: .omitted))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InfoRow: View {
    var label: String
    var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
            Text(value).font(.callout)
        }
    }
}

// MARK: - Comments tab

private struct CommentsView: View {
    var viewModel: WorkspaceViewModel

    /// Flattened list of all annotations across all member PDFs
    private var allAnnotations: [(page: PDFPage, annotation: PDFAnnotation, memberName: String)] {
        var result: [(PDFPage, PDFAnnotation, String)] = []
        for (member, pdf) in viewModel.loadedPDFs {
            for i in 0..<pdf.pageCount {
                guard let page = pdf.page(at: i) else { continue }
                for ann in page.annotations {
                    result.append((page, ann, member.displayName))
                }
            }
        }
        return result
    }

    var body: some View {
        if allAnnotations.isEmpty {
            Text("No annotations yet.\nUse the toolbar to highlight,\nadd notes, or draw.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(allAnnotations.indices, id: \.self) { i in
                    AnnotationRow(ann: allAnnotations[i].annotation,
                                  memberName: allAnnotations[i].memberName)
                    Divider()
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct AnnotationRow: View {
    var ann: PDFAnnotation
    var memberName: String

    private var typeLabel: String {
        switch ann.type {
        case "Highlight": return "Highlight"
        case "Text":      return "Note"
        case "Ink":       return "Ink"
        case "FreeText":  return "Text Box"
        case "Underline": return "Underline"
        case "StrikeOut": return "Strikeout"
        default:          return ann.type ?? "Annotation"
        }
    }

    private var icon: String {
        switch ann.type {
        case "Highlight": return "highlighter"
        case "Text":      return "note.text"
        case "Ink":       return "pencil.tip"
        default:          return "pencil.and.outline"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(typeLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                if let contents = ann.contents, !contents.isEmpty {
                    Text(contents)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(memberName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
