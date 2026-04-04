/**
 * SSH Key Management Types
 *
 * SSH Key Managementusetype definitions。
 * implementation: src/types/sshKey.ts
 */

/**
 * SSHkeymetadata
 */
export interface SSHKey {
 /** UUID v4 */
 id: string;

 /** display */
 name: string;

 /** key */
 keyType: 'ed25519' | 'rsa-2048' | 'rsa-4096' | 'ecdsa';

 /** public key (OpenSSH authorized_keys format) */
 publicKey: string;

 /** SHA256 fingerprint */
 fingerprint: string;

 /** biometric authentication */
 requireBiometrics: boolean;

 /** create (Unix timestamp ms) */
 createdAt: number;

 /** importkey */
 imported: boolean;
}

/**
 * SSHkeycreateinput
 */
export type SSHKeyInput = Omit<SSHKey, 'id' | 'createdAt'>;

/**
 * known host
 */
export interface KnownHost {
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

/**
 * hostkeyverificationresult
 */
export type HostKeyVerificationResult =
 | { status: 'trusted'; host: KnownHost }
 | { status: 'unknown'; fingerprint: string; keyType: KnownHost['keyType'] }
 | { status: 'changed'; previousFingerprint: string; newFingerprint: string };

/**
 * AsyncStoragesave
 */
export const SSH_KEYS_STORAGE_KEY = 'muxpod-ssh-keys';
export const KNOWN_HOSTS_STORAGE_KEY = 'muxpod-known-hosts';

/**
 * SecureStorekey
 */
export const PRIVATE_KEY_PREFIX = 'muxpod-ssh-key-';
