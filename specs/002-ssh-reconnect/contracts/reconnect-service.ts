/**
 * ReconnectService Contract
 *
 * Interface definition for the service that manages SSH reconnect logic.
 * Implementation goes in src/services/ssh/reconnect.ts.
 */

import type { Connection, ConnectionState } from '@/types/connection';

/**
 * Reconnect options
 */
export interface ReconnectOptions {
  /** Credentials (password or private key) */
  password?: string;
  privateKey?: string;
  passphrase?: string;
}

/**
 * Reconnect result
 */
export interface ReconnectResult {
  /** Whether it succeeded */
  success: boolean;
  /** Attempt count */
  attemptCount: number;
  /** Error message (on failure) */
  error?: string;
  /** Whether it was cancelled */
  cancelled?: boolean;
}

/**
 * Reconnect events
 */
export interface ReconnectEvents {
  /** When a reconnect attempt starts */
  onAttemptStart: (attemptNumber: number, maxAttempts: number) => void;
  /** When a reconnect attempt fails */
  onAttemptFailed: (attemptNumber: number, error: string) => void;
  /** When reconnect succeeds */
  onSuccess: () => void;
  /** When reconnect gives up after the maximum attempts */
  onGiveUp: (totalAttempts: number, lastError: string) => void;
  /** When reconnect is cancelled */
  onCancelled: () => void;
}

/**
 * ReconnectService interface
 */
export interface IReconnectService {
  /**
   * Handle a disconnect and decide whether auto-reconnect should start.
   * @param connection The disconnected connection
   * @param state The current connection state
   * @returns true if auto-reconnect was started
   */
  handleDisconnection(connection: Connection, state: ConnectionState): boolean;

  /**
   * Start reconnecting.
   * @param connection The connection to reconnect
   * @param options Options such as credentials
   * @returns Promise for the reconnect result
   */
  startReconnect(connection: Connection, options?: ReconnectOptions): Promise<ReconnectResult>;

  /**
   * Cancel an in-progress reconnect.
   * @param connectionId The connection ID
   */
  cancelReconnect(connectionId: string): void;

  /**
   * Check whether reconnect is in progress.
   * @param connectionId The connection ID
   */
  isReconnecting(connectionId: string): boolean;

  /**
   * Set event handlers.
   * @param connectionId The connection ID
   * @param events Event handlers
   */
  setEventHandlers(connectionId: string, events: Partial<ReconnectEvents>): void;

  /**
   * Remove event handlers.
   * @param connectionId The connection ID
   */
  removeEventHandlers(connectionId: string): void;
}
