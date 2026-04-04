# Feature Specification: SSH Key Management

**Feature Branch**: `002-ssh-key-management`
**Created**: 2026-01-10
**Status**: Draft
**Input**: User description: "SSH key management feature. Secure Enclave integration via expo-secure-store. ED25519 key generation, existing key import, key list, authentication method selection UI, and known-host management."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate a New SSH Key and Connect to a Server (Priority: P1)

The user wants to generate a new ED25519 SSH key pair inside the app and use it to connect securely to a remote server. The key is stored in device secure storage and protected by biometrics.

**Why this priority**: SSH key authentication is safer than password authentication and is recommended for many servers. Without key generation, users must rely on external tools, which significantly hurts usability.

**Independent Test**: A new user installs the app, generates a key, copies the public key to the server, and connects over SSH with that key.

**Acceptance Scenarios**:

1. **Given** the user is on the key management screen, **When** they choose `Generate New Key` and enter a name, **Then** an ED25519 key pair is generated, saved to secure storage, and the public key is shown
2. **Given** a generated key exists, **When** the user selects `Key Authentication` in connection settings and chooses the generated key, **Then** that key can be used to connect to the server
3. **Given** the key is protected by biometric authentication, **When** a connection starts using that key, **Then** biometrics are required and the connection only proceeds after success

---

### User Story 2 - Import an Existing SSH Key (Priority: P1)

The user wants to import an existing SSH private key generated on another device or by another tool and keep using existing server settings.

**Why this priority**: Many users already have SSH keys and want to reuse them. Import is just as important as generating a new key.

**Independent Test**: The user imports a PEM or OpenSSH private key file and confirms that it can be used to connect to the existing server.

**Acceptance Scenarios**:

1. **Given** the user is on the key management screen, **When** they choose `Import Key` and select a private key file, **Then** the key is validated and saved to secure storage
2. **Given** a passphrase-protected private key exists, **When** the user imports it, **Then** the app asks for the passphrase and imports the key after decrypting it with the correct passphrase
3. **Given** an invalid or corrupted key file exists, **When** the user tries to import it, **Then** an appropriate error message is shown and the import is rejected

---

### User Story 3 - List and Manage SSH Keys (Priority: P2)

The user wants to view all stored SSH keys in a list, inspect details, and delete keys they no longer need.

**Why this priority**: This is needed for users with multiple keys who need to organize them. It can be implemented after the main generate/import/connect flows.

**Independent Test**: A user with multiple keys can open the list, inspect a specific key, and delete an unnecessary key.

**Acceptance Scenarios**:

1. **Given** the user has multiple keys saved, **When** they open the key management screen, **Then** all keys are listed with their name, type, and created date
2. **Given** the key list is visible, **When** the user selects a specific key, **Then** the public key fingerprint, created time, and related connection settings are shown
3. **Given** a key should be deleted, **When** the user confirms deletion, **Then** the key is removed from secure storage

---

### User Story 4 - Choose an Authentication Method at Connection Time (Priority: P2)

The user wants to choose between password authentication and SSH key authentication when configuring a connection, and choose which key to use if key auth is selected.

**Why this priority**: The connection settings UI must integrate with key management. This is an extension of the existing connection settings screen.

**Independent Test**: The user switches authentication methods in a new connection setup and successfully connects with each method.

**Acceptance Scenarios**:

1. **Given** the user is on the connection settings screen, **When** they view the authentication section, **Then** they see `Password` and `SSH Key` options
2. **Given** `SSH Key` is selected, **When** the user taps the key picker, **Then** a list of saved keys appears and one can be selected
3. **Given** no keys are registered, **When** the user selects `SSH Key`, **Then** a link to `Add Key` appears and can navigate to key management

---

### User Story 5 - Manage Known Hosts (Priority: P3)

The user wants to manage host keys for connected servers and prevent connections to unauthorized servers. Host key verification should be required on first connection.

**Why this priority**: This is an important security feature, but it can be implemented after the core SSH connection flow. It adds a layer against man-in-the-middle attacks.

**Independent Test**: When the user connects to a new server for the first time, a host key confirmation appears, and after approval it connects automatically on future attempts.

**Acceptance Scenarios**:

1. **Given** the user is connecting to a new server, **When** the connection starts, **Then** the server host key fingerprint is shown and approval is requested
2. **Given** the host key is saved, **When** the user reconnects to the same server, **Then** the host key is automatically verified and the connection proceeds without confirmation
3. **Given** the server host key has changed, **When** the user tries to connect, **Then** a warning is shown and the user can approve the new host key or cancel
4. **Given** the user is on the known-host management screen, **When** they delete a specific host entry, **Then** the next connection to that host will prompt for host key approval again

---

### Edge Cases

- If the app crashes or is interrupted during key generation, incomplete keys are not saved
- If secure storage is unavailable, such as on older Android versions, show an appropriate error message
- If a key with the same name already exists, offer overwrite or rename options
- If the wrong passphrase is entered for a passphrase-protected key, allow retrying up to 3 times
- If the known-host storage is full, suggest deleting old entries

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system must generate ED25519 SSH key pairs
- **FR-002**: The system must save generated keys with a user-defined name
- **FR-003**: The system must import PEM and OpenSSH private keys
- **FR-004**: The system must decrypt and import passphrase-protected private keys
- **FR-005**: The system must store private keys in device secure storage with Secure Enclave/Keystore integration
- **FR-006**: The system must be able to require biometric authentication when a key is used
- **FR-007**: The system must list all stored keys
- **FR-008**: The system must show each key's public key, fingerprint, and created date
- **FR-009**: The system must allow the user to delete keys
- **FR-010**: The system must let the user choose either `Password` or `SSH Key` as the connection authentication method
- **FR-011**: The system must let the user choose which key to use for SSH key authentication
- **FR-012**: The system must show the server host key fingerprint on first connection and request approval
- **FR-013**: The system must save approved host keys and automatically verify them on later connections
- **FR-014**: The system must warn when a host key changes
- **FR-015**: The system must list and delete known-host entries

### Key Entities

- **SSHKey**: Represents an SSH key pair. Includes the name, type such as ED25519, public key, created date, and fingerprint. The private key itself is managed separately in secure storage.
- **KnownHost**: Represents a known server host key. Includes host name, port, key type, fingerprint, and last connection time.
- **Connection**: Connection settings. Includes the authentication method (`password` / `key`) and, when key auth is selected, a reference to the `SSHKey` to use.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The user can generate a new SSH key and copy its public key to the clipboard within 30 seconds
- **SC-002**: The user can import an existing private key file and use it for connection within 1 minute
- **SC-003**: Key-based authentication completes in the same time as password authentication, within 5 seconds
- **SC-004**: If biometric authentication is enabled, one authentication step starts the connection when the key is used
- **SC-005**: Host key change warnings are shown 100% of the time when a change is detected
- **SC-006**: Private keys are never stored outside the device secure storage

## Assumptions

- The device runs Android 8.0 or later and supports hardware-backed Keystore similar to Secure Enclave
- The user has biometric authentication configured, such as fingerprint or face unlock
- ED25519 is preferred, and RSA (2048/4096-bit) is also supported
- When importing a key, the file is selected from local or cloud storage on the device
- Known-host data is stored locally, just like connection settings
