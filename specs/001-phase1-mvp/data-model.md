# Data Model: MuxPod Phase 1 MVP

**Feature**: 001-phase1-mvp
**Date**: 2026-01-10

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Persistence Layer                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐                                                 │
│  │ Connection  │ ──────────────────────────────────────────────┐ │
│  │ (AsyncStorage)                                              │ │
│  └──────┬──────┘                                               │ │
│         │                                                       │ │
│         │ has password (optional)                               │ │
│         ▼                                                       │ │
│  ┌─────────────┐                                               │ │
│  │  Password   │                                               │ │
│  │ (SecureStore)                                               │ │
│  └─────────────┘                                               │ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         Runtime Layer                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐       ┌─────────────┐                          │
│  │ Connection  │ 1───* │ TmuxSession │                          │
│  │   State     │       └──────┬──────┘                          │
│  └─────────────┘              │                                  │
│                                │ 1                               │
│                                ▼ *                               │
│                         ┌─────────────┐                          │
│                         │ TmuxWindow  │                          │
│                         └──────┬──────┘                          │
│                                │ 1                               │
│                                ▼ *                               │
│                         ┌─────────────┐       ┌─────────────┐   │
│                         │  TmuxPane   │ 1───1 │ PaneContent │   │
│                         └─────────────┘       └─────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Entities

### Connection (persistence)

SSH connection settings。AsyncStoragesave。

```typescript
interface Connection {
  id: string;                      // UUID v4
  name: string;                    // display (e.g., "Production Server")
  host: string;                    // host name or IP
  port: number;                    // SSHport (default: 22)
  username: string;                // SSHuser
  authMethod: 'password' | 'key';  // authentication
  keyId?: string;                  // SSHkeyID (keyauthentication)
  timeout: number;                 // connection (default: 30)
  keepAliveInterval: number;       // Keepalive (default: 60)

  // information
  icon?: string;                   // custom
  color?: string;                  // color (#RRGGBB)
  tags?: string[];                 // 
  lastConnected?: number;          // finalconnection (Unix timestamp ms)
  createdAt: number;               // create (Unix timestamp ms)
  updatedAt: number;               // update (Unix timestamp ms)
}
```

**Validation Rules**:
- `id`: required、UUID v4format
- `name`: required、1-50characters
- `host`: required、enabledhost nameIP
- `port`: required、1-65535count
- `username`: required、1-32characters
- `authMethod`: required、'password' | 'key'
- `timeout`: 1-300count
- `keepAliveInterval`: 0-300count (0 = disabled)

**Storage Key**: `muxpod-connections`

---

### ConnectionState ()

connectionstate。persistence。

```typescript
interface ConnectionState {
  connectionId: string;
  status: 'disconnected' | 'connecting' | 'connected' | 'error';
  error?: string;                  // errormessage
  latency?: number;                // RTT (ms)
  connectedAt?: number;            // connectionstart
}
```

**State Transitions**:
```
disconnected ──connect()──> connecting ──success──> connected
                              │                        │
                              └──failure──> error      │
                                              │        │
connected ──disconnect()──> disconnected <────┘        │
                  ▲                                    │
                  └────────network error───────────────┘
```

---

### TmuxSession ()

tmux session。SSHretrieve。

```typescript
interface TmuxSession {
  name: string;                    // session (unique per server)
  created: number;                 // create (Unix timestamp ms)
  attached: boolean;               // clientattachin progress
  windowCount: number;             // windowcount
  windows: TmuxWindow[];           // window (lazy load)
}
```

**Source**: `tmux list-sessions -F "#{session_name}\t#{session_created}\t#{session_attached}\t#{session_windows}"`

---

### TmuxWindow ()

tmux window。

```typescript
interface TmuxWindow {
  index: number;                   // window (0-based)
  name: string;                    // window
  active: boolean;                 // activewindow
  paneCount: number;               // panecount
  panes: TmuxPane[];               // pane (lazy load)
}
```

**Source**: `tmux list-windows -t {session} -F "#{window_index}\t#{window_name}\t#{window_active}\t#{window_panes}"`

---

### TmuxPane ()

tmux pane。

