/**
 * SSH Key Manager Service Contract
 *
 * SSH key generation、import、management。
 * implementation: src/services/ssh/keyManager.ts
 */

import type { SSHKey } from './types';

/**
 * keygenerate
 */
export interface GenerateKeyOptions {
 /** keydisplay */
 name: string;
 /** key (: ed25519) */
 keyType?: 'ed25519' | 'rsa-2048' | 'rsa-4096';
 /** biometric authentication (: true) */
 requireBiometrics?: boolean;
}

/**
 * keyimport
 */
export interface ImportKeyOptions {
 /** keydisplay */
 name: string;
 /** private key (PEM OpenSSH format) */
 privateKey: string;
 /** passphrase () */
 passphrase?: string;
 /** biometric authentication (: true) */
 requireBiometrics?: boolean;
}

/**
 * keygenerateresult
 */
export interface GenerateKeyResult {
 /** generatekeymetadata */
 key: SSHKey;
 /** public key (authorized_keys format) */
 publicKey: string;
}

/**
 * keyimporterror
 */
export type ImportKeyError =
 | { type: 'INVALID_FORMAT'; message: string }
 | { type: 'INVALID_PASSPHRASE'; message: string }
 | { type: 'UNSUPPORTED_KEY_TYPE'; message: string }
 | { type: 'DUPLICATE_NAME'; message: string }
 | { type: 'STORAGE_ERROR'; message: string };

/**
 * SSH Key Manager 
 */
export interface KeyManagerService {
 /**
 * SSHkeygenerate
 * @throws generate
 */
 generateKey(options: GenerateKeyOptions): Promise<GenerateKeyResult>;

 /**
 * existingprivate keyimport
 * @throws ImportKeyError
 */
 importKey(options: ImportKeyOptions): Promise<SSHKey>;

 /**
 * keymetadataretrieve
 */
 getAllKeys(): Promise<SSHKey[]>;

 /**
 * IDkeyretrieve
 */
 getKeyById(id: string): Promise<SSHKey | null>;

 /**
 * private keyretrieve（biometric authenticationrequired）
 * @throws authentication
 */
 getPrivateKey(id: string): Promise<string>;

 /**
 * keydelete
 * @returns delete true
 */
 deleteKey(id: string): Promise<boolean>;

 /**
 * key
 */
 isNameAvailable(name: string): Promise<boolean>;

 /**
 * private keyformatverification
 */
 validatePrivateKey(privateKey: string): {
 valid: boolean;
 keyType?: SSHKey['keyType'];
 encrypted?: boolean;
 error?: string;
 };
}
