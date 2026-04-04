# Tasks: MuxPod Phase 1 MVP

**Input**: Design documents from `/specs/001-phase1-mvp/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

## Path Conventions

- **Mobile (Expo)**: `app/` (screens), `src/` (business logic), `__tests__/` (tests)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Expo/React Native structure

- [ ] T001 Initialize Expo project with TypeScript template and pnpm
- [ ] T002 [P] Configure tsconfig.json with strict mode and path aliases
- [ ] T003 [P] Configure ESLint and Prettier for TypeScript/React Native
- [ ] T004 [P] Install core dependencies (zustand, react-native-ssh-sftp, expo-secure-store, async-storage)
- [ ] T005 [P] Setup Jest with React Native Testing Library
- [ ] T006 Create base directory structure per plan.md (app/, src/components, src/hooks, src/stores, src/services, src/types)
- [ ] T007 [P] Add monospace fonts to assets/fonts/ (JetBrainsMono, HackGen)
- [ ] T008 Configure app.json with app name, bundleId, and permissions

**Checkpoint**: Project structure ready, dependencies installed, build passes

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T009 [P] Create Connection type definition in src/types/connection.ts
- [ ] T010 [P] Create ConnectionState type definition in src/types/connection.ts
- [ ] T011 [P] Create TmuxSession, TmuxWindow, TmuxPane types in src/types/tmux.ts
- [ ] T012 [P] Create PaneContent, AnsiLine, AnsiSpan types in src/types/terminal.ts
- [ ] T013 Setup Expo Router with app/_layout.tsx (root layout with providers)
- [ ] T014 Create navigation structure: app/(main)/_layout.tsx for authenticated routes

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Establish SSH Connection (Priority: P1) 🎯 MVP Core

**Goal**: The user can establish an SSH connection and connect to the server

**Independent Test**: Enter server information and a password, connect, and verify that the session list is displayed

### Tests for User Story 1

- [ ] T015 [P] [US1] Unit test for SSHClient in __tests__/services/ssh/client.test.ts
- [ ] T016 [P] [US1] Unit test for auth helpers in __tests__/services/ssh/auth.test.ts

### Implementation for User Story 1

- [ ] T017 [P] [US1] Implement SSHClient class in src/services/ssh/client.ts
- [ ] T018 [P] [US1] Implement auth helpers (password, key loading) in src/services/ssh/auth.ts
- [ ] T019 [US1] Create connectionStore with Zustand in src/stores/connectionStore.ts
- [ ] T020 [US1] Implement useSSH hook in src/hooks/useSSH.ts
- [ ] T021 [US1] Add SecureStore integration for password storage in src/services/ssh/auth.ts
- [ ] T022 [US1] Add connection state management (connecting, connected, error) in connectionStore

**Checkpoint**: SSH connection can be established. The user can connect to the server with password authentication and disconnect

---

## Phase 4: User Story 2 - Connection Management (Priority: P1) 🎯 MVP Core

**Goal**: The user can add, edit, delete, and persist connection settings

**Independent Test**: Add a connection, restart the app, verify the connection remains, and confirm edit/delete also work

### Tests for User Story 2

- [ ] T023 [P] [US2] Unit test for connectionStore persistence in __tests__/stores/connectionStore.test.ts
- [ ] T024 [P] [US2] Component test for ConnectionCard in __tests__/components/connection/ConnectionCard.test.tsx

### Implementation for User Story 2

- [ ] T025 [P] [US2] Add AsyncStorage persistence to connectionStore in src/stores/connectionStore.ts
- [ ] T026 [P] [US2] Create ConnectionCard component in src/components/connection/ConnectionCard.tsx
- [ ] T027 [P] [US2] Create ConnectionList component in src/components/connection/ConnectionList.tsx
- [ ] T028 [US2] Create connection list screen in app/index.tsx
- [ ] T029 [US2] Create add connection screen in app/connection/add.tsx
- [ ] T030 [US2] Create edit connection screen in app/connection/[id]/edit.tsx
- [ ] T031 [US2] Add connection form validation (host, port, username required)
- [ ] T032 [US2] Add long-press context menu for edit/delete actions
- [ ] T033 [US2] Add delete confirmation dialog

**Checkpoint**: Full CRUD for connection settings works and persists after app restart

---

## Phase 5: User Story 3 - tmux Navigation (Priority: P2)

**Goal**: The user can navigate the session -> window -> pane hierarchy

**Independent Test**: After connecting, the user can display the session list, select a window, and select a pane

### Tests for User Story 3

- [ ] T034 [P] [US3] Unit test for TmuxCommands in __tests__/services/tmux/commands.test.ts
- [ ] T035 [P] [US3] Unit test for tmux output parser in __tests__/services/tmux/parser.test.ts

### Implementation for User Story 3

- [ ] T036 [P] [US3] Implement TmuxCommands class in src/services/tmux/commands.ts
- [ ] T037 [P] [US3] Implement tmux output parser in src/services/tmux/parser.ts
- [ ] T038 [US3] Create sessionStore with Zustand in src/stores/sessionStore.ts
- [ ] T039 [US3] Implement useTmux hook in src/hooks/useTmux.ts
- [ ] T040 [P] [US3] Create SessionTabs component in src/components/navigation/SessionTabs.tsx
- [ ] T041 [P] [US3] Create WindowTabs component in src/components/navigation/WindowTabs.tsx
- [ ] T042 [P] [US3] Create PaneSelector component in src/components/navigation/PaneSelector.tsx
- [ ] T043 [US3] Create SessionTree component in src/components/connection/SessionTree.tsx
- [ ] T044 [US3] Create terminal screen with navigation in app/(main)/terminal/[connectionId].tsx
- [ ] T045 [US3] Add auto-selection of first session/window/pane on connect

**Checkpoint**: Session, window, and pane navigation works completely

---

## Phase 6: User Story 4 - Terminal Display (Priority: P2)

**Goal**: Display the selected pane's contents with ANSI color support and render Japanese text correctly

**Independent Test**: Select a pane and verify that ANSI-colored output is displayed correctly and Japanese text does not become garbled

### Tests for User Story 4

- [ ] T046 [P] [US4] Unit test for AnsiParser in __tests__/services/ansi/parser.test.ts
- [ ] T047 [P] [US4] Unit test for charWidth in __tests__/services/terminal/charWidth.test.ts

### Implementation for User Story 4

- [ ] T048 [P] [US4] Implement AnsiParser class in src/services/ansi/parser.ts
- [ ] T049 [P] [US4] Implement charWidth utility in src/services/terminal/charWidth.ts
- [ ] T050 [P] [US4] Implement formatter in src/services/terminal/formatter.ts
- [ ] T051 [US4] Create terminalStore with Zustand in src/stores/terminalStore.ts
- [ ] T052 [US4] Implement useTerminal hook (polling, content update) in src/hooks/useTerminal.ts
- [ ] T053 [US4] Create TerminalView component with FlatList in src/components/terminal/TerminalView.tsx
- [ ] T054 [US4] Add ANSI color rendering to TerminalView
- [ ] T055 [US4] Add 100ms polling for pane content updates
- [ ] T056 [US4] Add scrollback support (1000 lines)
- [ ] T057 [US4] Integrate TerminalView into terminal screen

**Checkpoint**: Terminal contents are displayed in real time with ANSI colors

---

## Phase 7: User Story 5 - Key Input (Priority: P2)

**Goal**: The user can enter characters and special keys from the keyboard and send them to the pane

**Independent Test**: Type text, press Enter to run a command, and send Ctrl+C to interrupt a process

### Tests for User Story 5

- [ ] T058 [P] [US5] Unit test for key mapping in __tests__/services/tmux/commands.test.ts (sendKeys)
- [ ] T059 [P] [US5] Component test for SpecialKeys in __tests__/components/terminal/SpecialKeys.test.tsx

### Implementation for User Story 5

- [ ] T060 [P] [US5] Create SpecialKeys component (ESC, TAB, CTRL, arrows) in src/components/terminal/SpecialKeys.tsx
- [ ] T061 [US5] Create TerminalInput component in src/components/terminal/TerminalInput.tsx
- [ ] T062 [US5] Add sendKeys method to TmuxCommands in src/services/tmux/commands.ts
- [ ] T063 [US5] Extend useTerminal hook with sendKeys, sendSpecialKey, sendCtrl
- [ ] T064 [US5] Integrate TerminalInput and SpecialKeys into terminal screen
- [ ] T065 [US5] Add keyboard handling for software keyboard input
- [ ] T066 [US5] Add Ctrl+key combination support (Ctrl+C, Ctrl+D, etc.)

**Checkpoint**: Full interactive terminal operation is possible

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T067 [P] Add error handling for network disconnection (reconnect option)
- [ ] T068 [P] Add error message for tmux not installed
- [ ] T069 [P] Add empty state for no tmux sessions
- [ ] T070 [P] Add connection timeout handling with user feedback
- [ ] T071 [P] Add loading indicators for connection and navigation
- [ ] T072 Performance optimization for terminal rendering (memoization)
- [ ] T073 Run pnpm typecheck and fix any type errors
- [ ] T074 Run pnpm lint and fix any lint errors
- [ ] T075 Validate against quickstart.md test scenarios

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundational) → [Phase 3-7 User Stories] → Phase 8 (Polish)
                                              ↓
                         ┌─────────────────────────────────────┐
                         │     P1 Stories (sequential):        │
                         │  Phase 3 (US1) → Phase 4 (US2)     │
                         │                                     │
                         │     P2 Stories (can parallelize):   │
                         │  Phase 5 (US3) ←→ Phase 6 (US4)    │
                         │              ↘   ↙                  │
                         │          Phase 7 (US5)              │
                         └─────────────────────────────────────┘
```

