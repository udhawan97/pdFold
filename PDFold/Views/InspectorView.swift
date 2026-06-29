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
            // Header
            HStack {
                Text("Inspector")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
            }
            .padding(.horizontal, .dsLG)
            .padding(.top, .dsMD)
            .padding(.bottom, .dsSM)

            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, .dsMD)
            .padding(.bottom, .dsMD)

            Rectangle()
                .fill(Color.dsSeparator)
                .frame(height: 0.5)

            ScrollView {
                switch selectedTab {
                case .info:     InspectorInfoView(viewModel: viewModel)
                case .comments: InspectorCommentsView(viewModel: viewModel)
                }
            }
        }
        .background(Color.dsSurface)
    }
}

// MARK: - Info tab

private struct InspectorInfoView: View {
    var viewModel: WorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: .dsLG) {
            InspectorRow(label: "Documents",   value: "\(viewModel.document.workspace.documents.count)")
            InspectorRow(label: "Total pages", value: "\(viewModel.document.workspace.pageOrder.count)")
            InspectorRow(label: "Signatures",  value: "\(viewModel.document.workspace.signatures.count)")
            InspectorRow(label: "Created",     value: viewModel.document.workspace.createdAt.formatted(
                date: .abbreviated, time: .omitted))
        }
        .padding(.dsLG)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InspectorRow: View {
    var label: String
    var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.dsTextTertiary)
                .tracking(0.5)
            Text(value)
                .font(.dsBody())
                .foregroundStyle(Color.dsTextPrimary)
        }
    }
}

// MARK: - Comments tab

private struct InspectorCommentsView: View {
    var viewModel: WorkspaceViewModel

    private var allAnnotations: [(page: PDFPage, annotation: PDFAnnotation, memberName: String)] {
        var result: [(PDFPage, PDFAnnotation, String)] = []
        for (member, pdf) in viewModel.loadedPDFs {
            for i in 0..<pdf.pageCount {
                guard let page = pdf.page(at: i) else { continue }
                for ann in page.annotations { result.append((page, ann, member.displayName)) }
            }
        }
        return result
    }

    var body: some View {
        if allAnnotations.isEmpty {
            VStack(spacing: .dsSM) {
                Image(systemName: "highlighter")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Color.dsTextTertiary)
                Text("No annotations yet.")
                    .font(.dsBody())
                    .foregroundStyle(Color.dsTextSecondary)
                Text("Use the toolbar to highlight,\nadd notes, or draw.")
                    .font(.dsCaption())
                    .foregroundStyle(Color.dsTextTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.dsXXL)
            .frame(maxWidth: .infinity)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(allAnnotations.indices, id: \.self) { i in
                    InspectorAnnotationRow(ann: allAnnotations[i].annotation,
                                          memberName: allAnnotations[i].memberName)
                    Rectangle().fill(Color.dsSeparator).frame(height: 0.5)
                }
            }
            .padding(.vertical, .dsXS)
        }
    }
}

private struct InspectorAnnotationRow: View {
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
        case "Underline": return "underline"
        case "StrikeOut": return "strikethrough"
        default:          return "pencil.and.outline"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: .dsSM) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.dsTextTertiary)
                .frame(width: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(typeLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dsTextPrimary)
                if let contents = ann.contents, !contents.isEmpty {
                    Text(contents)
                        .font(.dsCaption())
                        .foregroundStyle(Color.dsTextSecondary)
                        .lineLimit(2)
                }
                Text(memberName)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dsTextTertiary)
            }
        }
        .padding(.horizontal, .dsMD)
        .padding(.vertical, .dsSM)
    }
}
