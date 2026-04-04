# Implementation Plan: MuxPod Phase 1 MVP

**Branch**: `001-phase1-mvp` | **Date**: 2026-01-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-phase1-mvp/spec.md`

## Summary

MuxPod Phase 1 MVP、AndroidSSHservertmux sessionoperationExpo (React Native) app。SSH connection、connectionmanagementUI、tmux session/window/pane、ANSIcolorsupportterminal display、specialkey inputfeatureimplement。

## Technical Context

**Language/Version**: TypeScript 5.6+
**Framework**: Expo ~52.0.0 / React Native 0.76.0
**Primary Dependencies**:
- expo-router ~4.0.0 (filebaserouting)
- zustand ^5.0.0 (statemanagement)
- react-native-ssh-sftp ^1.4.0 (SSH connection)
- expo-secure-store ~13.0.0 (securesave)
- @react-native-async-storage/async-storage 2.1.0 (persistence)

**Storage**: AsyncStorage (connection settings), expo-secure-store (passwordencrypted)
**Testing**: Jest + React Native Testing Library
**Target Platform**: Android (primary), iOS (secondary)
**Project Type**: Mobile application
**Package Manager**: pnpm

**Performance Goals**:
- SSH connectionestablishmenttmux sessionlistdisplay5
- paneselectterminalcontentsdisplay1
- terminalupdate200ms
- key inputscreenreflect300ms
- 60fpsmaintainscroll

**Constraints**:
- 
- 1000linescrollbackhistory
- polling100ms

**Scale/Scope**:
- 5+connection settingssave
- 10+session、each10+window

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety | ✅ PASS | strict: truemaintain、externalinput（SSH） |
| II. KISS & YAGNI | ✅ PASS | Phase 1MVPfeature、Phase 2featureexclude |
| III. Test-First (TDD) | ✅ PASS | SSHcommand/tmuxoperationmockpossible |
| IV. Security-First | ✅ PASS | passwordexpo-secure-store、commandescaperequired |
| V. SOLID | ✅ PASS | SSH/tmux/UI、DIP |
| VI. DRY | ✅ PASS | sharedsrc/types/ |
| Prohibited Naming | ✅ PASS | utils/helpers、main |
| Quality Gates | ✅ PASS | pnpm typecheck/lintrequired |

## Project Structure

### Documentation (this feature)

```text
specs/001-phase1-mvp/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
app/                           # Expo Router (screen)
├── _layout.tsx                # Root layout
├── index.tsx                  # connection listscreen
├── (main)/
│   ├── _layout.tsx            # mainlayout
│   └── terminal/
│       └── [connectionId].tsx # terminalscreen
└── connection/
    ├── add.tsx                # connectionadd
    └── [id]/
        └── edit.tsx           # connectionedit

src/
├── components/
│   ├── terminal/
│   │   ├── TerminalView.tsx   # terminal display
│   │   ├── TerminalInput.tsx  # input
│   │   └── SpecialKeys.tsx    # ESC/CTRL/ALT
│   ├── connection/
│   │   ├── ConnectionList.tsx
│   │   ├── ConnectionCard.tsx
│   │   └── SessionTree.tsx    # session/window/pane
│   └── navigation/
│       ├── SessionTabs.tsx
│       ├── WindowTabs.tsx
│       └── PaneSelector.tsx
├── hooks/
│   ├── useSSH.ts              # SSH connectionmanagement
│   ├── useTmux.ts             # tmuxcommand
│   └── useTerminal.ts         # terminalstate
├── stores/
│   ├── connectionStore.ts     # connection settings
│   ├── sessionStore.ts        # tmux sessionstate
│   └── terminalStore.ts       # terminalcontents
├── services/
│   ├── ssh/
│   │   ├── client.ts          # SSHclient
│   │   └── auth.ts            # authenticationprocessing
│   ├── tmux/
│   │   ├── commands.ts        # tmuxcommandrun
│   │   └── parser.ts          # outputparser
│   ├── ansi/
│   │   └── parser.ts          # ANSIescapeprocessing
│   └── terminal/
│       ├── charWidth.ts       # characterswidth
│       └── formatter.ts       # output
└── types/
    ├── connection.ts
    ├── tmux.ts
    └── terminal.ts

__tests__/
├── services/
│   ├── ssh/
│   ├── tmux/
│   └── ansi/
├── hooks/
└── components/
```

**Structure Decision**: Mobile application。Expo Routerfilebaserouting（app/）（src/）。。

## Complexity Tracking

> No Constitution violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | - | - |



