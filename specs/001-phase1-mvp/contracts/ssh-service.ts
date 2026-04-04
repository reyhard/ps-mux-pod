/**
 * SSH Service Contract
 *
 * SSHclientserviceinterface。
 * implement react-native-ssh-sftp 。
 */

import type { Connection } from '../../../src/types/connection';

/**
 * SSH connection
 */
export interface SSHConnectOptions {
  /** passwordauthenticationpassword */
  password?: string;
  /** keyauthenticationprivate key（PEMformat） */
  privateKey?: string;
  /** private keypassphrase */
  passphrase?: string;
}

/**
 * shell
 */
export interface ShellOptions {
  /** terminal */
  term?: string;
  /** count */
  cols?: number;
  /** rows */
  rows?: number;
}

/**
 * SSH connectionstate
 */
export interface SSHEvents {
  /** datareceive */
  onData: (data: string) => void;
  /** connection */
  onClose: () => void;
  /** error */
  onError: (error: Error) => void;
}

/**
 * SSHclientinterface
 */
export interface ISSHClient {
  /**
   * SSH connectionestablishment
   * @param connection connection settings
   * @param options authentication
   * @throws connection
   */
  connect(connection: Connection, options: SSHConnectOptions): Promise<void>;

  /**
   * connectiondisconnect
   */
  disconnect(): Promise<void>;

  /**
   * connectionin progress
   */
  isConnected(): boolean;

  /**
   * shellstart
   * @param options shell
   */
  startShell(options?: ShellOptions): Promise<void>;

  /**
   * shelldata
   * @param data senddata
   */
  write(data: string): Promise<void>;

  /**
   * terminalsizechange
   * @param cols count
   * @param rows rows
   */
  resize(cols: number, rows: number): Promise<void>;

  /**
   * commandrunresultretrieve
   * @param command runcommand
   * @returns commandoutput
   */
  exec(command: string): Promise<string>;

  /**
   * settings
   * @param events 
   */
  setEventHandlers(events: Partial<SSHEvents>): void;
}

/**
 * SSHclient
 */
export interface ISSHClientFactory {
  /**
   * newSSHclientcreate
   */
  create(): ISSHClient;
}



