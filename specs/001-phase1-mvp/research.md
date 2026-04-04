# Research: MuxPod Phase 1 MVP

**Feature**: 001-phase1-mvp
**Date**: 2026-01-10

## Research Topics

### 1. SSH connectionlibrary

**Decision**: `react-native-ssh-sftp` 

**Rationale**:
- React NativematureSSHlibrary
- passwordauthenticationpublic keyauthenticationsupport
- shellconnection（PTY）commandrunsupport
- iOS/Androidbehaviortrack record

**Alternatives Considered**:

| library |  | rationale |
|-----------|------|----------|
| ssh2 (Node.js) | × | React Nativebehavior |
| WebSocket | × | serveraddcomponentrequired |
| react-native-tcp | × | SSHimplementperformrequired |

**Implementation Notes**:
```typescript
// basicconnectionpattern
import SSHClient from 'react-native-ssh-sftp';

const client = new SSHClient(host, port, username, {
  password: 'xxx', // or
  privateKey: 'xxx',
});

await client.connect();
const shell = await client.startShell('xterm-256color', { rows: 24, cols: 80 });
shell.on('data', (data: string) => { /* handle output */ });
shell.write('command\n');
```

---

### 2. ANSIescapesequenceprocessing

**Decision**: customparserimplement（lightweight）

**Rationale**:
- npm`ansi-parser`Node.jsdependency
- React Nativebehaviorlightweightimplementrequired
- requiredfeature16color/256colordisplay（Phase 1）

**Alternatives Considered**:

|  |  | rationale |
|-----------|------|----------|
| ansi-parser | × | Node.jsdependency |
| xterm.js | × | DOMdependency、React Nativesupport |
| strip-ansi | △ | colorinformation |

**Implementation Pattern**:
```typescript
// ANSIparserbasic
interface AnsiSpan {
  text: string;
  fg?: number; // 0-255
  bg?: number; // 0-255
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
}

function parseAnsi(input: string): AnsiSpan[] {
  const ESC = '\x1b';
  const CSI = ESC + '[';
  // SGRsequenceparse: \x1b[<params>m
  // support: 30-37 (fg), 40-47 (bg), 38;5;n (256colorfg), 48;5;n (256colorbg)
}
```

---

### 3. tmuxcommandoutputparse

**Decision**: tabformatparse

**Rationale**:
- tmux`-F`customformatpossible
- tabparsepossible
- addlibrarynot needed

**Command Patterns**:

```bash
# sessionlist
tmux list-sessions -F "#{session_name}\t#{session_created}\t#{session_attached}\t#{session_windows}"

# windowlist
tmux list-windows -t SESSION -F "#{window_index}\t#{window_name}\t#{window_active}\t#{window_panes}"

# panelist
tmux list-panes -t SESSION:WINDOW -F "#{pane_index}\t#{pane_id}\t#{pane_active}\t#{pane_current_command}\t#{pane_width}\t#{pane_height}"

# panecontentsretrieve
tmux capture-pane -t SESSION:WINDOW.PANE -p -e  # -e ANSIretain
```

**Parser Pattern**:
```typescript
function parseTmuxOutput<T>(output: string, keys: (keyof T)[]): T[] {
  return output
    .trim()
    .split('\n')
    .filter(line => line.length > 0)
    .map(line => {
      const values = line.split('\t');
      return keys.reduce((obj, key, i) => {
        obj[key] = values[i];
        return obj;
      }, {} as T);
    });
}
```

---

### 4. statemanagementpattern（Zustand + persistence）

**Decision**: Zustand + persist middleware + AsyncStorage

**Rationale**:
- Zustand 5.0lightweightReact Nativeoptimal
- persist middlewareautomaticpersistence
- connectionstate（）connection settings（persistence）

**Implementation Pattern**:
```typescript
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface ConnectionStore {
  connections: Connection[];
  // Runtime state (not persisted)
  connectionStates: Map<string, ConnectionState>;

  addConnection: (conn: Omit<Connection, 'id'>) => void;
}

export const useConnectionStore = create<ConnectionStore>()(
  persist(
    (set, get) => ({
      connections: [],
      connectionStates: new Map(),
      addConnection: (conn) => set((state) => ({
        connections: [...state.connections, { ...conn, id: crypto.randomUUID() }],
      })),
    }),
    {
      name: 'muxpod-connections',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (state) => ({ connections: state.connections }), // Exclude runtime state
    }
  )
);
```

