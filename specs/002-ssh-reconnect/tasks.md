# Tasks: SSH Reconnection

**Input**: Design documents from `/specs/002-ssh-reconnect/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included (Constitution requires TDD approach)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Prepare type definitions and store extensions

- [x] T001 [P] Add reconnect-related types in `src/types/connection.ts`
  - Add `'reconnecting'` to `ConnectionStatus`
  - Create a new `DisconnectReason` type
  - Add `ReconnectAttempt` and `AttemptResult` interfaces
  - Add reconnect settings fields to `Connection` (`autoReconnect`, `maxReconnectAttempts`, `reconnectInterval`)
  - Add disconnect info fields to `ConnectionState` (`disconnectedAt`, `disconnectReason`, `reconnectAttempt`)
  - Add the `DEFAULT_RECONNECT_SETTINGS` constant

- [x] T002 [P] Add reconnect actions to `connectionStore` in `src/stores/connectionStore.ts`
  - Add `updateReconnectSettings`
  - Add `setDisconnected`
  - Add `setReconnecting`
  - Add `recordReconnectAttempt`
  - Add `clearReconnectState`
  - Update persistence to include reconnect settings

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Foundation for the reconnect service shared by all user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Create tests for ReconnectService in `__tests__/services/ssh/reconnect.test.ts`
  - `handleDisconnection`: returns true when auto-reconnect is enabled
  - `handleDisconnection`: returns false when auto-reconnect is disabled
  - `startReconnect`: returns `success=true` when connection succeeds
  - `startReconnect`: retries when connection fails
  - `startReconnect`: emits the `giveUp` event after the maximum number of attempts
  - `cancelReconnect`: can be cancelled while reconnecting

- [x] T004 Implement ReconnectService in `src/services/ssh/reconnect.ts`
  - Implement the `IReconnectService` interface
  - Implement `handleDisconnection`
  - Implement `startReconnect` with retry logic
  - Implement `cancelReconnect`
  - Manage event handlers
  - Manage timers for retry intervals

- [x] T005 Update SSH service exports in `src/services/ssh/index.ts`
  - Add ReconnectService-related exports

**Checkpoint**: Reconnect service foundation is complete - user story work can begin

---

## Phase 3: User Story 1 - Always Check Connection Status (Priority: P1) 🎯 MVP

**Goal**: Visually confirm connection status on the terminal screen at all times and update immediately when it changes

**Independent Test**: Verify that the connection status indicator appears and changes to `Disconnected` when the SSH client's `onClose` event fires

### Tests for User Story 1

- [x] T006 [P] [US1] Create tests for ConnectionStatusIndicator in `__tests__/components/connection/ConnectionStatusIndicator.test.tsx`
  - Show a green dot in the connected state
  - Show a red dot in the disconnected state
  - Show a spinning animation in the reconnecting state
  - Show details on press

### Implementation for User Story 1

- [x] T007 [P] [US1] Implement ConnectionStatusIndicator in `src/components/connection/ConnectionStatusIndicator.tsx`
  - Show color and icon according to `status`
  - Add animations for pulse and rotation
  - Show details on tap
  - Add size variants (`sm`/`md`/`lg`)

- [x] T008 [US1] Wire SSH client `onClose` handling in `src/services/ssh/client.ts`
  - Call `connectionStore.setDisconnected` when `onClose` fires
  - Add disconnect reason detection logic

- [x] T009 [US1] Update component exports in `src/components/connection/index.ts`
  - Export `ConnectionStatusIndicator`

- [x] T010 [US1] Integrate the indicator into `TerminalHeader` in `src/components/terminal/TerminalHeader.tsx`
  - Place `ConnectionStatusIndicator`
  - Read state from `connectionStore`

**Checkpoint**: Visual connection status display works (US1 complete)

---

## Phase 4: User Story 2 - Reconnect Confirmation on Disconnect (Priority: P2)

**Goal**: Show a reconnect confirmation dialog when SSH disconnects and let the user choose reconnect or cancel

**Independent Test**: Verify that the dialog appears on disconnect and that choosing `Reconnect` restores the connection

### Tests for User Story 2

- [ ] T011 [P] [US2] Create tests for ReconnectDialog in `__tests__/components/connection/ReconnectDialog.test.tsx`
  - Show the dialog when `visible=true`
  - Call `onReconnect` when the `Reconnect` button is pressed
  - Call `onCancel` when the `Cancel` button is pressed
  - Show a spinner while connecting
  - Show a message and retry button on error

### Implementation for User Story 2

- [ ] T012 [P] [US2] Implement ReconnectDialog in `src/components/connection/ReconnectDialog.tsx`
  - Show the overlay with a `Modal` component
  - Manage `confirm` / `connecting` / `password` / `error` / `success` states
  - Add reconnect and cancel buttons
  - Show progress with a spinner
  - Show error messages
  - Show a password input form when credentials are unavailable

- [ ] T013 [US2] Add `ReconnectDialog` export in `src/components/connection/index.ts`
  - Export `ReconnectDialog`

- [ ] T014 [US2] Create the `useReconnectDialog` hook in `src/hooks/useReconnectDialog.ts`
  - Manage dialog visibility state
  - Integrate with `ReconnectService`
  - Execute reconnect handling
  - Retrieve credentials

- [ ] T015 [US2] Use the dialog on the terminal screen in `app/terminal/[id].tsx`
  - Show the dialog when a disconnect is detected
  - Close the dialog when reconnect succeeds
  - Navigate back to the connection list on cancel

- [ ] T016 [US2] Update hook exports in `src/hooks/index.ts`
  - Export `useReconnectDialog`

**Checkpoint**: Manual reconnect flow works (US1 + US2 complete)

---

## Phase 5: User Story 3 - Auto-Reconnect Settings (Priority: P3)

**Goal**: Let each connection enable or disable auto-reconnect, and reconnect automatically without a dialog when enabled

**Independent Test**: Enable auto-reconnect and verify that reconnect starts without a dialog when the connection drops

### Tests for User Story 3

- [ ] T017 [P] [US3] Create tests for auto-reconnect logic in `__tests__/services/ssh/reconnect.test.ts`
  - Start reconnect without a dialog when `autoReconnect=true`
  - Switch to the manual dialog after 3 failures
  - Cancel auto-reconnect through user action

### Implementation for User Story 3

- [ ] T018 [P] [US3] Add auto-reconnect settings to ConnectionForm in `src/components/connection/ConnectionForm.tsx`
  - Auto-reconnect toggle switch
  - Optional maximum attempt count
  - Optional retry interval

- [ ] T019 [US3] Integrate auto-reconnect logic into ReconnectService in `src/services/ssh/reconnect.ts`
  - Decide auto-reconnect inside `handleDisconnection`
  - Switch to the manual dialog after reaching the maximum attempts
  - Connect the attempt count to the indicator

- [ ] T020 [US3] Handle auto-reconnect on the terminal screen in `app/terminal/[id].tsx`
  - Hide the dialog when `autoReconnect=true`
  - Show the dialog after auto-reconnect fails
  - Allow cancel via indicator tap

- [ ] T021 [US3] Add attempt count display to ConnectionStatusIndicator in `src/components/connection/ConnectionStatusIndicator.tsx`
  - Show `Reconnecting (2/3)` when reconnecting
  - Confirm cancel on tap

**Checkpoint**: Auto-reconnect flow works (all user stories complete)

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improve quality and cover edge cases

- [ ] T022 [P] Run type check `pnpm typecheck`
- [ ] T023 [P] Run lint `pnpm lint`
- [ ] T024 [P] Run all tests `pnpm test`
- [ ] T025 Edge case: verify reconnect flow when the password is not saved
- [ ] T026 Edge case: verify behavior when the app moves to the background
- [ ] T027 Verify behavior by following the steps in `quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational) ← BLOCKS all user stories
    ↓
