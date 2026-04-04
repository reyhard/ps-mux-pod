# Research: SSH Key Management

**Feature**: 003-ssh-key-management
**Date**: 2026-01-11

## Research Tasks

### 1. SSHkeygenerate

**Question**: Dart/FlutterEd25519/RSAkeygenerate？

**Decision**: `cryptography`（Ed25519） `pointycastle`（RSA）use

**Rationale**:
- `dartssh2`key/、generatefeature
- `cryptography`Ed25519、platformsupport
- `pointycastle`RSAkeygenerate、Pure Dartdependencies

**Alternatives Considered**:

| | | |
|-----------|------|----------|
| `ed25519_dart` | △ | Ed25519、 |
| `basic_utils` | △ | RSA、API |
| `cryptography` | ✅ | Ed25519support、 |
| `pointycastle` | ✅ | RSAsupport、use |

**Implementation Notes**:
```dart
// Ed25519 using cryptography package
import 'package:cryptography/cryptography.dart';

final ed25519 = Ed25519();
final keyPair = await ed25519.newKeyPair();
final privateKey = await keyPair.extractPrivateKeyBytes();
final publicKey = await keyPair.extractPublicKey();

// RSA using pointycastle
import 'package:pointycastle/export.dart';

final keyGen = RSAKeyGenerator()
 ..init(ParametersWithRandom(
 RSAKeyGeneratorParameters(BigInt.parse('65537'), 4096, 64),
 secureRandom,
 ));
final pair = keyGen.generateKeyPair();
```

---

### 2. Choosing a file picker

**Question**: AndroidSSHprivate keyfileselect？

**Decision**: `file_picker`use

**Rationale**:
- pub.dev（5000+ likes）
- Android/iOS/Web/Desktopsupport
- API、support
- 

**Alternatives Considered**:

| | | |
|-----------|------|----------|
| `native_file_picker` | △ | 、 |
| `filesystem_picker` | △ | select |
| `file_picker` | ✅ | 、API |

**Implementation Notes**:
```dart
import 'package:file_picker/file_picker.dart';

// private keyfileselect
FilePickerResult? result = await FilePicker.platform.pickFiles(
 type: FileType.any, // SSHkey
 allowMultiple: false,
);

if (result != null && result.files.single.path != null) {
 final file = File(result.files.single.path!);
 final content = await file.readAsString();
 // PEMformatverification
}
```

---

### 3. private keyPEMformat

**Question**: importprivate key？

**Decision**: `dartssh2``SSHKeyPair.fromPem()`

**Rationale**:
- existingdependenciessupportpossible
- OpenSSHformatPEMformat
- passphrasekey

**Implementation Notes**:
```dart
import 'package:dartssh2/dartssh2.dart';

// 
final isEncrypted = SSHKeyPair.isEncryptedPem(pemContent);

// 
final keyPair = SSHKeyPair.fromPem(
 pemContent,
 passphrase: isEncrypted ? userPassphrase : null,
);

// keyretrieve
final keyType = keyPair.type; // 'ssh-ed25519', 'ssh-rsa', etc.
```

---

### 4. PEMformatkey

**Question**: generatekeyPEMformatsave？

**Decision**: OpenSSHformatPEMmanual

**Rationale**:
- `cryptography``pointycastle`PEM
- OpenSSHformat、high

**Implementation Notes**:
```dart
// Ed25519
String toPem(Uint8List privateKey, Uint8List publicKey) {
 // OpenSSHformatPEM
 // - "-----BEGIN OPENSSH PRIVATE KEY-----"
 // - Base64
 // - "-----END OPENSSH PRIVATE KEY-----"
}

// public keyauthorized_keysformat
String toAuthorizedKeys(String type, Uint8List publicKey, String comment) {
 return '$type ${base64Encode(publicKey)} $comment';
}
```

---

### 5. fingerprint

**Question**: keyfingerprint？

**Decision**: SHA-256use（OpenSSH）

**Rationale**:
- OpenSSH 6.8later
- MD5securehigh

**Implementation Notes**:
```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

String calculateFingerprint(Uint8List publicKeyBlob) {
 final hash = sha256.convert(publicKeyBlob);
 return 'SHA256:${base64Encode(hash.bytes).replaceAll('=', '')}';
}
```

---

## Dependencies to Add

```yaml
# pubspec.yaml add
dependencies:
 file_picker: ^8.0.3
 cryptography: ^2.7.0
 pointycastle: ^3.9.1
```

## Security Considerations

1. **Private key handling**:
 - minimum
 - key
 - use

2. **Passphrase handling**:
 - flutter_secure_storagesave
 - UIdisplay

3. **file**:
 - file pickerviafile
