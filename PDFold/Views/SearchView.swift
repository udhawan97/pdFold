import SwiftUI
import PDFKit

struct SearchView: View {
    @Bindable var viewModel: WorkspaceViewModel
    @FocusState private var fieldFocused: Bool

    private var resultLabel: String {
        let n = viewModel.searchResults.count
        if n == 0 { return "" }
        let i = viewModel.searchResultIndex
        if i >= 0 { return "\(i + 1) of \(n)" }
        return "\(n) result\(n == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: .dsSM) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.dsTextTertiary)
                    .font(.system(size: 13))

                TextField("Search workspace…", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.dsBody())
                    .focused($fieldFocused)
                    .onSubmit { viewModel.searchNext() }
                    .onChange(of: viewModel.searchQuery) { _, q in
                        if q.isEmpty { viewModel.searchResults = []; viewModel.searchResultIndex = -1 }
                        else { viewModel.search(query: q) }
                    }

                if !viewModel.searchQuery.isEmpty {
                    Text(resultLabel)
                        .font(.dsCaption())
                        .foregroundStyle(Color.dsTextTertiary)
                        .animation(.none, value: resultLabel)

                    Divider().frame(height: 14)

                    Button { viewModel.searchPrevious() } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.dsTextSecondary)
                    .disabled(viewModel.searchResults.isEmpty)

                    Button { viewModel.searchNext() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.dsTextSecondary)
                    .disabled(viewModel.searchResults.isEmpty)

                    Button {
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                        viewModel.searchResultIndex = -1
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.dsTextTertiary)
                }
            }
            .padding(.horizontal, .dsMD)
            .padding(.vertical, .dsMD)

            Rectangle().fill(Color.dsSeparator).frame(height: 0.5)

            if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                VStack(spacing: .dsSM) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.dsTextTertiary)
                    Text("No results")
                        .font(.dsBody())
                        .foregroundStyle(Color.dsTextSecondary)
                }
                .padding(.dsXL)
                .frame(maxWidth: .infinity)
            } else if !viewModel.searchResults.isEmpty {
                List(viewModel.searchResults.indices, id: \.self) { i in
                    SearchResultRow(
                        result: viewModel.searchResults[i],
                        isActive: i == viewModel.searchResultIndex
                    )
                    .listRowBackground(
                        i == viewModel.searchResultIndex ? Color.dsAccentSoft : Color.clear
                    )
                    .onTapGesture {
                        viewModel.searchResultIndex = i
                        NotificationCenter.default.post(
                            name: .pdfoldJumpToSelection,
                            object: viewModel.searchResults[i]
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 300)
        .background(Color.dsSurface)
        .onAppear { fieldFocused = true }
    }
}

struct SearchResultRow: View {
    var result: PDFSelection
    var isActive: Bool

    private var pageLabel: String {
        result.pages.first.flatMap { $0.label } ?? "?"
    }
    private var snippet: String {
        result.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snippet)
                .font(.dsBody())
                .foregroundStyle(isActive ? Color.dsAccent : Color.dsTextPrimary)
                .lineLimit(2)
            Text("Page \(pageLabel)")
                .font(.dsCaption())
                .foregroundStyle(Color.dsTextTertiary)
        }
        .padding(.vertical, .dsXS)
    }
}

extension Notification.Name {
    static let pdfoldJumpToSelection = Notification.Name("pdfoldJumpToSelection")
    static let pdfoldJumpToPageIndex = Notification.Name("pdfoldJumpToPageIndex")
    static let pdfoldPrint           = Notification.Name("pdfoldPrint")
    static let pdfoldZoomIn          = Notification.Name("pdfoldZoomIn")
    static let pdfoldZoomOut         = Notification.Name("pdfoldZoomOut")
    static let pdfoldZoomFit         = Notification.Name("pdfoldZoomFit")
    static let pdfoldSaveAsPDF       = Notification.Name("pdfoldSaveAsPDF")
}
