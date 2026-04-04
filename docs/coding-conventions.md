# MuxPod Coding Conventions

## Naming Rules

| Target | Convention | Example |
|--------|-----------|---------|
| Components | PascalCase | `TerminalView.tsx` |
| hooks | camelCase + `use` prefix | `useTerminal.ts` |
| stores | camelCase + `Store` suffix | `connectionStore.ts` |
| services | camelCase | `client.ts` |
| Type definitions | PascalCase | `TmuxSession` |
| Constants | SCREAMING_SNAKE_CASE | `DEFAULT_PORT` |

## State Management

### Zustand Store
- Place global state in `src/stores/`
- Items requiring persistence: `persist` middleware + AsyncStorage
- Sensitive data: `expo-secure-store`

```typescript
// Example: src/stores/connectionStore.ts
export const useConnectionStore = create<ConnectionStore>()(
 persist(
 (set, get) => ({ ... }),
 {
 name: 'muxpod-connections',
 storage: createJSONStorage(() => AsyncStorage),
 partialize: (state) => ({ connections: state.connections }),
 }
 )
);
```

## SSH/tmux Operations

### SSH Client
- Use the `SSHClient` class from `src/services/ssh/client.ts`
- Connection management coordinates with `connectionStore`

### tmux Commands
- Use the `TmuxCommands` class from `src/services/tmux/commands.ts`
- Always use the `escape()` method for shell escaping (injection prevention)

```typescript
// Correct example
await tmux.sendKeys(sessionName, windowIndex, paneIndex, keys);

// Bad example (direct command construction is prohibited)
await ssh.exec(`tmux send-keys -t ${sessionName} ${keys}`);
```

## Terminal Display

- ANSI escape sequence processing: `src/services/ansi/parser.ts`
- Character width calculation (Japanese support): `src/services/terminal/charWidth.ts`
- Polling interval: 100ms (inside `useTerminal` hook)

## TypeScript

### Type Definitions
- Place shared types in `src/types/`
- Define component-specific Props in the same file

### Strict Mode
- Maintain `strict: true`
- Use of `any` is generally prohibited (use `// eslint-disable-next-line` with a comment if unavoidable)

## Component Design

### File Structure
```typescript
// 1. imports
import { ... } from 'react';
import { ... } from '@/components/ui';

// 2. types
interface Props { ... }

// 3. component
export function MyComponent({ ... }: Props) {
 // hooks
 // handlers
 // render
}
```

### Hooks
- Place custom hooks in `src/hooks/`
- Each hook should focus on a single responsibility
