import Foundation
import Security

/// Pins the `casero.rem.cu` certificate. The portal serves a certificate that
/// fails standard chain validation; rather than trusting any CA we compare the
/// presented leaf certificate byte-for-byte against a bundled copy.
///
/// Bundle the DER certificate as `casero_rem_cu.cer` in the app resources. If it
/// is absent the pinner rejects every connection (fail closed).
enum CertificatePinner {

    private static let bundledName = "casero_rem_cu"

    private static let pinnedData: Data? = {
        guard let url = Bundle.main.url(forResource: bundledName, withExtension: "cer") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }()

    /// Evaluates a server-trust challenge against the pinned certificate.
    static func evaluate(_ challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }

        guard let pinned = pinnedData else {
            // No bundled certificate — refuse rather than trust blindly.
            return (.cancelAuthenticationChallenge, nil)
        }

        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let leaf = chain.first else {
            return (.cancelAuthenticationChallenge, nil)
        }

        let presented = SecCertificateCopyData(leaf) as Data
        if presented == pinned {
            return (.useCredential, URLCredential(trust: serverTrust))
        }
        return (.cancelAuthenticationChallenge, nil)
    }
}
