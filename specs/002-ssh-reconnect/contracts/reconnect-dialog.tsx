/**
 * ReconnectDialog Contract
 *
 * Interface definition for the reconnect confirmation dialog.
 * Implementation goes in src/components/connection/ReconnectDialog.tsx.
 */

import type { Connection, ConnectionState } from '@/types/connection';

/**
 * Dialog state
 */
export type DialogState =
  | 'confirm'      // Waiting for reconnect confirmation
  | 'connecting'   // Connecting
  | 'password'     // Waiting for password input
  | 'error'        // Error display
  | 'success';     // Success (before auto-close)

/**
 * Props for ReconnectDialog
 */
export interface ReconnectDialogProps {
  /** Whether it is visible */
  visible: boolean;

  /** Connection to reconnect */
  connection: Connection;

  /** Connection state */
  connectionState: ConnectionState;

  /** When the reconnect button is pressed */
  onReconnect: (password?: string) => void;

  /** When the cancel button is pressed */
  onCancel: () => void;

  /** Close the dialog (background tap, etc.) */
  onDismiss: () => void;

  /** When the retry button is pressed from the error state */
  onRetry?: () => void;
}

/**
 * Internal state used by the dialog
 */
export interface DialogInternalState {
  /** Current dialog state */
  state: DialogState;

  /** Error message (when `state === 'error'`) */
  errorMessage?: string;

  /** Attempt display (when `state === 'connecting'`) */
  attemptInfo?: {
    current: number;
    max: number;
  };

  /** Entered password (when `state === 'password'`) */
  passwordInput?: string;
}

/**
 * Expected behavior
 *
 * 1. Display when `visible=true`
 * 2. If `connection.autoReconnect=false`, start from the `confirm` state
 * 3. `Reconnect` button -> calls `onReconnect()`
 * 4. `Cancel` button -> calls `onCancel()`
 * 5. Show a spinner in the `connecting` state
 * 6. Show text input in the `password` state when needed
 * 7. Show a message in the `error` state
 * 8. Close automatically on success (or pass through the `success` state)
 */
