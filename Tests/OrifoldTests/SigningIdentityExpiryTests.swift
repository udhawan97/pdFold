import Crypto
import Foundation
import X509
import XCTest
@testable import Orifold

/// Regression coverage for a review finding: nothing in the signing path ever checked
/// whether the selected identity's certificate had already expired before signing.
final class SigningIdentityExpiryTests: XCTestCase {
    private struct FakeSigningIdentity: SigningIdentity {
        var certificate: Certificate
        var chain: [Certificate] = []
        var signatureAlgorithm: SignatureAlgorithm = .ecdsaP256SHA256

        func sign(_ data: Data) throws -> Data { Data() }
    }

    private func makeCertificate(notBefore: Date, notAfter: Date) throws -> Certificate {
        let privateKey = Certificate.PrivateKey(P256.Signing.PrivateKey())
        let subject = try DistinguishedName {
            CommonName("Expiry Test")
        }
        return try Certificate(
            version: .v3,
            serialNumber: .init(),
            publicKey: privateKey.publicKey,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: subject,
            subject: subject,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: Certificate.Extensions {
                Critical(BasicConstraints.notCertificateAuthority)
                Critical(KeyUsage(digitalSignature: true, nonRepudiation: true))
            },
            issuerPrivateKey: privateKey
        )
    }

    func testAlreadyExpiredCertificateIsFlaggedExpired() throws {
        let certificate = try makeCertificate(
            notBefore: Date().addingTimeInterval(-3 * 24 * 60 * 60),
            notAfter: Date().addingTimeInterval(-1 * 24 * 60 * 60)
        )
        let identity = FakeSigningIdentity(certificate: certificate)

        XCTAssertTrue(identity.isCertificateExpired,
                      "a certificate whose notValidAfter is in the past must be reported expired")
    }

    func testStillValidCertificateIsNotFlaggedExpired() throws {
        let certificate = try makeCertificate(
            notBefore: Date().addingTimeInterval(-300),
            notAfter: Date().addingTimeInterval(365 * 24 * 60 * 60)
        )
        let identity = FakeSigningIdentity(certificate: certificate)

        XCTAssertFalse(identity.isCertificateExpired,
                       "a certificate with a future notValidAfter must not be reported expired")
    }
}
