import SwiftUI
import PDFKit

struct InspectorView: View {
    var viewModel: WorkspaceViewModel
    @State private var selectedTab: InspectorTab = .info

    enum InspectorTab: String, CaseIterable {
        case info = "Info"
        case annotations = "Annotations"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            Divider()

            ScrollView {
                switch selectedTab {
                case .info:
                    WorkspaceInfoView(viewModel: viewModel)
                case .annotations:
                    Text("Annotations appear here.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .padding()
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct WorkspaceInfoView: View {
    var viewModel: WorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoRow(label: "Documents", value: "\(viewModel.document.workspace.documents.count)")
            InfoRow(label: "Total pages", value: "\(viewModel.document.workspace.pageOrder.count)")
            InfoRow(label: "Created", value: viewModel.document.workspace.createdAt.formatted(date: .abbreviated, time: .omitted))
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
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.callout)
        }
    }
}
