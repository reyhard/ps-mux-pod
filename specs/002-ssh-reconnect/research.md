# Research: SSH Reconnection

**Feature**: 002-ssh-reconnect
**Date**: 2026-01-10

## 1. SSH Disconnect Detection

### Decision
Use the `Disconnect` event from `react-native-ssh-sftp` together with the existing keep-alive behavior to detect disconnects.

### Rationale
- The existing `SSHClient` class already supports an `onClose` event handler (`client.ts:39`)
- `startShell` already listens for the `Disconnect` event (`client.ts:186-187`)
- No extra polling is needed, so detection can be immediate and event-driven

### Alternatives Considered
1. **Periodic ping commands**: Adds overhead and increases battery usage
2. **Monitoring TCP connection state**: Low-level APIs are limited in React Native
3. **Keep-alive timeout only**: Already configurable via `connection.keepAliveInterval`, but not enough for immediate detection

## 2. Reconnect Dialog Pattern

### Decision
Use React Native's `Modal` component and show it when `connectionStore` state changes.

### Rationale
- The existing `ConnectionErrorScreen.tsx` establishes an error-display pattern
- Zustand `connectionStates` makes the state reactive
- A modal can overlay the current screen without navigation and preserve the user's context

### Alternatives Considered
1. **`Alert.alert()`**: Too little customization and cannot show progress
2. **Full-screen navigation**: Makes returning to the original screen after reconnect more complex
3. **Toast notifications only**: Not appropriate when user action is required

## 3. Auto-Reconnect Strategy

### Decision
Create a new `ReconnectService` class and keep retry logic separate from `connectionStore`.

### Rationale
- Single Responsibility Principle: `connectionStore` should focus on connection state
- Testability: reconnect logic can be unit-tested independently
- Flexibility: different reconnect policies can be applied per connection

### Implementation Details
```
Reconnect flow:
1. Disconnect detected -> `connectionStore.setConnectionState(id, { status: 'disconnected' })`
2. ReconnectService.handleDisconnection(connectionId)
3. Auto-reconnect enabled? -> start reconnect immediately
4. Auto-reconnect disabled? -> show `ReconnectDialog`
5. Reconnect attempt -> show `status: 'reconnecting'` and attempt count
6. Success -> `status: 'connected'`, close the dialog
7. Failure before max attempts -> retry after the interval
8. Failure after max attempts -> switch to the manual confirmation dialog
```

### Retry Policy
- Maximum attempts: 3 by default, configurable in connection settings
- Retry interval: 5 seconds, fixed; exponential backoff is not part of the initial implementation
- Cancellable: the user can stop reconnect at any time

## 4. Connection Status Indicator Design

### Decision
Create a `ConnectionStatusIndicator` component and integrate it into `TerminalHeader`.

### Rationale
- `TerminalHeader.tsx` already owns the header area
- `ConnectionCard`'s `ServerIcon` established the status display pattern (`ConnectionCard.tsx:38-74`)
- The component should be reusable

### Visual States
| State | Color | Icon | Animation |
|------|-----|---------|---------------|
| connected | green (#22c55e) | ● (dot) | none |
| connecting | yellow (#eab308) | ○ (ring) | pulse |
| reconnecting | yellow (#eab308) | ↻ (arrow) | rotation |
| disconnected | red (#ef4444) | ● (dot) | none |
| error | red (#ef4444) | ⚠ (warning) | none |

## 5. Credential Retrieval

### Decision
Retrieve credentials from `expo-secure-store` during reconnect, and show a password dialog when nothing is stored.

### Rationale
- Existing `auth.ts` already provides credential retrieval logic
- This follows the security principle that credentials must be stored encrypted
- We must handle cases where the password was not saved

### Flow
1. Call `getStoredCredentials(connectionId)` when reconnect starts
2. If credentials exist -> try to reconnect
3. If credentials do not exist -> show `PasswordInputDialog`
4. After user input -> retry reconnect, optionally saving the credential

## 6. Background Handling

### Decision
Prioritize reconnect while foregrounded, and continue reconnecting in the background while notifying the user locally on success or failure.

### Rationale
- Mobile OS background limits apply (iOS: 30 seconds, Android: 10 minutes)
- The spec already says foreground reconnect takes priority
- Full background support is out of scope for now

### Implementation
- Use `AppState` listeners to track foreground/background transitions
- When moving to background: keep the reconnect timer running and cache the result
- When returning to foreground: apply the cached result to the UI

## 7. Test Strategy

### Decision
Unit test disconnect detection and reconnect logic with mocks, and run E2E tests manually.

### Test Cases
1. **Disconnect detection**: state changes to `disconnected` when `onClose` fires
2. **Auto reconnect**: transitions to `reconnecting` when enabled
3. **Manual reconnect**: dialog display and option handling
4. **Max attempts**: switch to manual confirmation after 3 failed attempts
5. **Cancel**: cancel while reconnecting
6. **No credentials**: show the password dialog

### Mocking Strategy
- `SSHClient`: `jest.mock('react-native-ssh-sftp')`
- `expo-secure-store`: `jest.mock('expo-secure-store')`
- Timers: `jest.useFakeTimers()`
