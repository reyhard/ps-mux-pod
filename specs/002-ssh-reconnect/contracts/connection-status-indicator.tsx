/**
 * ConnectionStatusIndicator Contract
 *
 * Interface definition for the connection status indicator.
 * Implementation goes in src/components/connection/ConnectionStatusIndicator.tsx.
 */

import type { ConnectionState } from '@/types/connection';

/**
 * Indicator sizes
 */
export type IndicatorSize = 'sm' | 'md' | 'lg';

/**
 * Props for ConnectionStatusIndicator
 */
export interface ConnectionStatusIndicatorProps {
  /** Connection state */
  state: ConnectionState;

  /** Size (default: 'md') */
  size?: IndicatorSize;

  /** Tap callback */
  onPress?: () => void;

  /** Whether to show details (default: false) */
  showDetails?: boolean;

  /** Whether to enable animation (default: true) */
  animated?: boolean;
}

/**
 * Display spec by state
 */
export const STATUS_DISPLAY = {
  connected: {
    color: '#22c55e',  // colors.success
    icon: 'circle',    // filled circle
    label: 'Connected',
    animated: false,
  },
  connecting: {
    color: '#eab308',  // colors.warning
    icon: 'circle-outline',
    label: 'Connecting...',
    animated: true,    // Pulse animation
  },
  reconnecting: {
    color: '#eab308',  // colors.warning
    icon: 'refresh',   // Rotating arrow
    label: 'Reconnecting...',
    animated: true,    // Rotation animation
  },
  disconnected: {
    color: '#ef4444',  // colors.error
    icon: 'circle',
    label: 'Disconnected',
    animated: false,
  },
  error: {
    color: '#ef4444',  // colors.error
    icon: 'alert',
    label: 'Error',
    animated: false,
  },
} as const;

/**
 * Dimensions by size
 */
export const SIZE_SPECS = {
  sm: {
    iconSize: 12,
    fontSize: 10,
    padding: 4,
  },
  md: {
    iconSize: 16,
    fontSize: 12,
    padding: 8,
  },
  lg: {
    iconSize: 20,
    fontSize: 14,
    padding: 12,
  },
} as const;

/**
 * Expected behavior
 *
 * 1. Show color, icon, and label based on `state.status`
 * 2. If `onPress` is provided, make it look tappable
 * 3. If `showDetails=true`, show extra info such as disconnect time and error details
 * 4. If reconnecting and `attemptInfo` exists, show something like `Reconnecting (2/3)`
 * 5. If `animated=true`, apply animations according to the state
 */
