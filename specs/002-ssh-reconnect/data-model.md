# Data Model: SSH Reconnection

**Feature**: 002-ssh-reconnect
**Date**: 2026-01-10

## Entity Relationships

```
┌─────────────────────┐      ┌──────────────────────┐
│     Connection      │ 1  1 │   ReconnectSettings  │
│ (existing entity)     │──────│   (new fields)        │
└─────────────────────┘      └──────────────────────┘
          │ 1
          │
          │ *
┌─────────────────────┐
│   ConnectionState   │
│ (existing, extended)  │
└─────────────────────┘
          │ 1
          │
          │ 0..1
┌─────────────────────┐
│  ReconnectAttempt   │
│ (new, runtime)        │
└─────────────────────┘
```

## Entities

### Connection (existing entity - extended)

Defined in `src/types/connection.ts`. Add reconnect settings fields.

```typescript
interface Connection {
  // Existing fields
  id: string;
  name: string;
  host: string;
  port: number;
  username: string;
  authMethod: 'password' | 'key';
  keyId?: string;
  timeout: number;
  keepAliveInterval: number;
  icon?: string;
  color?: string;
  tags?: string[];
  lastConnected?: number;
  createdAt: number;
  updatedAt: number;

  // New: reconnect settings
  autoReconnect: boolean;           // Auto-reconnect enabled flag (default: true)
  maxReconnectAttempts: number;     // Maximum attempt count (default: 3)
  reconnectInterval: number;        // Retry interval in ms (default: 5000)
}
```

**Validation Rules**:
- `autoReconnect`: boolean, default `true`
- `maxReconnectAttempts`: integer from 1 to 10, default `3`
- `reconnectInterval`: integer from 1000 to 30000 ms, default `5000`

**State Transitions**: N/A (settings are static)

---

### ConnectionState (existing entity - extended)

Defined in `src/types/connection.ts`. Extend the status values and details.

```typescript
interface ConnectionState {
  // Existing fields
  connectionId: string;
  status: ConnectionStatus;   // Extended with 'reconnecting'
  error?: string;
  latency?: number;
  connectedAt?: number;

  // New fields
  disconnectedAt?: number;     // Disconnect time (Unix timestamp ms)
  disconnectReason?: DisconnectReason;  // Disconnect reason
  reconnectAttempt?: ReconnectAttempt;  // Current reconnect attempt info
}

type ConnectionStatus =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'reconnecting'  // New
  | 'error';

type DisconnectReason =
  | 'network_error'      // Network failure
  | 'server_closed'      // Server-side disconnect
  | 'auth_failed'        // Authentication failure
  | 'timeout'            // Timeout
  | 'user_disconnect'    // User-initiated disconnect
  | 'unknown';           // Unknown
```

**Validation Rules**:
- `disconnectedAt`: Set only when `status === 'disconnected'` or `status === 'reconnecting'`
- `disconnectReason`: Valid only when `disconnectedAt` is set
- `reconnectAttempt`: Set only when `status === 'reconnecting'`

**State Transitions**:
```
connected → disconnected (disconnect detected)
disconnected → connecting (manual reconnect started)
disconnected → reconnecting (auto reconnect started)
reconnecting → connected (reconnect successful)
reconnecting → disconnected (reconnect abandoned/cancelled)
reconnecting → error (fatal error)
error → connecting (retry)
```

---

### ReconnectAttempt (new entity - runtime)

Tracks reconnect attempt state. Not persisted.

```typescript
interface ReconnectAttempt {
  /** Attempt start time (Unix timestamp ms) */
  startedAt: number;

  /** Current attempt number (starts at 1) */
  attemptNumber: number;

  /** Maximum attempts (copied from `Connection.maxReconnectAttempts`) */
  maxAttempts: number;

  /** Next scheduled attempt time (Unix timestamp ms, only while waiting) */
  nextAttemptAt?: number;

  /** History of each attempt result */
  history: AttemptResult[];
}

interface AttemptResult {
  /** Attempt number */
  attemptNumber: number;

  /** Attempt time */
  attemptedAt: number;

  /** Result */
  result: 'success' | 'failed' | 'cancelled';

  /** Failure reason (when `result === 'failed'`) */
  error?: string;
}
```

**Validation Rules**:
- `attemptNumber`: At least 1 and no greater than `maxAttempts`
- `history.length`: Matches `attemptNumber` after each attempt
- `nextAttemptAt`: Must be in the future

**State Transitions**:
```
null → ReconnectAttempt (reconnect started)
attemptNumber++ (move to the next attempt)
ReconnectAttempt → null (success / give up / cancel)
```

## Default Values

```typescript
const DEFAULT_RECONNECT_SETTINGS = {
  autoReconnect: true,
  maxReconnectAttempts: 3,
  reconnectInterval: 5000,  // 5 seconds
};
```

## Storage

| Entity | Storage | Persistence |
|--------|---------|-------------|
| Connection (including reconnect settings) | AsyncStorage | ✅ Persistent |
| ConnectionState | Zustand (memory) | ❌ Runtime only |
| ReconnectAttempt | Zustand (memory) | ❌ Runtime only |

## Migration

Added fields on the existing `Connection` entity are merged automatically by Zustand's persist middleware. Use default values when new fields are missing.

```typescript
// Apply defaults during initialization in connectionStore.ts
const normalizeConnection = (conn: Partial<Connection>): Connection => ({
  ...DEFAULT_CONNECTION,
  ...DEFAULT_RECONNECT_SETTINGS,
  ...conn,
});
```