```typescript
interface TmuxPane {
  index: number;                   // pane (0-based)
  id: string;                      // paneID (%0, %1, etc.)
  active: boolean;                 // activepane
  currentCommand: string;          // currentrunin progresscommand
  title: string;                   // pane
  width: number;                   // width（count）
  height: number;                  // height（rows）
  cursorX: number;                 // X
  cursorY: number;                 // Y
}
```

**Source**: `tmux list-panes -t {session}:{window} -F "#{pane_index}\t#{pane_id}\t#{pane_active}\t#{pane_current_command}\t#{pane_title}\t#{pane_width}\t#{pane_height}\t#{cursor_x}\t#{cursor_y}"`

---

### PaneContent ()

panedisplaycontents。pollingupdate。

```typescript
interface PaneContent {
  paneId: string;                  // supportpaneID
  lines: AnsiLine[];               // linecontents（parse）
  scrollbackSize: number;          // scrollbackrows
  cursorX: number;                 // X
  cursorY: number;                 // Y
  lastUpdated: number;             // finalupdate
}

interface AnsiLine {
  spans: AnsiSpan[];               // same
}

interface AnsiSpan {
  text: string;                    // contents
  fg?: number;                     // color (0-255, undefined=default)
  bg?: number;                     // color (0-255, undefined=default)
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
}
```

**Source**: `tmux capture-pane -t {session}:{window}.{pane} -p -e -S -1000`

---

## Store Structure

### connectionStore

```typescript
interface ConnectionStore {
  // Persisted
  connections: Connection[];

  // Runtime (not persisted)
  connectionStates: Map<string, ConnectionState>;
  activeConnectionId: string | null;

  // Actions
  addConnection: (conn: Omit<Connection, 'id' | 'createdAt' | 'updatedAt'>) => string;
  updateConnection: (id: string, updates: Partial<Connection>) => void;
  removeConnection: (id: string) => void;
  setConnectionState: (id: string, state: Partial<ConnectionState>) => void;
  setActiveConnection: (id: string | null) => void;
  getConnection: (id: string) => Connection | undefined;
}
```

### sessionStore

```typescript
interface SessionStore {
  // Runtime only
  sessions: Map<string, TmuxSession[]>;  // connectionId -> sessions
  selectedSession: string | null;        // session name
  selectedWindow: number | null;         // window index
  selectedPane: number | null;           // pane index

  // Actions
  setSessions: (connectionId: string, sessions: TmuxSession[]) => void;
  selectSession: (name: string) => void;
  selectWindow: (index: number) => void;
  selectPane: (index: number) => void;
  clearSelection: () => void;
}
```

### terminalStore

```typescript
interface TerminalStore {
  // Runtime only
  paneContents: Map<string, PaneContent>;  // paneId -> content

  // Actions
  setContent: (paneId: string, content: PaneContent) => void;
  appendLine: (paneId: string, line: AnsiLine) => void;
  clearContent: (paneId: string) => void;
}
```

---

## Data Flow

### connection

```
1. User taps connection card
   ↓
2. connectionStore.setConnectionState(id, { status: 'connecting' })
   ↓
3. Load password from SecureStore (if authMethod === 'password')
   ↓
4. SSHClient.connect(connection, password)
   ↓
5. On success:
   - connectionStore.setConnectionState(id, { status: 'connected' })
   - connectionStore.setActiveConnection(id)
   - Navigate to terminal screen
   ↓
6. TmuxCommands.listSessions()
   ↓
7. sessionStore.setSessions(connectionId, sessions)
```

### terminalupdate

```
1. useTerminal hook starts polling (100ms interval)
   ↓
2. TmuxCommands.capturePane(session, window, pane, { escape: true })
   ↓
3. AnsiParser.parse(rawOutput)
   ↓
4. Compare with previous content
   ↓
5. If changed:
   - terminalStore.setContent(paneId, newContent)
   - Component re-renders via Zustand subscription
```

---

## Indexes and Lookups

| Entity | Lookup | Key |
|--------|--------|-----|
| Connection | By ID | `id` (Map key) |
| Connection | By host | Linear search (small dataset) |
| ConnectionState | By connection ID | `connectionId` (Map key) |
| TmuxSession | By name | `name` (within connection's sessions) |
| TmuxWindow | By index | `index` (within session's windows) |
| TmuxPane | By index | `index` (within window's panes) |
| PaneContent | By pane ID | `paneId` (Map key) |



