# Data Model: SSH Key Management

**Feature**: 002-ssh-key-management
**Date**: 2026-01-10

## Entities

### SSHKey

SSHkeymetadata。private key SecureStore separatelysave。

```typescript
interface SSHKey {
 /** UUID v4 */
 id: string;

 /** display (e.g., "Work Laptop", "Personal") */
 name: string;

 /** key */
 keyType: 'ed25519' | 'rsa-2048' | 'rsa-4096' | 'ecdsa';

 /** public key (OpenSSH authorized_keys format) */
 publicKey: string;

 /** SHA256 fingerprint (e.g., "SHA256:abcd1234...") */
 fingerprint: string;

 /** biometric authentication */
 requireBiometrics: boolean;

 /** create (Unix timestamp ms) */
 createdAt: number;

 /** importkey */
 imported: boolean;
}
```

**Storage**:
- metadata: `AsyncStorage` key `muxpod-ssh-keys` (JSON array)
- private key: `SecureStore` key `muxpod-ssh-key-{id}`

**Validation Rules**:
- `name`: 1-50、
- `publicKey`: OpenSSHformat
- `fingerprint`: `SHA256:` required

---

### KnownHost

serverhostkey。MITMuse。

```typescript
interface KnownHost {
 /** host (host:port) */
 identifier: string;

 /** host */
 host: string;

 /** */
 port: number;

 /** hostkey */
 keyType: 'ssh-ed25519' | 'ssh-rsa' | 'ecdsa-sha2-nistp256' | 'ecdsa-sha2-nistp384';

 /** public key (Base64) */
 publicKey: string;

 /** SHA256 fingerprint */
 fingerprint: string;

 /** firstadd (Unix timestamp ms) */
 addedAt: number;

 /** verification (Unix timestamp ms) */
 lastVerifiedAt: number;
}
```

**Storage**: `AsyncStorage` key `muxpod-known-hosts` (JSON array)

**Validation Rules**:
- `identifier`: `{host}:{port}` format
- `port`: 1-65535
- `fingerprint`: `SHA256:` required

---

### Connection (existingentity)

```typescript
interface Connection {
 // ... existing ...

 /** authentication (existing) */
 authMethod: 'password' | 'key';

 /** SSHkeyID (keyauthentication、existingrequiredchange) */
 keyId?: string;
}
```

**Relationship**:
- `Connection.keyId` → `SSHKey.id` ()

---

## State Transitions

### SSHKey Lifecycle

```
[Created] ─── generate ───→ [Active] ←─── import ───┐
 │ │
 │ delete │
 ▼ │
 [Deleted] [File Selected]
```

### KnownHost Verification

```
[New Connection]
 │
 ▼
[Check Known Hosts]
 │
 ├─── ───→ [Show Fingerprint Dialog]
 │ │
 │ ├─ Accept ─→ [Save & Connect]
 │ └─ Reject ─→ [Abort]
 │
 ├─── ───→ [Connect]
 │
 └─── ───→ [Show Warning Dialog]
 │
 ├─ Accept ─→ [Update & Connect]
 └─ Reject ─→ [Abort]
```

---

## Storage Keys

| Key | Type | Content |
|-----|------|---------|
| `muxpod-ssh-keys` | AsyncStorage | `SSHKey[]` metadata |
| `muxpod-ssh-key-{id}` | SecureStore | private key (PEMformat) |
| `muxpod-known-hosts` | AsyncStorage | `KnownHost[]` |
| `muxpod-ssh-password-{id}` | SecureStore | password (existing) |

---

## Indexes / Queries

### SSHKey
- **By ID**: `getKeyById(id: string): SSHKey | undefined`
- **All**: `getAllKeys(): SSHKey[]`
- **By Name**: `getKeyByName(name: string): SSHKey | undefined` ()

### KnownHost
- **By Identifier**: `getHostByIdentifier(identifier: string): KnownHost | undefined`
- **All**: `getAllHosts(): KnownHost[]`

---

## Constraints

1. **SSHKey.name** 
2. **SSHKey** delete、 **Connection** `keyId` `undefined` 
3. **KnownHost.identifier** 
4. private key **SecureStore** save
