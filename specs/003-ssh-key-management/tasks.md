# Tasks: SSH Key Management

**Input**: Design documents from `/specs/003-ssh-key-management/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: Includes tests based on the TDD approach (Constitution III. Test-First)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Mobile (Flutter)**: `lib/`, `test/` at repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependency setup

- [x] T001 Add dependencies to pubspec.yaml: file_picker, cryptography, pointycastle
- [x] T002 Run `flutter pub get` to install dependencies
- [x] T003 [P] Verify flutter analyze passes with new dependencies

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Add KeySource enum to lib/providers/key_provider.dart
- [x] T005 Extend SshKeyMeta with fingerprint and source fields in lib/providers/key_provider.dart
- [x] T006 Update SshKeyMeta.toJson/fromJson for new fields in lib/providers/key_provider.dart
- [x] T007 [P] Create SshKeyPair data class in lib/services/keychain/ssh_key_service.dart
- [x] T008 Create SshKeyService interface in lib/services/keychain/ssh_key_service.dart
- [x] T009 Implement isEncrypted() method using dartssh2 in lib/services/keychain/ssh_key_service.dart
- [x] T010 Implement calculateFingerprint() method in lib/services/keychain/ssh_key_service.dart
- [x] T011 Add navigation from keys_screen.dart to key_generate_screen.dart in lib/screens/keys/keys_screen.dart
- [x] T012 Add navigation from keys_screen.dart to key_import_screen.dart in lib/screens/keys/keys_screen.dart

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - SSH key generation (Priority: P1) 🎯 MVP

**Goal**: Ed25519RSAkeygenerate、secure storagesave

**Independent Test**: key generation screenkeyselect「Generate」、keycreatelistdisplay

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T013 [P] [US1] Unit test for Ed25519 key generation in test/services/keychain/ssh_key_service_test.dart
- [x] T014 [P] [US1] Unit test for RSA key generation (2048/3072/4096) in test/services/keychain/ssh_key_service_test.dart
- [x] T015 [P] [US1] Unit test for PEM format conversion in test/services/keychain/ssh_key_service_test.dart

### Implementation for User Story 1

- [x] T016 [US1] Implement generateEd25519() using cryptography package in lib/services/keychain/ssh_key_service.dart
- [x] T017 [US1] Implement generateRsa() using pointycastle package in lib/services/keychain/ssh_key_service.dart
- [x] T018 [US1] Implement toPem() for OpenSSH format output in lib/services/keychain/ssh_key_service.dart
- [x] T019 [US1] Implement toAuthorizedKeys() for public key output in lib/services/keychain/ssh_key_service.dart
- [x] T020 [US1] Add SshKeyService provider in lib/providers/key_provider.dart
- [x] T021 [US1] Implement _generate() method in lib/screens/keys/key_generate_screen.dart
- [x] T022 [US1] Save generated private key to SecureStorage in lib/screens/keys/key_generate_screen.dart
- [x] T023 [US1] Save SshKeyMeta to KeysNotifier in lib/screens/keys/key_generate_screen.dart
- [x] T024 [US1] Add loading indicator during RSA generation in lib/screens/keys/key_generate_screen.dart
- [x] T025 [US1] Add error handling for generation failures in lib/screens/keys/key_generate_screen.dart

**Checkpoint**: User Story 1 fully functional - Ed25519/RSA key generation works

---

## Phase 4: User Story 2 - SSH key import (Priority: P1)

**Goal**: filePEMexistingprivate keyimport

**Independent Test**: importscreenfileselectPEM「Import」、keysavelistdisplay

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T026 [P] [US2] Unit test for PEM parsing in test/services/keychain/ssh_key_service_test.dart
- [x] T027 [P] [US2] Unit test for passphrase-encrypted key parsing in test/services/keychain/ssh_key_service_test.dart
- [x] T028 [P] [US2] Unit test for invalid PEM rejection in test/services/keychain/ssh_key_service_test.dart

### Implementation for User Story 2

- [x] T029 [US2] Implement parseFromPem() using dartssh2 in lib/services/keychain/ssh_key_service.dart
- [x] T030 [US2] Implement _pickFile() using file_picker in lib/screens/keys/key_import_screen.dart
- [x] T031 [US2] Read file content after file selection in lib/screens/keys/key_import_screen.dart
- [x] T032 [US2] Detect passphrase requirement and show passphrase field in lib/screens/keys/key_import_screen.dart
- [x] T033 [US2] Implement _import() method to parse and save key in lib/screens/keys/key_import_screen.dart
- [x] T034 [US2] Save imported private key to SecureStorage in lib/screens/keys/key_import_screen.dart
- [x] T035 [US2] Save passphrase to SecureStorage if provided in lib/screens/keys/key_import_screen.dart
- [x] T036 [US2] Save SshKeyMeta to KeysNotifier in lib/screens/keys/key_import_screen.dart
- [x] T037 [US2] Add validation error for invalid PEM format in lib/screens/keys/key_import_screen.dart
- [x] T038 [US2] Add error handling for wrong passphrase in lib/screens/keys/key_import_screen.dart

**Checkpoint**: User Story 2 fully functional - file import and PEM paste work

---

## Phase 5: User Story 3 - SSH key listdisplay (Priority: P2)

**Goal**: can confirm all saved SSH keys in a list

**Independent Test**: key list screen、savekeydisplay

### Implementation for User Story 3

- [x] T039 [US3] Watch keysProvider in lib/screens/keys/keys_screen.dart
- [x] T040 [US3] Display ListView.builder with keys list in lib/screens/keys/keys_screen.dart
- [x] T041 [US3] Use KeyTile widget for each key item in lib/screens/keys/keys_screen.dart
- [x] T042 [US3] Add fingerprint to KeyTile display in lib/screens/keys/widgets/key_tile.dart
- [x] T043 [US3] Add loading indicator while keys loading in lib/screens/keys/keys_screen.dart
- [x] T044 [US3] Show empty state when no keys exist in lib/screens/keys/keys_screen.dart

**Checkpoint**: User Story 3 fully functional - key list displays correctly

---

## Phase 6: User Story 4 - delete an SSH key (Priority: P3)

**Goal**: can delete SSH keys that are no longer needed

**Independent Test**: keydeletedisplay、confirmationdelete

### Implementation for User Story 4

- [x] T045 [US4] Add onDelete callback to KeyTile in lib/screens/keys/widgets/key_tile.dart
- [x] T046 [US4] Implement delete confirmation dialog in lib/screens/keys/keys_screen.dart
- [x] T047 [US4] Call keysNotifier.remove() on confirmation in lib/screens/keys/keys_screen.dart
- [x] T048 [US4] Delete private key from SecureStorage in lib/screens/keys/keys_screen.dart
- [x] T049 [US4] Delete passphrase from SecureStorage if exists in lib/screens/keys/keys_screen.dart
- [x] T050 [US4] Show success snackbar after deletion in lib/screens/keys/keys_screen.dart

**Checkpoint**: User Story 4 fully functional - key deletion works with confirmation

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T051 [P] Add copy public key functionality to KeyTile in lib/screens/keys/widgets/key_tile.dart
- [x] T052 [P] Add RSA key generation progress indicator (background compute) in lib/screens/keys/key_generate_screen.dart
- [x] T053 Run flutter analyze and fix any warnings
- [x] T054 Run all tests and ensure pass in test/services/keychain/
- [x] T055 [P] Update CLAUDE.md if needed
- [x] T056 Verify quickstart.md steps work correctly

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
 - User stories can proceed in priority order (P1 → P2 → P3)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - Independent of US1
- **User Story 3 (P2)**: Can start after Foundational (Phase 2) - Benefits from US1/US2 for test data
- **User Story 4 (P3)**: Can start after Foundational (Phase 2) - Requires US3 for list display

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Service methods before screen integration
- Core implementation before UI polish
- Story complete before moving to next priority

### Parallel Opportunities

- T003 can run in parallel during Setup
- T007 can run in parallel during Foundational
- T013, T014, T015 can run in parallel (all US1 tests)
- T026, T027, T028 can run in parallel (all US2 tests)
- US1 and US2 can theoretically run in parallel (both P1)
- T051, T052, T055 can run in parallel during Polish

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together:
Task: "Unit test for Ed25519 key generation in test/services/keychain/ssh_key_service_test.dart"
Task: "Unit test for RSA key generation in test/services/keychain/ssh_key_service_test.dart"
Task: "Unit test for PEM format conversion in test/services/keychain/ssh_key_service_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (keygenerate)
4. **STOP and VALIDATE**: Test key generation independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP - keygeneratepossible!)
3. Add User Story 2 → Test independently → Deploy/Demo (importpossible!)
4. Add User Story 3 → Test independently → Deploy/Demo (listdisplayimprovement!)
5. Add User Story 4 → Test independently → Deploy/Demo (deletepossible!)
6. Each story adds value without breaking previous stories

### Recommended Order

US1US2P1、US1（generate）completerecommended:
- US1SshKeyService
- US2US1toPem/calculateFingerprintreuse

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Security: Never log private key content, clear sensitive data after use
