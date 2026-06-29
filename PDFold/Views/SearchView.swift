import SwiftUI
import PDFKit

struct SearchView: View {
    @Bindable var viewModel: WorkspaceViewModel
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search workspace…", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onSubmit { viewModel.search(query: viewModel.searchQuery) }
                    .onChange(of: viewModel.searchQuery) { _, q in
                        if q.isEmpty { viewModel.searchResults = [] }
                        else { viewModel.search(query: q) }
                    }
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(10)

            Divider()

            if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                Text("No results")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding()
            } else {
                List(viewModel.searchResults.indices, id: \.self) { i in
                    let result = viewModel.searchResults[i]
                    SearchResultRow(result: result)
                        .onTapGesture {
                            // Navigate via notification — PDFView observes this
                            NotificationCenter.default.post(
                                name: .pdfoldJumpToSelection,
                                object: result
                            )
                        }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 280)
        .onAppear { fieldFocused = true }
    }
}

struct SearchResultRow: View {
    var result: PDFSelection

    private var pageLabel: String {
        result.pages.first.flatMap { $0.label } ?? "?"
    }
    private var snippet: String {
        result.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snippet)
                .font(.callout)
                .lineLimit(2)
            Text("Page \(pageLabel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

extension Notification.Name {
    static let pdfoldJumpToSelection = Notification.Name("pdfoldJumpToSelection")
}
