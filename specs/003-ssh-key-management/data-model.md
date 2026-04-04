# Data Model: SSH Key Management

**Feature**: 003-ssh-key-management
**Date**: 2026-01-11

## Entities

### SshKeyMeta（existing）

SSHkeymetadata。`shared_preferences`save。

```dart
class SshKeyMeta {
 final String id; // UUID
 final String name; // 
 final String type; // 'ed25519' | 'rsa-2048' | 'rsa-3072' | 'rsa-4096'
 final String? publicKey; // public key（authorized_keysformat）
 final String? fingerprint; // SHA256fingerprint
 final bool hasPassphrase; // passphrase
 final DateTime createdAt; // create
 final String? comment; // （）
 final KeySource source; // key（generated | imported）
}
```

**Validation Rules**:
- `id`: 、UUIDformat
- `name`: 、255
- `type`: `['ed25519', 'rsa-2048', 'rsa-3072', 'rsa-4096']`
- `publicKey`: null、settingsSSHpublic keyformat
- `fingerprint`: null、settings`SHA256:`
- `createdAt`: enabledDateTime

**State Transitions**:
```
[generate] → [generate] → [generatecomplete/save]
 ↘ [generate]

[import] → [] → [save]
 ↘ []

[save] → [delete]
```

---

### KeySource（new）

keyEnum。

```dart
enum KeySource {
 generated, // generate
 imported, // file/import
}
```

---

### KeysState（existing）

keylistmanagement。

```dart
class KeysState {
 final List<SshKeyMeta> keys; // key（create）
 final bool isLoading; // 
 final String? error; // error
}
```

---

## Storage Schema

### shared_preferences

```json
{
 "ssh_keys_meta": [
 {
 "id": "uuid-string",
 "name": "My Key",
 "type": "ed25519",
 "publicKey": "ssh-ed25519 AAAA... comment",
 "fingerprint": "SHA256:abc123...",
 "hasPassphrase": false,
 "createdAt": "2026-01-11T12:00:00.000Z",
 "comment": null,
 "source": "generated"
 }
 ]
}
```

### flutter_secure_storage

| Key Pattern | Value | Description |
|-------------|-------|-------------|
| `privatekey_{keyId}` | PEM string | private key（OpenSSHformat） |
| `passphrase_{keyId}` | string | passphrase（save） |

---

## Relationships

```
┌─────────────────┐
│ SshKeyMeta │
│ (metadata) │
│ │
│ id ─────────────┼──┐
│ name │ │
│ type │ │
│ publicKey │ │ References by key
│ fingerprint │ │
│ hasPassphrase ──┼──┼───────────────────┐
│ createdAt │ │ │
│ source │ │ │
└─────────────────┘ │ │
 │ │
 ┌─────────▼─────────┐ ┌──────▼───────┐
 │ SecureStorage │ │ SecureStorage│
 │ privatekey_{id} │ │ passphrase_{id}
 │ (PEM content) │ │ (if encrypted)
 └───────────────────┘ └──────────────┘
```

---

## API Contracts

### SshKeyService

```dart
abstract class SshKeyService {
 /// Ed25519keygenerate
 Future<SshKeyPair> generateEd25519({String? comment});

 /// RSAkeygenerate
 Future<SshKeyPair> generateRsa({
 required int bits, // 2048 | 3072 | 4096
 String? comment,
 });

 /// PEMkey
 Future<SshKeyPair> parseFromPem(
 String pemContent, {
 String? passphrase,
 });

 /// keypassphraseconfirmation
 bool isEncrypted(String pemContent);

 /// public keyfingerprint
 String calculateFingerprint(Uint8List publicKeyBlob);

 /// private keyPEMformat
 String toPem(SshKeyPair keyPair);

 /// public keyauthorized_keysformat
 String toAuthorizedKeys(SshKeyPair keyPair, String comment);
}

/// key
class SshKeyPair {
 final String type; // 'ed25519' | 'rsa-2048' | etc.
 final Uint8List privateKey; // private key
 final Uint8List publicKey; // public key
 final String fingerprint; // SHA256fingerprint
}
```

### KeysNotifier（existing）

```dart
class KeysNotifier extends Notifier<KeysState> {
 Future<void> add(SshKeyMeta key);
 Future<void> remove(String id);
 Future<void> update(SshKeyMeta key);
 SshKeyMeta? getById(String id);
 Future<void> reload();
}
```

### SecureStorageService（existing）

```dart
class SecureStorageService {
 Future<void> savePrivateKey(String keyId, String privateKey);
 Future<String?> getPrivateKey(String keyId);
 Future<void> deletePrivateKey(String keyId);
 Future<void> savePassphrase(String keyId, String passphrase);
 Future<String?> getPassphrase(String keyId);
 Future<void> deletePassphrase(String keyId);
}
```
