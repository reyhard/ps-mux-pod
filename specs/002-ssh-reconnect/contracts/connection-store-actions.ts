/**
 * ConnectionStore Actions Contract
 *
 * Definitions for reconnect-related actions added to connectionStore.
 * Implementation goes in src/stores/connectionStore.ts.
 */

import type { Connection, ConnectionState } from '@/types/connection';

/**
 * Reconnect-related actions (added to the existing ConnectionStoreActions)
 */
export interface ReconnectStoreActions {
  /**
   * Update reconnect settings for a connection.
   * @param id Connection ID
   * @param settings Reconnect settings
   */
  updateReconnectSettings: (
    id: string,
    settings: Partial<{
      autoReconnect: boolean;
      maxReconnectAttempts: number;
      reconnectInterval: number;
    }>
  ) => void;

  /**
   * Update to disconnected state and record the reason and time.
   * @param id Connection ID
   * @param reason Disconnect reason
   */
  setDisconnected: (
    id: string,
    reason: 'network_error' | 'server_closed' | 'auth_failed' | 'timeout' | 'user_disconnect' | 'unknown'
  ) => void;

  /**
   * Update to reconnecting state.
   * @param id Connection ID
   * @param attemptNumber Current attempt number
   * @param maxAttempts Maximum attempt count
   */
  setReconnecting: (id: string, attemptNumber: number, maxAttempts: number) => void;

  /**
   * Record a reconnect attempt result.
   * @param id Connection ID
   * @param result Attempt result
   */
  recordReconnectAttempt: (
    id: string,
    result: {
      attemptNumber: number;
      result: 'success' | 'failed' | 'cancelled';
      error?: string;
    }
  ) => void;

  /**
   * Clear reconnect state after success, give up, or cancel.
   * @param id Connection ID
   */
  clearReconnectState: (id: string) => void;
}

/**
 * Extended selectors
 */
export interface ReconnectSelectors {
  /**
   * Get whether auto-reconnect is enabled.
   * @param connectionId Connection ID
   */
  selectAutoReconnect: (connectionId: string) => boolean;

  /**
   * Get reconnect attempt information.
   * @param connectionId Connection ID
   */
  selectReconnectAttempt: (connectionId: string) => {
    current: number;
    max: number;
    nextAttemptAt?: number;
  } | null;

  /**
   * Get the disconnect reason.
   * @param connectionId Connection ID
   */
  selectDisconnectReason: (connectionId: string) => string | null;
}

/**
 * Expected behavior
 *
 * 1. setDisconnected: status='disconnected', disconnectedAt=now, disconnectReason=reason
 * 2. setReconnecting: status='reconnecting', initialize reconnectAttempt
 * 3. recordReconnectAttempt: append to reconnectAttempt.history
 * 4. clearReconnectState: clear reconnectAttempt while keeping status
 * 5. All updates modify the relevant entry in connectionStates
 */
