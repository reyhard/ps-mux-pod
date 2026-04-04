# Research: SSH Key Management

**Feature**: 002-ssh-key-management
**Date**: 2026-01-10

## 1. ED25519 Key Generation in React Native

### Decision
Use the native capabilities of `react-native-ssh-sftp` to generate ED25519 keys.

### Rationale
- `react-native-ssh-sftp` is already a project dependency
- Native key generation avoids extra cryptography dependencies in the JavaScript layer
- It integrates easily with Android Keystore

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| `tweetnacl-js` | Pure JS is slow, not secure, and cannot integrate with Secure Enclave |
| `expo-crypto` | ED25519keygenerate |
| `react-native-crypto` | 、Expo SDK 52support |

### Implementation Notes
- Use the `SSHClient.generateKey()` method from `react-native-ssh-sftp`
- Generated keys are output in OpenSSH format
- Public keys are provided in `authorized_keys` format

## 2. Secure Storage for Private Keys

### Decision
Use `expo-secure-store` and store keys in a hardware-backed keystore through Android Keystore.

### Rationale
- `expo-secure-store` is already used in `auth.ts` for password storage
- Android Keystore provides hardware security similar to Secure Enclave
- It is easy to integrate with biometrics via `expo-local-authentication`

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| AsyncStorage + encryption | Software-only encryption with no hardware backing |
| react-native-keychain | Overlaps with `expo-secure-store` and adds no value |

### Implementation Notes
- Store private keys under the `muxpod-ssh-key-{keyId}` key
- Store metadata such as name, type, and fingerprint separately in AsyncStorage
- Support a setting that requires biometric authentication when a key is accessed

## 3. Key Import and Passphrase Handling

### Decision
Parse PEM/OpenSSH private keys and decrypt passphrase-protected keys before storing them in secure storage.

### Rationale
- Users are likely to already have existing keys
- Decrypting once and storing in secure storage improves the connection experience
- Users do not need to enter the passphrase every time

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| Store with passphrase | Requires passphrase entry on every connection and hurts UX |
| Store the passphrase separately | Increases security risk and complexity |

### Implementation Notes
- Parse keys with `sshpk` or a similar library
- Supported formats: PEM (RSA, ECDSA, ED25519) and OpenSSH
- Show a passphrase prompt during import
- After decryption, store the plain private key in secure storage

## 4. Known Host Management

### Decision
Store known hosts as JSON in AsyncStorage and verify fingerprints during connection.

### Rationale
- Known hosts are security-related but do not need encrypted storage because they are public information
- AsyncStorage is fast enough
- This preserves compatibility with the `known_hosts` file format

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| SecureStore | Has storage limits and is overkill for public data |
| SQLite | Adds a dependency and is excessive at this scale |

### Implementation Notes
- Host identifier: `{host}:{port}`
- Storage format: `{ identifier, keyType, fingerprint, addedAt, lastVerifiedAt }`
- When verification fails, show a warning dialog and present choices to the user

## 5. File Import UI

### Decision
Use `expo-document-picker` to select private key files from local or cloud storage.

### Rationale
- It is an official library included with Expo SDK
- It supports cloud storage providers such as iCloud, Google Drive, and Dropbox
- It provides a platform-native file picker UI

### Implementation Notes
- MIME type: `*/*` or `text/plain`
- After selection, read the file content and validate the key format
- Show an error message if the format is invalid

## 6. Biometrics

### Decision
Use `expo-local-authentication` to require biometric authentication when a key is used.

### Rationale
- It is an official Expo SDK library
- It supports both fingerprint and face authentication
- It can work with SecureStore access control

### Implementation Notes
- Authentication is required when the key is accessed, such as when a connection starts
- No fallback to password authentication is offered if biometric authentication fails, for security reasons
- Users can enable or disable biometrics in settings

## Technology Stack Summary

| Concern | Technology | Status |
|---------|------------|--------|
| Key generation | react-native-ssh-sftp | Existing dependency |
| Secure storage | expo-secure-store | Existing dependency |
| Metadata storage | AsyncStorage | Existing dependency |
| File picker | expo-document-picker | Needs to be added |
| Biometrics | expo-local-authentication | Needs to be added |
