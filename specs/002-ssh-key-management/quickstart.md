# Quickstart: SSH Key Management

**Feature**: 002-ssh-key-management

## dependenciesadd

```bash
pnpm add expo-document-picker expo-local-authentication
```

## file structure

```
src/
├── types/
│ └── sshKey.ts # SSHKey, KnownHost type definitions
├── services/
│ └── ssh/
│ ├── keyManager.ts # SSH key generation, import, and management
│ ├── knownHostManager.ts # known host management
│ └── index.ts # add
├── stores/
│ └── keyStore.ts # SSHkeymanagement (Zustand)
├── components/
│ └── connection/
│ ├── KeySelector.tsx # keyselectUI
│ ├── AuthMethodSelector.tsx # authentication methodselect
│ └── HostKeyDialog.tsx # host key confirmation dialog
└── app/
 └── keys/
 ├── index.tsx # key list screen
 ├── [id].tsx # key details screen
 └── import.tsx # key import screen
```

## implementation

### Phase 1: feature (P1)

1. **type definitions** (`src/types/sshKey.ts`)
 - `SSHKey`, `KnownHost`, 

2. **key management service** (`src/services/ssh/keyManager.ts`)
 - `generateKey()` - ED25519keygenerate
 - `importKey()` - keyimport
 - `getAllKeys()` / `getKeyById()` - retrieve
 - `deleteKey()` - delete

3. **key** (`src/stores/keyStore.ts`)
 - Zustand store management

4. **connection** (`src/components/connection/ConnectionForm.tsx`)
 - authentication methodselectUIadd
 - keyselect

### Phase 2: managementUI (P2)

5. **key list screen** (`app/keys/index.tsx`)
 - keydisplay
 - generateimport

6. **key details screen** (`app/keys/[id].tsx`)
 - public keydisplay
 - deletefeature

7. **key selector component** (`src/components/connection/KeySelector.tsx`)
 - formatkeyselect

### Phase 3: (P3)

8. **known host management** (`src/services/ssh/knownHostManager.ts`)
 - hostkeyverification
 - hostsave

9. **host key dialog** (`src/components/connection/HostKeyDialog.tsx`)
 - firstat connection timeconfirmation
 - keychangewarning

## usage examples

### keygenerate

```typescript
import { keyManager } from '@/services/ssh/keyManager';

const result = await keyManager.generateKey({
 name: 'My Server Key',
 keyType: 'ed25519',
 requireBiometrics: true,
});

console.log(result.publicKey);
// ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... muxpod-key
```

### keyimport

```typescript
import { keyManager } from '@/services/ssh/keyManager';

const key = await keyManager.importKey({
 name: 'Existing Key',
 privateKey: `-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----`,
 passphrase: 'optional-passphrase',
});
```

### hostkeyverification

```typescript
import { knownHostManager } from '@/services/ssh/knownHostManager';

const result = await knownHostManager.verifyHostKey({
 host: 'example.com',
 port: 22,
 keyType: 'ssh-ed25519',
 publicKey: 'AAAAC3NzaC1lZDI1NTE5...',
 fingerprint: 'SHA256:abcd1234...',
});

if (result.status === 'unknown') {
 // firstconnection: confirmation
} else if (result.status === 'changed') {
 // warning: hostkeychange
}
```

## test

```bash
# test
pnpm test src/services/ssh/keyManager.test.ts

# 
pnpm typecheck
```
