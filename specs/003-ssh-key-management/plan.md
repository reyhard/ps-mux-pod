# Implementation Plan: SSH Key Management

**Branch**: `003-ssh-key-management` | **Date**: 2026-01-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-ssh-key-management/spec.md`

## Summary

SSH Key Managementimplementation。Ed25519RSAkeygenerate、file pickeruseprivate keyimport、keylistdisplaydeletefeature。existing`SecureStorageService``KeysNotifier`、screenTODO。

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.24+
**Primary Dependencies**:
- `dartssh2` (SSHconnectionkey)
- `cryptography` (Ed25519keygenerate)
- `pointycastle` (RSAkeygenerate)
- `file_picker` (fileselect - newadd)
- `flutter_riverpod` (management)

**Storage**:
- `flutter_secure_storage` (private keypassphrase)
- `shared_preferences` (keymetadata)

**Testing**: `flutter_test`
**Target Platform**: Android 6.0+ (API 23+)
**Project Type**: Mobile (Flutter)
**Performance Goals**:
- Ed25519keygenerate: 30
- RSA-4096keygenerate: 60
- keylistdisplay: 2

**Constraints**:
- private keysave
- passphrasekeyrequired

**Scale/Scope**: 、~100keymanagement

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety | ✅ PASS | Dart strict mode、use |
| II. KISS & YAGNI | ✅ PASS | existing、requiredminimumimplementation |
| III. Test-First | ✅ PASS | keygeneratetestcreate |
| IV. Security-First | ✅ PASS | flutter_secure_storageuse、keyinformation |
| V. SOLID | ✅ PASS | SshKeyService、Provider |
| VI. DRY | ✅ PASS | SecureStorageServicereuse |
| Prohibited Naming | ✅ PASS | utils/helpersuse |

## Project Structure

### Documentation (this feature)

```text
specs/003-ssh-key-management/
├── plan.md # This file
├── research.md # Phase 0 output
├── data-model.md # Phase 1 output
├── quickstart.md # Phase 1 output
└── tasks.md # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
lib/
├── providers/
│ └── key_provider.dart # existing: SshKeyMeta, KeysNotifier
├── screens/keys/
│ ├── keys_screen.dart # : navigationadd
│ ├── key_generate_screen.dart # : keygenerateadd
│ ├── key_import_screen.dart # : file pickerimportadd
│ └── widgets/
│ └── key_tile.dart # existing: keydisplayWidget
└── services/
 └── keychain/
 ├── secure_storage.dart # existing: secure storage
 └── ssh_key_service.dart # new: keygenerate

test/
├── services/
│ └── keychain/
│ └── ssh_key_service_test.dart # new: keygeneratetest
└── screens/keys/
 └── key_screens_test.dart # new: screentest
```

**Structure Decision**: existingFlutter。`lib/services/keychain/`new`ssh_key_service.dart`add、keygenerate。

## Complexity Tracking

> **No Constitution violations. Table intentionally empty.**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| - | - | - |
