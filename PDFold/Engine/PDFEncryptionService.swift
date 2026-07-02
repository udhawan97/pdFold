import CoreGraphics
import Foundation
import PDFKit

enum PDFEncryptionService {
    static func encryptedData(from pdfData: Data, options: PDFEncryptionOptions) throws -> Data {
        try validate(options)
        guard let sourcePDF = PDFDocument(data: pdfData) else {
            throw PDFEncryptionError.cannotOpenSourcePDF
        }
        let expectedText = sourcePDF.string ?? ""
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdFold-encrypted-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let writeOptions: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: options.userPassword,
            .ownerPasswordOption: options.ownerPassword,
            PDFDocumentWriteOption(rawValue: kCGPDFContextAllowsPrinting as String): options.allowsPrinting,
            PDFDocumentWriteOption(rawValue: kCGPDFContextAllowsCopying as String): options.allowsCopying,
            PDFDocumentWriteOption(rawValue: kCGPDFContextEncryptionKeyLength as String): 128
        ]

        guard sourcePDF.write(to: tempURL, withOptions: writeOptions) else {
            throw PDFEncryptionError.writeFailed
        }
        let encrypted = try Data(contentsOf: tempURL)
        try validateEncryptedData(encrypted, options: options, expectedText: expectedText)
        return encrypted
    }

    static func validate(_ options: PDFEncryptionOptions) throws {
        guard !options.userPassword.isEmpty else {
            throw PDFEncryptionError.emptyUserPassword
        }
        guard !options.ownerPassword.isEmpty else {
            throw PDFEncryptionError.emptyOwnerPassword
        }
        guard options.ownerPassword != options.userPassword else {
            throw PDFEncryptionError.matchingOwnerAndUserPasswords
        }
    }

    static func validateEncryptedData(_ data: Data,
                                      options: PDFEncryptionOptions,
                                      expectedText: String? = nil) throws {
        guard let encryptedPDF = PDFDocument(data: data) else {
            throw PDFEncryptionError.unreadableEncryptedOutput
        }
        guard encryptedPDF.isLocked else {
            throw PDFEncryptionError.unprotectedOutput
        }
        guard encryptedPDF.unlock(withPassword: options.userPassword) else {
            throw PDFEncryptionError.unlockFailed
        }
        guard encryptedPDF.allowsPrinting == options.allowsPrinting,
              encryptedPDF.allowsCopying == options.allowsCopying else {
            throw PDFEncryptionError.permissionsMismatch
        }
        if let expectedText, (encryptedPDF.string ?? "") != expectedText {
            throw PDFEncryptionError.textChanged
        }
    }
}