### User Story Dependencies

| Story | Depends On | Can Start After |
|-------|------------|-----------------|
| US1 (SSH Connection) | Foundational | Phase 2 complete |
| US2 (Connection Management) | US1 (connectionStore) | T019-T022 complete |
| US3 (tmux Navigation) | US1 (SSHClient) | Phase 3 complete |
| US4 (Display) | US3 (tmux commands) | T036-T039 complete |
| US5 (Input) | US3, US4 | T062 (sendKeys) ready |

### Parallel Opportunities

**Within Setup (Phase 1)**:
- T002, T003, T004, T005, T007 can all run in parallel

**Within Foundational (Phase 2)**:
- T009, T010, T011, T012 (all type definitions) can run in parallel

**Within Each User Story**:
- Tests (if included) can run in parallel
- Models/types can run in parallel
- Independent components can run in parallel

**Cross-Story Parallelization** (with team):
- After US1 complete: US2 can proceed
- After US3 tmux commands ready: US4 and US5 can work in parallel

---

## Parallel Example: Phase 2 (Foundational)

```bash
# All type definitions in parallel:
Task: "Create Connection type in src/types/connection.ts"
Task: "Create TmuxSession types in src/types/tmux.ts"
Task: "Create PaneContent types in src/types/terminal.ts"
```

