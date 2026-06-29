import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    var document: WorkspaceDocument
    @State private var viewModel: WorkspaceViewModel
    @State private var showInspector = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(document: WorkspaceDocument) {
        self.document = document
        _viewModel = State(initialValue: WorkspaceViewModel(document: document))
    }

    var body: some View {
        Group {
            if viewModel.document.workspace.documents.isEmpty {
                EmptyStateView(viewModel: viewModel)
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(viewModel: viewModel)
                        .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 320)
                } detail: {
                    HStack(spacing: 0) {
                        ReadingCanvas(viewModel: viewModel)
                        if showInspector {
                            Divider()
                            InspectorView(viewModel: viewModel)
                                .frame(width: 240)
                                .transition(.move(edge: .trailing))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showInspector)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showInspector.toggle()
                            } label: {
                                Label("Inspector", systemImage: "sidebar.right")
                            }
                            .help("Toggle Inspector (⌘⇧I)")
                        }
                    }
                }
                .navigationTitle(viewModel.document.workspace.title)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.document.workspace.documents.isEmpty)
        .onDrop(of: [UTType.pdf, .fileURL], isTargeted: nil, perform: handleDrop)
        .alert("Import Error", isPresented: Binding(
            get: { viewModel.importError != nil },
            set: { if !$0 { viewModel.importError = nil } }
        ), presenting: viewModel.importError) { _ in
            Button("OK") { viewModel.importError = nil }
        } message: { err in
            Text(err.message)
        }
        .sheet(isPresented: $viewModel.isShowingPasswordPrompt) {
            if let url = viewModel.pendingPasswordURL,
               let pdf = PDFDocument(url: url) {
                PasswordPromptView(
                    fileName: url.lastPathComponent,
                    pdf: pdf,
                    url: url,
                    viewModel: viewModel
                )
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        resolvePDFURLs(from: providers) { urls in
            viewModel.importPDFs(urls: urls)
        }
        return true
    }
}

/// Resolves `public.file-url` items from drag providers, filters to PDFs only.
func resolvePDFURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
    var urls: [URL] = []
    let group = DispatchGroup()
    for provider in providers {
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            defer { group.leave() }
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "pdf" else { return }
            urls.append(url)
        }
    }
    group.notify(queue: .main) { completion(urls) }
}
