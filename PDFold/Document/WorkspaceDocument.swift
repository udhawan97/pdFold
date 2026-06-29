import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let pdfoldproj = UTType(exportedAs: "com.ud.PDFold.pdfoldproj")
}

struct WorkspacePackage {
    var workspace: Workspace
    /// Raw PDF bytes keyed by MemberDocument.id; annotations are baked in.
    var memberPDFData: [UUID: Data]
}

final class WorkspaceDocument: ReferenceFileDocument {
    typealias Snapshot = WorkspacePackage

    static var readableContentTypes: [UTType] { [.pdfoldproj] }
    static var writableContentTypes: [UTType] { [.pdfoldproj] }

    var workspace: Workspace
    var memberPDFData: [UUID: Data] = [:]

    /// ViewModel sets this so snapshot() can capture live annotation state.
    var currentPDFDataProvider: (() -> [UUID: Data])?

    // MARK: - New document

    init() {
        workspace = Workspace()
    }

    // MARK: - Open existing

    required init(configuration: ReadConfiguration) throws {
        guard let wrappers = configuration.file.fileWrappers else {
            workspace = Workspace()
            return
        }
        if let wsWrapper = wrappers["workspace.json"],
           let data = wsWrapper.regularFileContents {
            workspace = (try? JSONDecoder().decode(Workspace.self, from: data)) ?? Workspace()
        } else {
            workspace = Workspace()
        }
        if let pdfsDir = wrappers["pdfs"],
           let pdfWrappers = pdfsDir.fileWrappers {
            for (filename, wrapper) in pdfWrappers {
                guard let data = wrapper.regularFileContents else { continue }
                let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
                if let uuid = UUID(uuidString: stem) {
                    memberPDFData[uuid] = data
                }
            }
        }
    }

    // MARK: - Snapshot (called on main thread before write)

    func snapshot(contentType: UTType) throws -> WorkspacePackage {
        let pdfData = currentPDFDataProvider?() ?? memberPDFData
        return WorkspacePackage(workspace: workspace, memberPDFData: pdfData)
    }

    // MARK: - Write

    func fileWrapper(snapshot: WorkspacePackage, configuration: WriteConfiguration) throws -> FileWrapper {
        let wsData = try JSONEncoder().encode(snapshot.workspace)
        let wsWrapper = FileWrapper(regularFileWithContents: wsData)
        wsWrapper.preferredFilename = "workspace.json"

        let pdfsWrapper = FileWrapper(directoryWithFileWrappers: [:])
        pdfsWrapper.preferredFilename = "pdfs"
        for (id, data) in snapshot.memberPDFData {
            let w = FileWrapper(regularFileWithContents: data)
            w.preferredFilename = "\(id.uuidString).pdf"
            pdfsWrapper.addFileWrapper(w)
        }

        return FileWrapper(directoryWithFileWrappers: [
            "workspace.json": wsWrapper,
            "pdfs": pdfsWrapper
        ])
    }
}
