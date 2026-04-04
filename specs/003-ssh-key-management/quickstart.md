# Quickstart: SSH Key Management

**Feature**: 003-ssh-key-management
**Date**: 2026-01-11

## Prerequisites

- Flutter SDK 3.24+
- Android Studio / VS Code with Flutter extension
- Android device or emulator (API 23+)

## Setup

### 1. add dependencies

```bash
flutter pub add file_picker cryptography pointycastle
```

 `pubspec.yaml` add:

```yaml
dependencies:
 file_picker: ^8.0.3
 cryptography: ^2.7.0
 pointycastle: ^3.9.1
```

### 2. Android permissions (not needed if already configured)

`android/app/src/main/AndroidManifest.xml`:

```xml
<!-- for file picker (Android 10 or below) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### 3. dependencies

```bash
flutter pub get
```

## Quick Verification

### keygeneratetest

```dart
import 'package:cryptography/cryptography.dart';

void main() async {
 // Ed25519keygeneratetest
 final ed25519 = Ed25519();
 final keyPair = await ed25519.newKeyPair();

 final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
 final publicKey = await keyPair.extractPublicKey();

 print('Private key length: ${privateKeyBytes.length}'); // 32
 print('Public key length: ${publicKey.bytes.length}'); // 32
}
```

### file picker test

```dart
import 'package:file_picker/file_picker.dart';

void pickFile() async {
 FilePickerResult? result = await FilePicker.platform.pickFiles();

 if (result != null) {
 print('Selected: ${result.files.single.name}');
 } else {
 print('Cancelled');
 }
}
```

## Development Flow

### 1. SshKeyService implementation

```bash
# newfilecreate
touch lib/services/keychain/ssh_key_service.dart
```

### 2. screenTODO

```bash
# targetfile
lib/screens/keys/keys_screen.dart # navigationadd
lib/screens/keys/key_generate_screen.dart # keygenerate
lib/screens/keys/key_import_screen.dart # file pickerimport
```

### 3. testrun

```bash
flutter test test/services/keychain/ssh_key_service_test.dart
flutter test test/screens/keys/
```

### 4. behaviorconfirmation

```bash
flutter run -d android
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/services/keychain/ssh_key_service.dart` | keygenerate（new） |
| `lib/services/keychain/secure_storage.dart` | secure storage（existing） |
| `lib/providers/key_provider.dart` | management（existing） |
| `lib/screens/keys/keys_screen.dart` | key list screen（） |
| `lib/screens/keys/key_generate_screen.dart` | key generation screen（） |
| `lib/screens/keys/key_import_screen.dart` | importscreen（） |

## Troubleshooting

### file_picker

Android 11scope:

```xml
<!-- AndroidManifest.xml -->
<application
 android:requestLegacyExternalStorage="true"
 ...>
```

### cryptographyerror

```bash
flutter clean
flutter pub get
```

### RSAkeygenerate

RSA-4096、UI`compute()`use:

```dart
final keyPair = await compute(_generateRsaKeyPair, bits);
```
