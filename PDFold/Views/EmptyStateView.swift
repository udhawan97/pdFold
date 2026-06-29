import SwiftUI
import UniformTypeIdentifiers

struct EmptyStateView: View {
    var viewModel: WorkspaceViewModel
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                        .frame(width: 96, height: 96)
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(Color.accentColor)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(spacing: 8) {
                    Text("Drag files here")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Drop PDF, Word, HTML, text, or image files to start a workspace.\nCombine, annotate, and sign them as one document.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                HStack(spacing: 12) {
                    Button {
                        openFiles()
                    } label: {
                        Label("Open Files…", systemImage: "folder.badge.plus")
                            .frame(minWidth: 130)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    Button {
                        // new blank workspace - already have one
                    } label: {
                        Label("New Workspace", systemImage: "plus")
                            .frame(minWidth: 130)
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                }
            }
            .padding(56)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    Color.accentColor,
                    lineWidth: isDropTargeted ? 2.5 : 0
                )
                .padding(12)
                .animation(.easeInOut(duration: 0.12), value: isDropTargeted)
        )
        .onDrop(of: WorkspaceDocument.importableContentTypes + [.fileURL], isTargeted: $isDropTargeted) { providers in
            resolveImportURLs(from: providers) { urls in
                viewModel.importFiles(urls: urls)
            }
            return true
        }
    }

    private func openFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = WorkspaceDocument.importableContentTypes
        if panel.runModal() == .OK {
            viewModel.importFiles(urls: panel.urls)
        }
    }
}
