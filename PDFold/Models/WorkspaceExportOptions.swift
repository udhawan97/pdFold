import Foundation

struct WorkspaceExportOptions: Equatable {
    var encryption: PDFEncryptionOptions?

    init(encryption: PDFEncryptionOptions? = nil) {
        self.encryption = encryption
    }
}

struct PDFEncryptionOptions: Codable, Equatable {
    var userPassword: String
    var ownerPassword: String
    var allowsPrinting: Bool
    var allowsCopying: Bool

    init(userPassword: String,
         ownerPassword: String,
         allowsPrinting: Bool = true,
         allowsCopying: Bool = true) {
        self.userPassword = userPassword
        self.ownerPassword = ownerPassword
        self.allowsPrinting = allowsPrinting
        self.allowsCopying = allowsCopying
    }
}

enum PDFEncryptionError: Error, Equatable {
    case emptyUserPassword
    case emptyOwnerPassword
    case matchingOwnerAndUserPasswords
    case digitalSignatureConflict
    case cannotOpenSourcePDF
    case writeFailed
    case unprotectedOutput
    case unreadableEncryptedOutput
    case unlockFailed
    case permissionsMismatch
    case textChanged

    var userMessage: String {
        switch self {
        case .emptyUserPassword:
            return "Password is missing. Enter a password before exporting the protected PDF."
        case .emptyOwnerPassword:
            return "pdFold could not prepare password protection. Try exporting again."
        case .matchingOwnerAndUserPasswords:
            return "pdFold could not apply PDF permissions because the owner and user passwords matched. Try exporting again."
        case .digitalSignatureConflict:
            return "Password protection is unavailable because this PDF has a digital signature. Remove the signature, or export without password protection."
        case .cannotOpenSourcePDF:
            return "pdFold could not open the final PDF for password protection. Export without password protection, or try again."
        case .writeFailed:
            return "pdFold could not write the protected PDF. Check the destination and try again."
        case .unprotectedOutput:
            return "pdFold could not verify password protection. Try exporting again."
        case .unreadableEncryptedOutput:
            return "pdFold could not verify the protected PDF. Try exporting again."
        case .unlockFailed:
            return "pdFold could not unlock the protected PDF during verification. Try exporting again."
        case .permissionsMismatch:
            return "pdFold could not verify the protected PDF permissions. Try exporting again."
        case .textChanged:
            return "pdFold could not verify the protected PDF text. Try exporting again."
        }
    }
}
