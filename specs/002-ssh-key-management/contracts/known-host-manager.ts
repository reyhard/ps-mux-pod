/**
 * Known Host Manager Service Contract
 *
 * known hostmanagementverification。
 * implementation: src/services/ssh/knownHostManager.ts
 */

import type { KnownHost, HostKeyVerificationResult } from './types';

/**
 * hostkeyinformation
 */
export interface HostKeyInfo {
 /** host */
 host: string;
 /** */
 port: number;
 /** key */
 keyType: KnownHost['keyType'];
 /** public key (Base64) */
 publicKey: string;
 /** fingerprint */
 fingerprint: string;
}

/**
 * Known Host Manager 
 */
export interface KnownHostManagerService {
 /**
 * hostkeyverification
 * @param hostKeyInfo serverhostkeyinformation
 * @returns verificationresult
 */
 verifyHostKey(hostKeyInfo: HostKeyInfo): Promise<HostKeyVerificationResult>;

 /**
 * hostkeysave
 * @param hostKeyInfo hostkeyinformation
 */
 trustHostKey(hostKeyInfo: HostKeyInfo): Promise<KnownHost>;

 /**
 * hostkeyupdate（keychange）
 * @param hostKeyInfo hostkeyinformation
 */
 updateHostKey(hostKeyInfo: HostKeyInfo): Promise<KnownHost>;

 /**
 * known hostretrieve
 */
 getAllHosts(): Promise<KnownHost[]>;

 /**
 * hostretrieve
 * @param identifier host:port format
 */
 getHostByIdentifier(identifier: string): Promise<KnownHost | null>;

 /**
 * hostdelete
 * @param identifier host:port format
 * @returns delete true
 */
 deleteHost(identifier: string): Promise<boolean>;

 /**
 * known hostdelete
 */
 clearAllHosts(): Promise<void>;

 /**
 * hostgenerate
 */
 createIdentifier(host: string, port: number): string;
}
