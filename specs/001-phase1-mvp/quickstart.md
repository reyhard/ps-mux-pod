# Quickstart: MuxPod Phase 1 MVP

**Feature**: 001-phase1-mvp
**Date**: 2026-01-10

## Prerequisites

- Node.js 18+
- pnpm 8+
- Android Studio (Android SDK)
- physical deviceemulator（Android 10+recommended）

## Setup

### 1. 

```bash
git clone <repo>
cd mux-pod
git checkout 001-phase1-mvp
```

### 2. dependencyinstall

```bash
pnpm install
```

### 3. serverstart

```bash
pnpm start
```

### 4. Androidrun

```bash
# separateterminal
pnpm android
```

## Project Structure Overview

```
mux-pod/
├── app/                    # Expo Router screens
│   ├── index.tsx           # connection list（）
│   ├── connection/         # connectionaddedit
│   └── (main)/terminal/    # terminalscreen
├── src/
│   ├── components/         # React components
│   ├── hooks/              # Custom hooks
│   ├── stores/             # Zustand stores
│   ├── services/           # Business logic
│   └── types/              # TypeScript types
└── __tests__/              # Test files
```

## Key Files to Implement

### Phase 1 MVP - priority order

#### 1. SSH connection (P1)

```
src/services/ssh/client.ts      # SSHclient
src/services/ssh/auth.ts        # authenticationprocessing
src/types/connection.ts         # Connection
```

#### 2. connectionmanagement (P1)

```
src/stores/connectionStore.ts   # connection settingspersistence
app/index.tsx                   # connection listscreen
app/connection/add.tsx          # connectionadd
app/connection/[id]/edit.tsx    # connectionedit
src/components/connection/      # UI components
```

#### 3. tmuxoperation (P2)

```
src/services/tmux/commands.ts   # tmuxcommand
src/services/tmux/parser.ts     # outputparser
src/types/tmux.ts               # TmuxSession
src/stores/sessionStore.ts      # sessionstatemanagement
```

#### 4. terminal display (P2)

```
src/services/ansi/parser.ts     # ANSIparser
src/components/terminal/TerminalView.tsx
src/stores/terminalStore.ts
```

#### 5. key input (P2)

```
src/components/terminal/TerminalInput.tsx
src/components/terminal/SpecialKeys.tsx
```

## Development Commands

```bash
# 
pnpm start                 # Expo dev server
pnpm android               # Androidrun
pnpm ios                   # iOSrun (optional)

# check
pnpm typecheck             # TypeScriptcheck
pnpm lint                  # ESLint
pnpm test                  # Jest tests

# build
pnpm build:android         # APK/AABgenerate
```

## Testing

### test

```bash
pnpm test                  # alltest
pnpm test -- --watch       # mode
pnpm test -- src/services  # 
```

### testfile

```
__tests__/
├── services/
│   ├── ssh/
│   │   └── client.test.ts
│   ├── tmux/
│   │   └── commands.test.ts
│   └── ansi/
│       └── parser.test.ts
└── components/
    └── terminal/
        └── TerminalView.test.tsx
```

## Key Patterns

### 1. SSHclient

```typescript
import { SSHClient } from '@/services/ssh/client';

const client = new SSHClient();
await client.connect(connection, { password });
const output = await client.exec('tmux list-sessions');
await client.disconnect();
```

### 2. tmuxcommandrun

```typescript
import { TmuxCommands } from '@/services/tmux/commands';

const tmux = new TmuxCommands(sshClient);
const sessions = await tmux.listSessions();
await tmux.sendKeys('main', 0, 0, 'ls -la');
await tmux.sendKeys('main', 0, 0, 'Enter');
```

### 3. Zustand Store

```typescript
import { useConnectionStore } from '@/stores/connectionStore';

// component
const { connections, addConnection } = useConnectionStore();

// component
const store = useConnectionStore.getState();
store.addConnection({ name: 'Server', host: '192.168.1.1', ... });
```

### 4. ANSIparse

```typescript
import { AnsiParser } from '@/services/ansi/parser';

const parser = new AnsiParser();
const spans = parser.parseLine('\x1b[32mgreen text\x1b[0m');
// [{ text: 'green text', fg: 2 }]
```

## Troubleshooting

### SSH connectionerror

1. host/portverify
2. settingsverify
3. password/keyverify

### tmux

```bash
# serververify
which tmux
# installwhen
sudo apt install tmux  # Ubuntu/Debian
sudo yum install tmux  # CentOS/RHEL
```

### Japanesecharacters

1. fontsettingsverify（HackGen, PlemolJPrecommended）
2. serverlocalesettingsverify

## References

- [spec.md](./spec.md) - featurespecification
- [plan.md](./plan.md) - implement
- [research.md](./research.md) - analysis
- [data-model.md](./data-model.md) - datamodel
- [contracts/](./contracts/) - serviceinterface