┌───────────────────────────────────────┐
│  Phase 3 (US1) → Phase 4 (US2) → Phase 5 (US3)  │
│  (run sequentially; each story can be tested independently) │
└───────────────────────────────────────┘
    ↓
Phase 6 (Polish)
```

### User Story Dependencies

| Story | Depends On | Independent Test |
|-------|------------|-----------------|
| US1 (P1) | Phase 2 complete | ✅ Can be verified with the indicator alone |
| US2 (P2) | US1 (indicator) | ✅ Can be verified with the dialog alone |
| US3 (P3) | US2 (dialog) | ✅ Can be verified with auto-reconnect alone |

### Parallel Opportunities

**Phase 1 (parallel)**:
- T001: Type definitions
- T002: Store extension

**Phase 3 (parallel)**:
- T006: Test creation
- T007: Component implementation

**Phase 4 (parallel)**:
- T011: Test creation
- T012: Component implementation

**Phase 5 (parallel)**:
- T017: Test creation
- T018: Form extension

**Phase 6 (parallel)**:
- T022, T023, T024: Various checks

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Complete Setup
2. Phase 2: Complete Foundational
3. Phase 3: Complete User Story 1
4. **STOP and VALIDATE**: Verify indicator behavior
5. Demo ready

### Incremental Delivery

1. Setup + Foundational → Foundation complete
2. Add US1 → Indicator works → **MVP!**
3. Add US2 → Manual reconnect works → Release candidate
4. Add US3 → Auto-reconnect works → Full feature set
5. Polish → Quality assurance → Final release

---

## Summary

| Phase | Tasks | Parallel |
|-------|-------|----------|
| Phase 1: Setup | 2 | 2 |
| Phase 2: Foundational | 3 | 0 |
| Phase 3: US1 | 5 | 2 |
| Phase 4: US2 | 6 | 2 |
| Phase 5: US3 | 5 | 2 |
| Phase 6: Polish | 6 | 3 |
| **Total** | **27** | **11** |

**MVP Scope**: Phases 1-3 (through US1, 10 tasks)
