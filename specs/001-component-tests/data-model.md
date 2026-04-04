# Data Model: Component Tests

**Date**: 2026-01-10
**Branch**: `001-component-tests`

## Overview

Define the structure of the test fixtures (mock data) used by the component tests.

---

## Test Fixtures

### ConnectionCard Fixtures

#### mockConnection
```typescript
interface Connection {
  id: string;                    // UUID
  name: string;                  // display name
  host: string;                  // host name
  port: number;                  // port number
  username: string;              // user name
  authMethod: 'password' | 'key'; // authentication method
  timeout: number;               // timeout in seconds
  keepAliveInterval: number;     // keep-alive interval
  createdAt: number;             // creation time
  updatedAt: number;             // update time
}
```

#### mockConnectionState
```typescript
interface ConnectionState {
  connectionId: string;
  status: 'disconnected' | 'connecting' | 'connected' | 'error';
  error?: string;
  latency?: number;
  connectedAt?: number;
}
```

---

### TerminalView Fixtures

#### mockAnsiLine
```typescript
interface AnsiLine {
  spans: AnsiSpan[];
}

interface AnsiSpan {
  text: string;
  fg?: number;          // foreground color (0-255)
  bg?: number;          // background color (0-255)
  bold?: boolean;
  dim?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  inverse?: boolean;
  hidden?: boolean;
}
```

#### mockTerminalTheme
```typescript
interface TerminalTheme {
  background: string;
  foreground: string;
  cursor: string;
  selection: string;
  palette: readonly string[]; // 16 colors
}
```

---

### SessionTabs Fixtures

#### mockTmuxSession
```typescript
interface TmuxSession {
  name: string;
  created: number;
  attached: boolean;
  windowCount: number;
  windows: TmuxWindow[];
}

interface TmuxWindow {
  index: number;
  name: string;
  active: boolean;
  paneCount: number;
  panes: TmuxPane[];
}
```

---

### SpecialKeys Fixtures

#### mockCallbacks
```typescript
interface SpecialKeysCallbacks {
  onSendKeys: jest.Mock;
  onSendSpecialKey: jest.Mock;
  onSendCtrl: jest.Mock;
}
```

---

## Fixture Factories

Factory function patterns for tests, implemented as needed:

```typescript
// Create a basic Connection
function createMockConnection(overrides?: Partial<Connection>): Connection

// Create a connected state
function createConnectedState(connectionId: string): ConnectionState

// Create an error state
function createErrorState(connectionId: string, error: string): ConnectionState

// Create ANSI-styled text
function createStyledSpan(text: string, style: Partial<AnsiSpan>): AnsiSpan
```

---

## State Transitions

### ConnectionCard State Flow
```
Initial → onPress → Expanded (if sessions exist)
Expanded → onPress → Collapsed
Expanded → onSelectSession → Callback invoked
```

### SpecialKeys Mode Flow
```
Normal → CTRL press → CTRL Mode
CTRL Mode → Literal key press → Normal (callback with Ctrl+key)
CTRL Mode → CTRL press → Normal
Normal → ALT press → ALT Mode
ALT Mode → ALT press → Normal
```

---

## Notes

- The actual type definitions live in `src/types/`, and the tests should import and use them
- Mock data is defined inline in each test file during the initial phase
- If duplication appears, consider extracting it to `__tests__/fixtures/`
