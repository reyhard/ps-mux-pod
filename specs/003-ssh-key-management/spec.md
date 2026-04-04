# Feature Specification: SSH Key Management

**Feature Branch**: `003-ssh-key-management`
**Created**: 2026-01-11
**Status**: Draft
**Input**: User description: "SSH Key Managementimplementation。lib/screens/keys/TODO: key_generate_screen.dart(keygenerate)、key_import_screen.dart(file pickerimport)、keys_screen.dart(navigation)。lib/services/keychain/secure_storage.dart。"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - SSH key generation (Priority: P1)

SSHkey（Ed25519RSA）generate、secure storagesave。

**Why this priority**: SSHconnectionbasicfeature、keyauthenticationhighest priority。

**Independent Test**: key generation screenkeyselect「Generate」、keycreatelistdisplay。

**Acceptance Scenarios**:

1. **Given** key list screen, **When** FAB「Generate New Key」select, **Then** key generation screen
2. **Given** key generation screen, **When** 「MyKey」inputEd25519select「Generate」, **Then** keygeneratelistscreen「Key generated successfully」display
3. **Given** key generation screen, **When** RSAselect, **Then** key（2048/3072/4096）selectdisplay
4. **Given** key generation screen, **When** 「Generate」, **Then** error「Please enter a name」display

---

### User Story 2 - SSH key import (Priority: P1)

existingprivate keyfileselect、PEMformatimport。

**Why this priority**: existingkeyrequiredfeature。

**Independent Test**: importscreenfileselectPEM「Import」、keysavelistdisplay。

**Acceptance Scenarios**:

1. **Given** key list screen, **When** FAB「Import Key」select, **Then** key import screen
2. **Given** key import screen, **When** 「Select Private Key File」, **Then** file pickerprivate keyfileselect
3. **Given** private keyfileselect, **When** input「Import」, **Then** keyimportlistscreen「Key imported successfully」display
4. **Given** key import screen, **When** PEMformatprivate key, **Then** fileselectimportpossible
5. **Given** passphraseprivate keyselect, **When** passphraseinputimport, **Then** keyimport
6. **Given** passphraseprivate keyselect, **When** passphraseimport, **Then** errordisplay

---

### User Story 3 - SSH key listdisplay (Priority: P2)

can confirm all saved SSH keys in a list。

**Why this priority**: keymanagementselectrequired、generate/importfeature。

**Independent Test**: key list screen、savekeydisplay。

**Acceptance Scenarios**:

1. **Given** SSHkey1save, **When** key list screen, **Then** keykeydisplay
2. **Given** SSHkey0, **When** key list screen, **Then** 「No SSH keys yet」display

---

### User Story 4 - delete an SSH key (Priority: P3)

can delete SSH keys that are no longer needed。

**Why this priority**: required、。

**Independent Test**: keydeletedisplay、confirmationdelete。

**Acceptance Scenarios**:

1. **Given** keylistkey, **When** keydeleteselect, **Then** confirmationdisplay
2. **Given** deleteconfirmationdisplay, **When** 「Delete」, **Then** keydeletelist

---

### Edge Cases

- keygenerate → generatecompleteresult、errordisplaynotification
- formatprivate keyfileimport → errordisplay
- keysave → errordisplay
- key → （ID）

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Ed25519formatSSHkeygenerate
- **FR-002**: RSAformatSSHkey（2048/3072/4096）generate
- **FR-003**: generatekeyoptional
- **FR-004**: file pickerprivate keyfileimport
- **FR-005**: PEMformatprivate keyinputimport
- **FR-006**: passphraseprivate keyimport
- **FR-007**: private keysave
- **FR-008**: saveSSHkeylistconfirmation
- **FR-009**: saveSSHkeydelete
- **FR-010**: key list screenkey generation screenimportscreen
- **FR-011**: formatprivate keyimport、errordisplay

### Key Entities

- **SSHKey**: SSHkeyentity。ID、、key（ed25519/rsa）、create、public keyfingerprint。private keysecure storageseparatelysave。
- **KeyType**: keytype（Ed25519、RSA-2048、RSA-3072、RSA-4096）

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 30Ed25519keygenerate
- **SC-002**: 60RSA-4096keygenerate
- **SC-003**: 1fileprivate keyimport
- **SC-004**: key list screensavekey2display
- **SC-005**: generateimportkeySSHconnectionauthentication

## Assumptions

- Android 6.0use（flutter_secure_storagerequirements）
- file pickerfile_pickeruse
- SSHkeygeneratedartssh2pointycstleuse
- keymetadata（、、create）shared_preferencessave、private keyflutter_secure_storagesave
