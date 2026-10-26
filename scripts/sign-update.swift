// Signs release DMGs so the in-app updater installs only builds you made. The Ed25519 private key lives
// in your login Keychain; the app carries the public key (Updater.publicKey) and checks every download.
//
//   swift scripts/sign-update.swift keygen             once: makes the key, prints the public key for Updater.swift
//   swift scripts/sign-update.swift sign <file.dmg>    writes <file.dmg>.sig (make-dmg.sh runs this)
//
// Back the key up (Keychain Access → "njrNotch update signing" → export, or copy the base64 somewhere safe).
// Lose it and released apps can't verify new updates; people would have to reinstall by hand once.
import CryptoKit
import Foundation

let service = "njrNotch update signing"

func security(_ arguments: [String]) -> (status: Int32, output: String) {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try! process.run()
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()
    return (process.terminationStatus, output.trimmingCharacters(in: .whitespacesAndNewlines))
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = CommandLine.arguments.dropFirst()
switch (arguments.first, arguments.count) {
case ("keygen", 1):
    guard security(["find-generic-password", "-s", service]).status != 0 else {
        fail("A key already exists in the Keychain (\(service)); not replacing it.")
    }
    let key = Curve25519.Signing.PrivateKey()
    let added = security(["add-generic-password", "-s", service, "-a", "njrNotch",
                          "-w", key.rawRepresentation.base64EncodedString()])
    guard added.status == 0 else { fail("Couldn't save the key to the Keychain.") }
    print("Public key (paste into Updater.publicKey):")
    print(key.publicKey.rawRepresentation.base64EncodedString())
case ("sign", 2):
    let path = arguments.last!
    let stored = security(["find-generic-password", "-s", service, "-w"])
    guard stored.status == 0, let raw = Data(base64Encoded: stored.output),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
        fail("No signing key in the Keychain. Run: swift scripts/sign-update.swift keygen")
    }
    guard let file = FileManager.default.contents(atPath: path) else { fail("Can't read \(path)") }
    let signature = try! key.signature(for: file)
    guard key.publicKey.isValidSignature(signature, for: file) else { fail("Signature check failed") }
    try! Data(signature.base64EncodedString().utf8).write(to: URL(fileURLWithPath: path + ".sig"))
    print("Signed \(path) -> \(path).sig")
default:
    fail("usage: sign-update.swift keygen | sign <file.dmg>")
}
