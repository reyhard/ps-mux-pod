# Quickstart: SSH Reconnection

**Feature**: 002-ssh-reconnect
**Date**: 2026-01-10

## Overview

Implement a feature that helps users quickly understand when an SSH connection drops and reconnect smoothly.

## Key Components

### 1. ReconnectService (`src/services/ssh/reconnect.ts`)

Service that manages reconnect logic.

```typescript
import { createReconnectService } from '@/services/ssh/reconnect';

const reconnectService = createReconnectService();

// Called when a disconnect is detected
reconnectService.handleDisconnection(connection, state);

// Start reconnect manually
await reconnectService.startReconnect(connection, { password: '...' });

// Cancel reconnect
reconnectService.cancelReconnect(connectionId);
```

### 2. ReconnectDialog (`src/components/connection/ReconnectDialog.tsx`)

Reconnect confirmation dialog.

```tsx
import { ReconnectDialog } from '@/components/connection';

<ReconnectDialog
  visible={showDialog}
  connection={connection}
  connectionState={state}
  onReconnect={(password) => handleReconnect(password)}
  onCancel={() => navigateToConnections()}
  onDismiss={() => setShowDialog(false)}
/>
```

### 3. ConnectionStatusIndicator (`src/components/connection/ConnectionStatusIndicator.tsx`)

Indicator that visually shows connection state.

```tsx
import { ConnectionStatusIndicator } from '@/components/connection';

<ConnectionStatusIndicator
  state={connectionState}
  size="md"
  onPress={() => showStatusDetails()}
  animated
/>
```

## State Management

### Extend `connectionStore`

```typescript
// Update reconnect settings
useConnectionStore.getState().updateReconnectSettings(id, {
  autoReconnect: true,
  maxReconnectAttempts: 3,
  reconnectInterval: 5000,
});

// Mark as disconnected
useConnectionStore.getState().setDisconnected(id, 'network_error');

// Mark as reconnecting
useConnectionStore.getState().setReconnecting(id, 1, 3);
```

## Implementation Steps

### Step 1: Extend type definitions

Add reconnect-related types to `src/types/connection.ts`:

```typescript
// Add to Connection
autoReconnect: boolean;
maxReconnectAttempts: number;
reconnectInterval: number;

// Add to ConnectionState
disconnectedAt?: number;
disconnectReason?: DisconnectReason;
reconnectAttempt?: ReconnectAttempt;

// New types
type ConnectionStatus = 'disconnected' | 'connecting' | 'connected' | 'reconnecting' | 'error';
type DisconnectReason = 'network_error' | 'server_closed' | 'auth_failed' | 'timeout' | 'user_disconnect' | 'unknown';

interface ReconnectAttempt {
  startedAt: number;
  attemptNumber: number;
  maxAttempts: number;
  nextAttemptAt?: number;
  history: AttemptResult[];
}
```

### Step 2: Implement `ReconnectService`

1. Create `src/services/ssh/reconnect.ts`
2. Implement the `IReconnectService` interface
3. Hook into the SSH client's `onClose` event
4. Implement retry logic with timer management

### Step 3: Extend `connectionStore`

1. Add reconnect-related actions
2. Add selectors
3. Update persistence so reconnect settings are stored in AsyncStorage

### Step 4: Implement UI components

1. Create `ConnectionStatusIndicator.tsx`
2. Create `ReconnectDialog.tsx`
3. Integrate the indicator into `TerminalHeader.tsx`
4. Add logic to show the dialog from the terminal screen

### Step 5: Write tests

1. Unit tests for `ReconnectService`
2. Reconnect action tests for `connectionStore`
3. Component snapshot tests

## File Structure

```
src/
├── components/
│   └── connection/
│       ├── ConnectionStatusIndicator.tsx  # New
│       ├── ReconnectDialog.tsx            # New
│       └── index.ts                        # Updated
├── services/
│   └── ssh/
│       ├── reconnect.ts                   # New
│       └── index.ts                        # Updated
├── stores/
│   └── connectionStore.ts                 # Updated
└── types/
    └── connection.ts                      # Updated
```

## Test Run

```bash
# Unit tests
pnpm test src/services/ssh/reconnect.test.ts
pnpm test src/stores/connectionStore.test.ts

# Type check
pnpm typecheck

# Lint
pnpm lint
```

## Notes

- Retrieve credentials from secure storage; never store them in plain text
- Prefer foreground processing for reconnect
- After the maximum number of attempts, switch to manual confirmation
