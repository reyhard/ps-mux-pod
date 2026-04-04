# Implementation Plan: SSH Key Management

**Branch**: `002-ssh-key-management` | **Date**: 2026-01-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-ssh-key-management/spec.md`

## Summary

SSH key generation, import, and managementfeatureknown host managementimplementation。ED25519keygenerate、PEM/OpenSSHformatprivate keyimport、expo-secure-storesecure storagesave、biometric authentication、known hostMITM。

## Technical Context

**Language/Version**: TypeScript 5.6+
**Primary Dependencies**: Expo ~52.0.0, React Native 0.76.0, react-native-ssh-sftp, expo-secure-store, expo-document-picker (add), expo-local-authentication (add)
**Storage**: expo-secure-store (private key), AsyncStorage (metadata)
**Testing**: Jest + jest-expo + @testing-library/react-native
**Target Platform**: Android 8.0+ (Keystoresupport)
**Project Type**: Mobile (Expo Router)
**Performance Goals**: keygenerate < 30, authentication < 5
**Constraints**: private keySecureStoresave, biometric authenticationsupportrequired
**Scale/Scope**: maximum50key、100known host

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety | ✅ PASS | strict: true, entitytype definitions |
| II. KISS & YAGNI | ✅ PASS | requiredminimumfeatureimplementation |
| III. Test-First | ✅ PASS | testrequired |
| IV. Security-First | ✅ PASS | SecureStoreuse、biometric authentication、 |
| V. SOLID | ✅ PASS | SRP: KeyManager / KnownHostManager |
| VI. DRY | ✅ PASS | existingauth.ts |
| Prohibited Naming | ✅ PASS | utils/helpers use |

**Post-Design Re-check**: ✅ 

## Project Structure

### Documentation (this feature)

```text
specs/002-ssh-key-management/
├── plan.md # This file
├── research.md # Phase 0 output
├── data-model.md # Phase 1 output
├── quickstart.md # Phase 1 output
├── contracts/ # Phase 1 output
│ ├── types.ts
│ ├── key-manager.ts
│ └── known-host-manager.ts
└── tasks.md # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
src/
├── types/
│ ├── connection.ts # existing (keyId)
│ └── sshKey.ts # new: SSHKey, KnownHost
├── services/
│ └── ssh/
│ ├── auth.ts # existing (passwordmanagement)
│ ├── client.ts # existing (SSHconnection)
│ ├── keyManager.ts # new: keygenerateimportmanagement
│ ├── knownHostManager.ts # new: known host management
│ └── index.ts # update: add
├── stores/
│ ├── connectionStore.ts # existing
│ └── keyStore.ts # new: SSHkeymanagement
├── components/
│ └── connection/
│ ├── ConnectionForm.tsx # update: authentication methodselectadd
│ ├── KeySelector.tsx # new: key selector component
│ ├── AuthMethodSelector.tsx # new: password/key
│ └── HostKeyDialog.tsx # new: hostkeyconfirmation
└── hooks/
 └── useSSH.ts # update: keyauthenticationsupport

app/
└── keys/
 ├── index.tsx # new: key list screen
 ├── [id].tsx # new: key details screen
 └── import.tsx # new: key import screen

__tests__/
└── services/
 └── ssh/
 ├── keyManager.test.ts # new
 └── knownHostManager.test.ts # new
```

**Structure Decision**: existingExpo Router + src/。SSH`src/services/ssh/`、key management screen`app/keys/`add。

## Complexity Tracking

> - 

## Dependencies to Add

```bash
pnpm add expo-document-picker expo-local-authentication
```

## Related Documents

- [research.md](./research.md) - result
- [data-model.md](./data-model.md) - entity
- [quickstart.md](./quickstart.md) - implementation
- [contracts/](./contracts/) - 