---

### 5. securestorage（passwordsave）

**Decision**: expo-secure-store 

**Rationale**:
- ExpoAPI
- Android Keystore / iOS Keychain internal
- syncAPI（）

**Implementation Pattern**:
```typescript
import * as SecureStore from 'expo-secure-store';

// passwordsave
await SecureStore.setItemAsync(`password-${connectionId}`, password);

// passwordretrieve
const password = await SecureStore.getItemAsync(`password-${connectionId}`);

// passworddelete
await SecureStore.deleteItemAsync(`password-${connectionId}`);
```

**Security Notes**:
- passwordConnection
- connectionSecureStoreretrieve
- appinstallautomaticdelete

---

### 6. terminal displayperformance

**Decision**: FlatList +  + 

**Rationale**:
- 1000linescrollbackhistorydisplay
- FlatListscreen
- React.memoreminimum

**Implementation Pattern**:
```typescript
const TerminalLine = React.memo(({ line, spans }: { line: number; spans: AnsiSpan[] }) => {
  return (
    <Text style={styles.line}>
      {spans.map((span, i) => (
        <Text key={i} style={getSpanStyle(span)}>{span.text}</Text>
      ))}
    </Text>
  );
});

const TerminalView = ({ lines }: { lines: AnsiSpan[][] }) => {
  return (
    <FlatList
      data={lines}
      renderItem={({ item, index }) => <TerminalLine line={index} spans={item} />}
      keyExtractor={(_, index) => index.toString()}
      initialNumToRender={30}
      maxToRenderPerBatch={20}
      windowSize={10}
      inverted // newline
    />
  );
};
```

---

### 7. Japaneseallcharacterswidth

**Decision**: East Asian Widthsupportcustomimplement

**Rationale**:
- terminalallcharacters2
- Unicode East Asian Width 

**Implementation Pattern**:
```typescript
// : CJKrangecheck
function getCharWidth(char: string): 1 | 2 {
  const code = char.charCodeAt(0);
  // CJK Unified Ideographs, Hiragana, Katakana, Fullwidth forms
  if (
    (code >= 0x4E00 && code <= 0x9FFF) || // CJK
    (code >= 0x3040 && code <= 0x30FF) || // Hiragana, Katakana
    (code >= 0xFF00 && code <= 0xFFEF)    // Fullwidth
  ) {
    return 2;
  }
  return 1;
}

function getStringWidth(str: string): number {
  return [...str].reduce((sum, char) => sum + getCharWidth(char), 0);
}
```

---

### 8. specialkeysend

**Decision**: tmux send-keyscommand

**Rationale**:
- tmuxsend-keysspecialkeysupport
- escapesequencerequired

**Key Mapping**:
```typescript
const SPECIAL_KEYS: Record<string, string> = {
  'Enter': 'Enter',
  'Escape': 'Escape',
  'Tab': 'Tab',
  'Backspace': 'BSpace',
  'Delete': 'DC',
  'Up': 'Up',
  'Down': 'Down',
  'Left': 'Left',
  'Right': 'Right',
  'Home': 'Home',
  'End': 'End',
  'PageUp': 'PPage',
  'PageDown': 'NPage',
};

// Ctrl+key
function ctrlKey(key: string): string {
  return `C-${key.toLowerCase()}`;
}

// sendexample
await tmux.sendKeys(session, window, pane, 'C-c'); // Ctrl+C
await tmux.sendKeys(session, window, pane, 'Escape'); // ESC
```

---

## Summary of Decisions

| Topic | Decision | Key Benefit |
|-------|----------|-------------|
| SSH connection | react-native-ssh-sftp | React Nativesupportmaturelibrary |
| ANSIparse | customlightweightimplement | Node.jsdependency |
| tmuxoutputparse | tabformat | parse |
| statemanagement | Zustand + persist | lightweight + automaticpersistence |
| passwordsave | expo-secure-store | OSstandardsecurestorage |
| terminal display | FlatList +  | 1000line60fps |
| characterswidth | East Asian Widthsupport | Japanesedisplay |
| specialkey | tmux send-keys | keysimple |



