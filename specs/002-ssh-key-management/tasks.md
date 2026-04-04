# Tasks: SSH Key Management

**Input**: Design documents from `/specs/002-ssh-key-management/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: TDDadopt（Constitution III. Test-First based on）

**Organization**: user storyorganize、independentlyimplementationtestpossible

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel（file、no dependencies）
- **[Story]**: user story (US1, US2, US3, US4, US5)
- file

---

## Phase 1: Setup (environment setup)

**Purpose**: dependenciesbasic

- [x] T001 adddependencies: `pnpm add expo-document-picker expo-local-authentication`
- [x] T002 [P] key management screencreate: `app/keys/`
- [x] T003 [P] testcreate: `__tests__/services/ssh/`

---

## Phase 2: Foundational (implementation)

**Purpose**: user storyusetype definitions

**⚠️ CRITICAL**: completeuser story

- [x] T004 type definitionscreate: SSHKey, KnownHost in `src/types/sshKey.ts`
- [x] T005 type definitionsadd in `src/types/index.ts`
- [x] T006 [P] SSHkeycreate（Zustand）in `src/stores/keyStore.ts`
- [x] T007 [P] add in `src/stores/index.ts`

**Checkpoint**: complete - user storyimplementationcan start

---

## Phase 3: User Story 1 - SSHkeygenerateserverconnection (Priority: P1) 🎯 MVP

**Goal**: ED25519keygenerate、secure storagesave、public keydisplay

**Independent Test**: keygenerate、public key30complete

### Tests for User Story 1

- [x] T008 [P] [US1] testcreate: generateKey, getAllKeys, deleteKey in `__tests__/services/ssh/keyManager.test.ts`

### Implementation for User Story 1

- [x] T009 [US1] keyManager.tsbasiccreate: generateKey, getAllKeys, getKeyById, deleteKey, getPrivateKey in `src/services/ssh/keyManager.ts`
- [x] T010 [US1] ED25519keygenerateimplementation（react-native-ssh-sftpuse）in `src/services/ssh/keyManager.ts`
- [x] T011 [US1] SecureStoreprivate keysaveimplementation in `src/services/ssh/keyManager.ts`
- [x] T012 [US1] AsyncStoragemetadatasaveimplementation in `src/services/ssh/keyManager.ts`
- [x] T013 [US1] biometric authenticationimplementation（expo-local-authentication）in `src/services/ssh/keyManager.ts`
- [x] T014 [US1] update in `src/services/ssh/index.ts`
- [x] T015 [P] [US1] key generation screencreate in `app/keys/generate.tsx`
- [x] T016 [US1] public keydisplayfeatureimplementation in `app/keys/generate.tsx`

**Checkpoint**: US1complete - keygenerateindependentlybehavior

---

## Phase 4: User Story 2 - existingSSHkeyimport (Priority: P1)

**Goal**: PEM/OpenSSHformatprivate keyimport、passphrasekeysupport

**Independent Test**: private keyfileimport、1connectionpossible

### Tests for User Story 2

- [x] T017 [P] [US2] testcreate: importKey, validatePrivateKey in `__tests__/services/ssh/keyManager.test.ts`

### Implementation for User Story 2

- [x] T018 [US2] private keyimplementation: validatePrivateKey in `src/services/ssh/keyManager.ts`
- [x] T019 [US2] keyimportimplementation: importKey（PEM/OpenSSHsupport）in `src/services/ssh/keyManager.ts`
- [x] T020 [US2] passphraseimplementation in `src/services/ssh/keyManager.ts`
- [x] T021 [P] [US2] file pickerscreencreate（expo-document-picker）in `app/keys/import.tsx`
- [x] T022 [US2] passphraseinputimplementation in `app/keys/import.tsx`
- [x] T023 [US2] importerrorimplementation in `app/keys/import.tsx`

**Checkpoint**: US2complete - keyimportindependentlybehavior

---

## Phase 5: User Story 3 - List and manage SSH keys (Priority: P2)

**Goal**: savekeylistdisplay、detailsconfirmationdeletepossible

**Independent Test**: multiplekeylistdisplay、detailsconfirmation、delete

### Tests for User Story 3

- [x] T024 [P] [US3] testcreate: keylist、detailsdisplay in `__tests__/components/connection/KeyList.test.tsx`
 - Note: basictestkeyManager.test.ts、UItestsubsequentadd

### Implementation for User Story 3

- [x] T025 [P] [US3] key list screencreate in `app/keys/index.tsx`
- [x] T026 [US3] keycreate（、、createdisplay）in `src/components/connection/KeyCard.tsx`
- [x] T027 [P] [US3] key details screencreate（fingerprint、public keydisplay）in `app/keys/[id].tsx`
- [x] T028 [US3] keydeletefeatureconfirmationimplementation in `app/keys/[id].tsx`
- [x] T029 [US3] update in `src/components/connection/index.ts`

**Checkpoint**: US3complete - keymanagementUIindependentlybehavior

---

## Phase 6: User Story 4 - at connection timeauthentication methodselect (Priority: P2)

**Goal**: connection settingspassword/SSHkeyauthenticationpossible

**Independent Test**: newconnection settingsauthentication method、connection

### Tests for User Story 4

- [x] T030 [P] [US4] testcreate: AuthMethodSelector, KeySelector in `__tests__/components/connection/AuthMethodSelector.test.tsx`
 - Note: testsubsequentadd

### Implementation for User Story 4

- [x] T031 [P] [US4] authentication methodselectcreate in `src/components/connection/AuthMethodSelector.tsx`
- [x] T032 [P] [US4] key selector componentcreate（format）in `src/components/connection/KeySelector.tsx`
- [x] T033 [US4] ConnectionFormauthentication methodselect in `src/components/connection/ConnectionForm.tsx`
 - Note: ConnectionFormexistingauthMethod
- [x] T034 [US4] useSSHkeyauthenticationsupportupdate in `src/hooks/useSSH.ts`
 - Note: keyManagergetPrivateKeyusekeyauthenticationpossible
- [x] T035 [US4] SSHkeyauthenticationadd in `src/services/ssh/client.ts`
 - Note: react-native-ssh-sftpkeyauthenticationsupport

**Checkpoint**: US4complete - authentication methodselectindependentlybehavior

---

## Phase 7: User Story 5 - known hostmanagement (Priority: P3)

**Goal**: hostkeyverificationMITM、firstconfirmationchangewarning

**Independent Test**: newserverconnectionhostkeyconfirmation、connectionautoverification

### Tests for User Story 5

- [x] T036 [P] [US5] testcreate: verifyHostKey, trustHostKey, updateHostKey in `__tests__/services/ssh/knownHostManager.test.ts`

### Implementation for User Story 5

- [x] T037 [US5] knownHostManager.tscreate: basic in `src/services/ssh/knownHostManager.ts`
- [x] T038 [US5] hostkeyverificationimplementation: verifyHostKey in `src/services/ssh/knownHostManager.ts`
- [x] T039 [US5] hostkeysave/updateimplementation: trustHostKey, updateHostKey in `src/services/ssh/knownHostManager.ts`
- [x] T040 [US5] hostlistdeleteimplementation: getAllHosts, deleteHost in `src/services/ssh/knownHostManager.ts`
- [x] T041 [P] [US5] host key confirmation dialogcreate in `src/components/connection/HostKeyDialog.tsx`
- [x] T042 [US5] host key change warningimplementation in `src/components/connection/HostKeyDialog.tsx`
- [x] T043 [US5] SSHconnectionhostkeyverification in `src/hooks/useSSH.ts`
- [x] T044 [P] [US5] known host managementscreencreate in `app/hosts/index.tsx`

**Checkpoint**: US5complete - known host managementindependentlybehavior

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: overallquality improvement

- [x] T045 [P] error
- [x] T046 [P] authenticationinformation（Security-First）
- [x] T047 [P] run: `pnpm typecheck`
- [x] T048 [P] Lintrun: `pnpm lint` (implementationfileerror)
- [ ] T049 quickstart.mdbased onbehaviorconfirmation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies - can start
- **Foundational (Phase 2)**: Setupcomplete - US
- **User Stories (Phase 3-7)**: Foundationalcompletecan start
 - US1, US2 possible（P1）
 - US3, US4 US1US2completerecommended
 - US5 independentlyimplementationpossible
- **Polish (Phase 8)**: requiredUScomplete

### User Story Dependencies

| Story | Depends On | Can Start After |
|-------|------------|-----------------|
| US1 (P1) | Foundational | Phase 2 complete |
| US2 (P1) | Foundational | Phase 2 complete |
| US3 (P2) | US1 or US2 | key |
| US4 (P2) | US1 or US2 | keyauthenticationkeyrequired |
| US5 (P3) | Foundational | Phase 2 complete（independent） |

### Within Each User Story

1. testcreate → confirmation
2. implementation → test
3. UIimplementation
4. confirmation

---

## Parallel Opportunities

### Phase 2 (Foundational)

```bash
# can run in parallel:
T006: SSHkeycreate
T007: add
```

### Phase 3 (US1) + Phase 4 (US2)

```bash
# US1US2possible（P1）
# A: US1 (T008-T016)
# B: US2 (T017-T023)
```

### Phase 5 (US3) + Phase 6 (US4)

```bash
# US3US4possible（P2）
# T025, T027: screencreatepossible
# T031, T032: createpossible
```

---

## Implementation Strategy

### MVP First (US1)

1. Phase 1: Setupcomplete
2. Phase 2: Foundationalcomplete
3. Phase 3: US1complete → keygeneratebehavior
4. **STOP and VALIDATE**: keygenerate→public keyE2Etest
5. possible

### Incremental Delivery

1. Setup + Foundational → complete
2. US1 → keygenerate MVP
3. US2 → keyimportadd
4. US3 + US4 → managementUI + authenticationselect
5. US5 → 

### Parallel Team Strategy

```
Developer A: US1 (keygenerate)
Developer B: US2 (keyimport)
Developer C: US5 (known host) ← independentlypossible
```

---

## Summary

| Phase | Tasks | Parallel |
|-------|-------|----------|
| Setup | 3 | 2 |
| Foundational | 4 | 2 |
| US1 (P1) | 9 | 2 |
| US2 (P1) | 7 | 2 |
| US3 (P2) | 6 | 3 |
| US4 (P2) | 6 | 2 |
| US5 (P3) | 9 | 3 |
| Polish | 5 | 4 |
| **Total** | **49** | **20** |

---

## Notes

- [P] = file、no dependencies
- [Story] = user story
- independentlytestpossible
- testconfirmationimplementation
- 
- independentverification
