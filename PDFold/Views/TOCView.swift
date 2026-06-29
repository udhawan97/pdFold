import SwiftUI
import PDFKit

struct TOCView: View {
    var viewModel: WorkspaceViewModel
    /// Called when the user taps an entry — jump the PDFView to that page.
    var onJump: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Table of Contents")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 10)

            Divider()

            if viewModel.tableOfContents.isEmpty {
                Text("No documents loaded.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding()
            } else {
                List(viewModel.tableOfContents) { entry in
                    Button {
                        onJump?(entry.startPageIndex)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("p. \(entry.startPageIndex + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 260)
    }
}
