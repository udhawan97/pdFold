import SwiftUI
import PDFKit

struct TOCView: View {
    var viewModel: WorkspaceViewModel
    var onJump: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Contents")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.horizontal, .dsLG)
                .padding(.top, .dsMD)
                .padding(.bottom, .dsSM)

            Rectangle().fill(Color.dsSeparator).frame(height: 0.5)

            if viewModel.tableOfContents.isEmpty {
                Text("No documents in workspace.")
                    .font(.dsBody())
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.dsLG)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List(viewModel.tableOfContents) { entry in
                    Button {
                        onJump?(entry.startPageIndex)
                    } label: {
                        HStack(spacing: .dsSM) {
                            Image(systemName: "doc.richtext.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.dsAccent)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.dsBody())
                                    .foregroundStyle(Color.dsTextPrimary)
                                    .lineLimit(1)
                                Text("Jump to first page")
                                    .font(.dsCaption())
                                    .foregroundStyle(Color.dsTextTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.dsTextTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.dsSurface)
            }
        }
        .frame(width: 260)
        .background(Color.dsSurface)
    }
}
