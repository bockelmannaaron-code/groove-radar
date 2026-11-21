// The Ed25519 key that signs Groove Radar updates. Used by build-app.sh:
//
//   swift macos/update-key.swift public <key file>        prints the public key (base64), creating the key file if missing
//   swift macos/update-key.swift sign <key file> <file>   prints the signature of <file> (base64)
//
// The key file holds the PRIVATE key. Keep it outside the repo and back it up: without it,
// installed apps can't be updated automatically any more (people would need to download again).
import CryptoKit
import Foundation

let args = CommandLine.arguments
func fail(_ s: String) -> Never { FileHandle.standardError.write((s + "\n").data(using: .utf8)!); exit(1) }
guard args.count >= 3 else { fail("usage: update-key.swift public <key file> | sign <key file> <file>") }
let keyURL = URL(fileURLWithPath: (args[2] as NSString).expandingTildeInPath)

func loadKey(create: Bool) -> Curve25519.Signing.PrivateKey {
    if let d = try? Data(contentsOf: keyURL), let raw = Data(base64Encoded: String(decoding: d, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)),
       let k = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) { return k }
    guard create else { fail("No update signing key at \(keyURL.path).") }
    let k = Curve25519.Signing.PrivateKey()
    try? FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: keyURL.path, contents: Data(k.rawRepresentation.base64EncodedString().utf8),
                                   attributes: [.posixPermissions: 0o600])
    FileHandle.standardError.write("Created a new update signing key at \(keyURL.path). Back it up somewhere safe.\n".data(using: .utf8)!)
    return k
}

switch args[1] {
case "public":
    print(loadKey(create: true).publicKey.rawRepresentation.base64EncodedString())
case "sign":
    guard args.count >= 4, let data = try? Data(contentsOf: URL(fileURLWithPath: args[3])) else { fail("Can't read the file to sign.") }
    let sig = try! loadKey(create: false).signature(for: data)
    print(sig.base64EncodedString())
default:
    fail("unknown command \(args[1])")
}