## Parallel Example: User Story 3

```bash
# Tests in parallel:
Task: "Unit test for TmuxCommands in __tests__/services/tmux/commands.test.ts"
Task: "Unit test for parser in __tests__/services/tmux/parser.test.ts"

# Then implementation services in parallel:
Task: "Implement TmuxCommands in src/services/tmux/commands.ts"
Task: "Implement parser in src/services/tmux/parser.ts"

# Then components in parallel:
Task: "Create SessionTabs in src/components/navigation/SessionTabs.tsx"
Task: "Create WindowTabs in src/components/navigation/WindowTabs.tsx"
Task: "Create PaneSelector in src/components/navigation/PaneSelector.tsx"
```

---

## Implementation Strategy

### MVP First (US1 + US2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1 (SSH Connection)
4. Complete Phase 4: User Story 2 (Connection Management)
5. **STOP and VALIDATE**: Connection setting save/load and SSH connection work

### Core Terminal (US3 + US4)

6. Complete Phase 5: User Story 3 (tmux Navigation)
7. Complete Phase 6: User Story 4 (Display)
8. **STOP and VALIDATE**: Session selection and pane content display work

### Full Interactive (US5)

9. Complete Phase 7: User Story 5 (Input)
10. **STOP and VALIDATE**: Full interactive operation works

### Production Ready

11. Complete Phase 8: Polish
12. Final validation

---

## Task Summary

| Phase | Tasks | Parallel Tasks |
|-------|-------|----------------|
| 1. Setup | 8 | 5 |
| 2. Foundational | 6 | 4 |
| 3. US1 (SSH connection) | 8 | 4 |
| 4. US2 (Connection Management) | 11 | 4 |
| 5. US3 (tmux) | 12 | 6 |
| 6. US4 (display) | 12 | 4 |
| 7. US5 (input) | 9 | 3 |
| 8. Polish | 9 | 5 |
| **Total** | **75** | **35** |

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Constitution requires TDD: write tests first where marked
- Each user story should be independently testable at its checkpoint
- Commit after each task or logical group
- Run `pnpm typecheck && pnpm lint` before completing each phase



