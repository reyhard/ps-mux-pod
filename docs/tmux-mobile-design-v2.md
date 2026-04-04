# MuxPod - details v2

## 1. System Overview

### 1.1 Project Name
**MuxPod**

### 1.2 Purpose
PCserverbehaviortmuxAndroidSSHviaoperation。

### 1.3 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ Android Device │
│ ┌───────────────────────────────────────────────────────────┐ │
│ │ Expo (React Native) │ │
│ │ │ │
│ │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐ │ │
│ │ │ Connections │ │ Session/ │ │ Terminal │ │ │
│ │ │ List │ │ Window/Pane │ │ View │ │ │
│ │ └─────────────┘ └─────────────┘ └─────────────────┘ │ │
│ │ │ │ │
│ │ ┌─────────────────────┴────────────────────────────┐ │ │
│ │ │ State Management (Zustand) │ │ │
│ │ └─────────────────────┬────────────────────────────┘ │ │
│ │ │ │ │
│ │ ┌─────────────────────┴────────────────────────────┐ │ │
│ │ │ SSH Client (react-native-ssh) │ │ │
│ │ └─────────────────────┬────────────────────────────┘ │ │
│ │ │ │ │
│ │ ┌─────────────────────┴────────────────────────────┐ │ │
│ │ │ SSH Key Store (Secure Enclave) │ │ │
│ │ └──────────────────────────────────────────────────┘ │ │
│ └───────────────────────────────────────────────────────────┘ │
└───────────────────────────│─────────────────────────────────────┘
 │ SSH (Port 22 or custom)
 │
┌───────────────────────────│─────────────────────────────────────┐
│ Remote Server (Linux) │
│ │ │
│ ┌───────┴───────┐ │
│ │ sshd │ │
│ └───────┬───────┘ │
│ │ │
│ ┌───────┴───────┐ │
│ │ tmux │ │
│ └───────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 1.4 v1change

| | v1 () | v2 () |
|------|---------|---------|
| connection | WebSocket + Bunserver | SSHconnection |
| serverrequirements | Bunserver | sshd （existing） |
| notification | server | （ntfy） |
| authentication | | SSHkey / password |

## 2. Android (Expo)

### 2.1 structure

```
muxpod/
├── app/ # Expo Router
│ ├── _layout.tsx # Root layout
│ ├── index.tsx # connectionlistscreen
│ ├── (main)/
│ │ ├── _layout.tsx # 
│ │ ├── terminal/
│ │ │ └── [connectionId].tsx # terminalscreen
│ │ └── notifications/
│ │ └── [connectionId].tsx # notificationsettings
│ ├── connection/
│ │ ├── add.tsx # connection
│ │ └── [id]/
│ │ └── edit.tsx # connection
│ ├── keys/
│ │ ├── index.tsx # SSHkeylist
│ │ ├── generate.tsx # keygenerate
│ │ └── import.tsx # keyimport
│ └── settings/
│ └── index.tsx # settings
├── src/
│ ├── components/
│ │ ├── terminal/
│ │ │ ├── TerminalView.tsx # terminaldisplay
│ │ │ ├── TerminalInput.tsx # input
│ │ │ ├── SpecialKeys.tsx # ESC/CTRL/ALT
│ │ │ └── VirtualKeyboard.tsx # 
│ │ ├── connection/
│ │ │ ├── ConnectionList.tsx
│ │ │ ├── ConnectionCard.tsx
│ │ │ └── SessionTree.tsx # //
│ │ ├── navigation/
│ │ │ ├── SessionTabs.tsx # 
│ │ │ ├── WindowTabs.tsx # 
│ │ │ └── PaneSelector.tsx # select
│ │ └── ui/
│ │ ├── Header.tsx
│ │ └── BottomNav.tsx
│ ├── hooks/
│ │ ├── useSSH.ts # SSHconnectionmanagement
│ │ ├── useTmux.ts # tmux
│ │ ├── useTerminal.ts # terminal
│ │ └── useNotificationRules.ts # notification
│ ├── stores/
│ │ ├── connectionStore.ts # connectionsettings
│ │ ├── sessionStore.ts # tmux
│ │ ├── terminalStore.ts # terminal
│ │ ├── keyStore.ts # SSHkey
│ │ └── settingsStore.ts # settings
│ ├── services/
│ │ ├── ssh/
│ │ │ ├── client.ts # SSH
│ │ │ ├── channel.ts # SSHmanagement
│ │ │ └── auth.ts # authentication
│ │ ├── tmux/
│ │ │ ├── commands.ts # tmux
│ │ │ ├── parser.ts # 
│ │ │ └── types.ts # tmux
│ │ ├── notification/
│ │ │ ├── engine.ts # notification（）
│ │ │ ├── rules.ts # management
│ │ │ └── matchers.ts # 
│ │ ├── keychain/
│ │ │ ├── secureStore.ts # Secure Enclave
│ │ │ └── keyManager.ts # keymanagement
│ │ ├── ansi/
│ │ │ └── parser.ts # ANSI
│ │ └── terminal/
│ │ ├── charWidth.ts # 
│ │ └── formatter.ts # terminal
│ └── types/
│ ├── connection.ts
│ ├── tmux.ts
│ └── settings.ts
├── assets/
│ └── fonts/
│ ├── JetBrainsMono.ttf
│ ├── FiraCode.ttf
│ ├── HackGen.ttf # support
│ └── PlemolJP.ttf # support
├── app.json
├── package.json
└── tsconfig.json
```

### 2.2 Data Model

#### 2.2.1 connectionsettings

```typescript
// src/types/connection.ts

interface Connection {
 id: string; // UUID
 name: string; // display (e.g., "Production AWS")
 host: string; // host or IP
 port: number; // SSH (default: 22)
 username: string; // SSH
 authMethod: 'password' | 'key';
 keyId?: string; // SSHkeyID（keyauthentication）
 timeout: number; // connection
 keepAliveInterval: number; // Keepalive
 
 // information
 icon?: string; // 
 color?: string; // 
 tags?: string[]; // 
 lastConnected?: number; // connection
 createdAt: number;
 updatedAt: number;
}

interface ConnectionState {
 connectionId: string;
 status: 'disconnected' | 'connecting' | 'connected' | 'error';
 error?: string;
 latency?: number; // RTT (ms)
}
```

#### 2.2.2 SSHkey

```typescript
// src/types/key.ts

interface SSHKey {
 id: string; // UUID
 name: string; // display
 type: 'rsa' | 'ed25519' | 'ecdsa';
 bits?: number; // RSA: 2048, 4096
 fingerprint: string; // SHA256fingerprint
 publicKey: string; // key（display）
 encrypted: boolean; // passphrase
 storedInSecureEnclave: boolean;
 isDefault: boolean;
 createdAt: number;
 lastUsed?: number;
}
```

#### 2.2.3 tmux

```typescript
// src/types/tmux.ts

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

interface TmuxPane {
 index: number;
 id: string; // %0, %1, etc.
 active: boolean;
 currentCommand: string;
 title: string;
 width: number;
 height: number;
 cursorX: number;
 cursorY: number;
}

interface PaneContent {
 paneId: string;
 lines: string[]; // 
 scrollbackSize: number;
 cursorX: number;
 cursorY: number;
}
```

#### 2.2.4 notification

```typescript
// src/types/notification.ts

interface NotificationRule {
 id: string;
 name: string;
 enabled: boolean;
 
 // 
 connectionId: string;
 sessionName?: string; // omit
 windowIndex?: number;
 paneIndex?: number;
 
 // 
 condition: NotificationCondition;
 
 // 
 action: 'in_app' | 'sound' | 'vibrate';
 soundName?: string;
 
 // 
 frequency: 'always' | 'once_per_session' | 'once_per_match';
 throttleMs: number; // minimumnotification
 
 lastTriggered?: number;
 createdAt: number;
}

type NotificationCondition =
 | { type: 'text'; text: string; caseSensitive: boolean }
 | { type: 'regex'; pattern: string; flags: string }
 | { type: 'idle'; durationMs: number }
 | { type: 'activity' };
```

#### 2.2.5 settings

```typescript
// src/types/settings.ts

interface AppSettings {
 // display
 display: {
 fontSize: number; // 10-24
 fontFamily: 'JetBrainsMono' | 'FiraCode' | 'Meslo' | 'HackGen' | 'PlemolJP';
 colorTheme: 'dracula' | 'solarized' | 'monokai' | 'nord' | 'custom';
 customColors?: TerminalColors;
 };
 
 // terminal
 terminal: {
 scrollbackLimit: number; // 1000-10000
 bellSound: boolean;
 bellVibrate: boolean;
 };
 
 // SSH
 ssh: {
 keepAliveInterval: number; // 0 = off, 10-300
 compressionEnabled: boolean;
 defaultPort: number;
 defaultUsername: string;
 };
 
 // security
 security: {
 useSecureEnclave: boolean;
 lockOnBackground: boolean;
 biometricUnlock: boolean;
 };
}

interface TerminalColors {
 background: string;
 foreground: string;
 cursor: string;
 selection: string;
 black: string;
 red: string;
 green: string;
 yellow: string;
 blue: string;
 magenta: string;
 cyan: string;
 white: string;
 brightBlack: string;
 brightRed: string;
 brightGreen: string;
 brightYellow: string;
 brightBlue: string;
 brightMagenta: string;
 brightCyan: string;
 brightWhite: string;
}
```

### 2.3 SSHconnection

```typescript
// src/services/ssh/client.ts
import { Client } from 'react-native-ssh-sftp'; // 

export class SSHClient {
 private client: Client | null = null;
 private shell: any = null;
 private onData: ((data: string) => void) | null = null;
 private onClose: (() => void) | null = null;
 
 async connect(connection: Connection, password?: string): Promise<void> {
 const config: any = {
 host: connection.host,
 port: connection.port,
 username: connection.username,
 timeout: connection.timeout * 1000,
 };
 
 if (connection.authMethod === 'password') {
 config.password = password;
 } else {
 const key = await this.loadPrivateKey(connection.keyId!);
 config.privateKey = key;
 }
 
 this.client = new Client();
 await this.client.connect(config);
 }
 
 async startShell(options?: {
 cols?: number;
 rows?: number;
 term?: string;
 }): Promise<void> {
 if (!this.client) throw new Error('Not connected');
 
 this.shell = await this.client.shell({
 pty: {
 cols: options?.cols || 80,
 rows: options?.rows || 24,
 term: options?.term || 'xterm-256color',
 },
 });
 
 this.shell.on('data', (data: Buffer) => {
 this.onData?.(data.toString('utf-8'));
 });
 
 this.shell.on('close', () => {
 this.onClose?.();
 });
 }
 
 async write(data: string): Promise<void> {
 if (!this.shell) throw new Error('Shell not started');
 this.shell.write(data);
 }
 
 async resize(cols: number, rows: number): Promise<void> {
 if (!this.shell) return;
 this.shell.setWindow(rows, cols, 0, 0);
 }
 
 async exec(command: string): Promise<string> {
 if (!this.client) throw new Error('Not connected');
 
 return new Promise((resolve, reject) => {
 this.client!.exec(command, (err: Error, stream: any) => {
 if (err) return reject(err);
 
 let output = '';
 stream.on('data', (data: Buffer) => {
 output += data.toString('utf-8');
 });
 stream.on('close', () => {
 resolve(output);
 });
 });
 });
 }
 
 setOnData(callback: (data: string) => void): void {
 this.onData = callback;
 }
 
 setOnClose(callback: () => void): void {
 this.onClose = callback;
 }
 
 async disconnect(): Promise<void> {
 this.shell?.close();
 this.client?.end();
 this.shell = null;
 this.client = null;
 }
 
 private async loadPrivateKey(keyId: string): Promise<string> {
 // Secure Enclavesecure storage
 return ''; // omit
 }
}
```

### 2.4 tmux Command Service

```typescript
// src/services/tmux/commands.ts

export class TmuxCommands {
 constructor(private ssh: SSHClient) {}
 
 async listSessions(): Promise<TmuxSession[]> {
 const output = await this.ssh.exec(
 'tmux list-sessions -F "#{session_name}\t#{session_created}\t#{session_attached}\t#{session_windows}" 2>/dev/null || echo ""'
 );
 
 if (!output.trim()) return [];
 
 return output.trim().split('\n').map(line => {
 const [name, created, attached, windowCount] = line.split('\t');
 return {
 name,
 created: parseInt(created) * 1000,
 attached: attached === '1',
 windowCount: parseInt(windowCount),
 windows: [],
 };
 });
 }
 
 async listWindows(sessionName: string): Promise<TmuxWindow[]> {
 const output = await this.ssh.exec(
 `tmux list-windows -t ${this.escape(sessionName)} -F "#{window_index}\t#{window_name}\t#{window_active}\t#{window_panes}" 2>/dev/null || echo ""`
 );
 
 if (!output.trim()) return [];
 
 return output.trim().split('\n').map(line => {
 const [index, name, active, paneCount] = line.split('\t');
 return {
 index: parseInt(index),
 name,
 active: active === '1',
 paneCount: parseInt(paneCount),
 panes: [],
 };
 });
 }
 
 async listPanes(sessionName: string, windowIndex: number): Promise<TmuxPane[]> {
 const output = await this.ssh.exec(
 `tmux list-panes -t ${this.escape(sessionName)}:${windowIndex} -F "#{pane_index}\t#{pane_id}\t#{pane_active}\t#{pane_current_command}\t#{pane_title}\t#{pane_width}\t#{pane_height}\t#{cursor_x}\t#{cursor_y}" 2>/dev/null || echo ""`
 );
 
 if (!output.trim()) return [];
 
 return output.trim().split('\n').map(line => {
 const [index, id, active, command, title, width, height, cursorX, cursorY] = line.split('\t');
 return {
 index: parseInt(index),
 id,
 active: active === '1',
 currentCommand: command,
 title,
 width: parseInt(width),
 height: parseInt(height),
 cursorX: parseInt(cursorX),
 cursorY: parseInt(cursorY),
 };
 });
 }
 
 async capturePane(
 sessionName: string,
 windowIndex: number,
 paneIndex: number,
 options?: { start?: number; end?: number; escape?: boolean }
 ): Promise<string[]> {
 let cmd = `tmux capture-pane -t ${this.escape(sessionName)}:${windowIndex}.${paneIndex} -p`;
 
 if (options?.start !== undefined) cmd += ` -S ${options.start}`;
 if (options?.end !== undefined) cmd += ` -E ${options.end}`;
 if (options?.escape) cmd += ' -e'; // ANSI
 
 const output = await this.ssh.exec(cmd);
 return output.split('\n');
 }
 
 async sendKeys(
 sessionName: string,
 windowIndex: number,
 paneIndex: number,
 keys: string,
 literal: boolean = false
 ): Promise<void> {
 const target = `${this.escape(sessionName)}:${windowIndex}.${paneIndex}`;
 const literalFlag = literal ? ' -l' : '';
 await this.ssh.exec(`tmux send-keys -t ${target}${literalFlag} ${this.escapeKeys(keys)}`);
 }
 
 async selectPane(sessionName: string, windowIndex: number, paneIndex: number): Promise<void> {
 await this.ssh.exec(
 `tmux select-pane -t ${this.escape(sessionName)}:${windowIndex}.${paneIndex}`
 );
 }
 
 async selectWindow(sessionName: string, windowIndex: number): Promise<void> {
 await this.ssh.exec(
 `tmux select-window -t ${this.escape(sessionName)}:${windowIndex}`
 );
 }
 
 async newSession(name: string): Promise<void> {
 await this.ssh.exec(`tmux new-session -d -s ${this.escape(name)}`);
 }
 
 async killSession(name: string): Promise<void> {
 await this.ssh.exec(`tmux kill-session -t ${this.escape(name)}`);
 }
 
 async resizePane(
 sessionName: string,
 windowIndex: number,
 paneIndex: number,
 width: number,
 height: number
 ): Promise<void> {
 const target = `${this.escape(sessionName)}:${windowIndex}.${paneIndex}`;
 await this.ssh.exec(`tmux resize-pane -t ${target} -x ${width} -y ${height}`);
 }
 
 private escape(str: string): string {
 // 
 return `'${str.replace(/'/g, "'\\''")}'`;
 }
 
 private escapeKeys(keys: string): string {
 // tmux send-keys
 return `'${keys.replace(/'/g, "'\\''")}'`;
 }
}
```

### 2.5 terminaldisplay Hook

```typescript
// src/hooks/useTerminal.ts
import { useState, useEffect, useCallback, useRef } from 'react';
import { SSHClient } from '../services/ssh/client';
import { TmuxCommands } from '../services/tmux/commands';
import { useTerminalStore } from '../stores/terminalStore';
import { useNotificationRules } from './useNotificationRules';

interface UseTerminalOptions {
 connectionId: string;
 sessionName: string;
 windowIndex: number;
 paneIndex: number;
}

export function useTerminal(options: UseTerminalOptions) {
 const { connectionId, sessionName, windowIndex, paneIndex } = options;
 
 const [isLoading, setIsLoading] = useState(true);
 const [error, setError] = useState<string | null>(null);
 
 const sshRef = useRef<SSHClient | null>(null);
 const tmuxRef = useRef<TmuxCommands | null>(null);
 const pollIntervalRef = useRef<NodeJS.Timeout | null>(null);
 
 const { content, setContent, appendOutput } = useTerminalStore();
 const { checkRules } = useNotificationRules(connectionId);
 
 // polling
 const pollPaneContent = useCallback(async () => {
 if (!tmuxRef.current) return;
 
 try {
 const lines = await tmuxRef.current.capturePane(
 sessionName,
 windowIndex,
 paneIndex,
 { start: -1000, escape: true } // 1000 + ANSI
 );
 
 const newContent = lines.join('\n');
 const oldContent = content.get(paneIndex)?.lines.join('\n') || '';
 
 // update
 if (newContent !== oldContent) {
 setContent(paneIndex, { lines, scrollbackSize: lines.length, cursorX: 0, cursorY: 0 });
 
 // notification
 const diff = newContent.slice(oldContent.length);
 if (diff) {
 checkRules(sessionName, windowIndex, paneIndex, diff);
 }
 }
 } catch (e) {
 console.error('Failed to capture pane:', e);
 }
 }, [sessionName, windowIndex, paneIndex, content, setContent, checkRules]);
 
 // 
 useEffect(() => {
 const init = async () => {
 try {
 setIsLoading(true);
 setError(null);
 
 // SSHconnectionassumption
 // connectionStoreretrieve
 sshRef.current = getSSHClient(connectionId);
 tmuxRef.current = new TmuxCommands(sshRef.current);
 
 // firstretrieve
 await pollPaneContent();
 
 // polling (100ms)
 pollIntervalRef.current = setInterval(pollPaneContent, 100);
 
 setIsLoading(false);
 } catch (e) {
 setError(String(e));
 setIsLoading(false);
 }
 };
 
 init();
 
 return () => {
 if (pollIntervalRef.current) {
 clearInterval(pollIntervalRef.current);
 }
 };
 }, [connectionId, sessionName, windowIndex, paneIndex]);
 
 // 
 const sendKeys = useCallback(async (keys: string, literal = false) => {
 if (!tmuxRef.current) return;
 await tmuxRef.current.sendKeys(sessionName, windowIndex, paneIndex, keys, literal);
 }, [sessionName, windowIndex, paneIndex]);
 
 // 
 const sendSpecialKey = useCallback(async (key: 'Enter' | 'Escape' | 'Tab' | 'Backspace' | 'Up' | 'Down' | 'Left' | 'Right') => {
 const keyMap: Record<string, string> = {
 'Enter': 'Enter',
 'Escape': 'Escape',
 'Tab': 'Tab',
 'Backspace': 'BSpace',
 'Up': 'Up',
 'Down': 'Down',
 'Left': 'Left',
 'Right': 'Right',
 };
 await sendKeys(keyMap[key]);
 }, [sendKeys]);
 
 // Ctrl+
 const sendCtrl = useCallback(async (key: string) => {
 await sendKeys(`C-${key}`);
 }, [sendKeys]);
 
 return {
 content: content.get(paneIndex),
 isLoading,
 error,
 sendKeys,
 sendSpecialKey,
 sendCtrl,
 };
}
```

### 2.6 notification（）

```typescript
// src/services/notification/engine.ts
import { Vibration } from 'react-native';
import { Audio } from 'expo-av';
import { useNotificationStore } from '../../stores/notificationStore';

export class NotificationEngine {
 private rules: Map<string, NotificationRule> = new Map();
 private lastTriggered: Map<string, number> = new Map();
 
 addRule(rule: NotificationRule): void {
 this.rules.set(rule.id, rule);
 }
 
 removeRule(ruleId: string): void {
 this.rules.delete(ruleId);
 this.lastTriggered.delete(ruleId);
 }
 
 updateRule(rule: NotificationRule): void {
 this.rules.set(rule.id, rule);
 }
 
 checkOutput(
 connectionId: string,
 sessionName: string,
 windowIndex: number,
 paneIndex: number,
 output: string
 ): void {
 for (const rule of this.rules.values()) {
 if (!rule.enabled) continue;
 if (rule.connectionId !== connectionId) continue;
 
 // 
 if (rule.sessionName && rule.sessionName !== sessionName) continue;
 if (rule.windowIndex !== undefined && rule.windowIndex !== windowIndex) continue;
 if (rule.paneIndex !== undefined && rule.paneIndex !== paneIndex) continue;
 
 // 
 const lastTime = this.lastTriggered.get(rule.id) || 0;
 if (Date.now() - lastTime < rule.throttleMs) continue;
 
 // 
 const matched = this.evaluateCondition(rule.condition, output);
 if (!matched) continue;
 
 // notification
 this.triggerNotification(rule, output);
 this.lastTriggered.set(rule.id, Date.now());
 
 // once_per_session disabled
 if (rule.frequency === 'once_per_session') {
 rule.enabled = false;
 this.rules.set(rule.id, rule);
 }
 }
 }
 
 private evaluateCondition(condition: NotificationCondition, output: string): boolean {
 switch (condition.type) {
 case 'text': {
 const text = condition.caseSensitive ? output : output.toLowerCase();
 const search = condition.caseSensitive ? condition.text : condition.text.toLowerCase();
 return text.includes(search);
 }
 case 'regex': {
 try {
 const regex = new RegExp(condition.pattern, condition.flags);
 return regex.test(output);
 } catch {
 return false;
 }
 }
 case 'activity':
 return output.length > 0;
 case 'idle':
 // idleseparatelymanagement（false）
 return false;
 default:
 return false;
 }
 }
 
 private async triggerNotification(rule: NotificationRule, matchedText: string): Promise<void> {
 // notification
 useNotificationStore.getState().addNotification({
 id: `${rule.id}-${Date.now()}`,
 ruleId: rule.id,
 ruleName: rule.name,
 message: `Pattern matched: ${rule.name}`,
 matchedText: matchedText.slice(0, 100),
 timestamp: Date.now(),
 read: false,
 });
 
 // 
 if (rule.action === 'sound' && rule.soundName) {
 try {
 const { sound } = await Audio.Sound.createAsync(
 // file
 require(`../../assets/sounds/${rule.soundName}.mp3`)
 );
 await sound.playAsync();
 } catch (e) {
 console.error('Failed to play sound:', e);
 }
 }
 
 // 
 if (rule.action === 'vibrate') {
 Vibration.vibrate([0, 250, 100, 250]);
 }
 }
}

// singleton
export const notificationEngine = new NotificationEngine();
```

### 2.7 State Management (Zustand)

```typescript
// src/stores/connectionStore.ts
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';
import type { Connection, ConnectionState } from '../types/connection';

interface ConnectionStore {
 // saveconnectionsettings
 connections: Connection[];
 
 // （save）
 connectionStates: Map<string, ConnectionState>;
 
 // 
 addConnection: (connection: Omit<Connection, 'id' | 'createdAt' | 'updatedAt'>) => string;
 updateConnection: (id: string, updates: Partial<Connection>) => void;
 removeConnection: (id: string) => void;
 setConnectionState: (id: string, state: Partial<ConnectionState>) => void;
 getConnection: (id: string) => Connection | undefined;
}

export const useConnectionStore = create<ConnectionStore>()(
 persist(
 (set, get) => ({
 connections: [],
 connectionStates: new Map(),
 
 addConnection: (data) => {
 const id = crypto.randomUUID();
 const now = Date.now();
 const connection: Connection = {
 ...data,
 id,
 createdAt: now,
 updatedAt: now,
 };
 set((state) => ({
 connections: [...state.connections, connection],
 }));
 return id;
 },
 
 updateConnection: (id, updates) => {
 set((state) => ({
 connections: state.connections.map((c) =>
 c.id === id ? { ...c, ...updates, updatedAt: Date.now() } : c
 ),
 }));
 },
 
 removeConnection: (id) => {
 set((state) => ({
 connections: state.connections.filter((c) => c.id !== id),
 }));
 },
 
 setConnectionState: (id, stateUpdates) => {
 set((state) => {
 const newStates = new Map(state.connectionStates);
 const current = newStates.get(id) || { connectionId: id, status: 'disconnected' };
 newStates.set(id, { ...current, ...stateUpdates });
 return { connectionStates: newStates };
 });
 },
 
 getConnection: (id) => {
 return get().connections.find((c) => c.id === id);
 },
 }),
 {
 name: 'muxpod-connections',
 storage: createJSONStorage(() => AsyncStorage),
 partialize: (state) => ({ connections: state.connections }),
 }
 )
);
```

```typescript
// src/stores/settingsStore.ts
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';
import type { AppSettings } from '../types/settings';

const defaultSettings: AppSettings = {
 display: {
 fontSize: 14,
 fontFamily: 'JetBrainsMono',
 colorTheme: 'dracula',
 },
 terminal: {
 scrollbackLimit: 2000,
 bellSound: false,
 bellVibrate: true,
 },
 ssh: {
 keepAliveInterval: 60,
 compressionEnabled: false,
 defaultPort: 22,
 defaultUsername: '',
 },
 security: {
 useSecureEnclave: true,
 lockOnBackground: false,
 biometricUnlock: false,
 },
};

interface SettingsStore {
 settings: AppSettings;
 updateSettings: (updates: Partial<AppSettings>) => void;
 updateDisplaySettings: (updates: Partial<AppSettings['display']>) => void;
 updateTerminalSettings: (updates: Partial<AppSettings['terminal']>) => void;
 updateSSHSettings: (updates: Partial<AppSettings['ssh']>) => void;
 updateSecuritySettings: (updates: Partial<AppSettings['security']>) => void;
 resetSettings: () => void;
}

export const useSettingsStore = create<SettingsStore>()(
 persist(
 (set) => ({
 settings: defaultSettings,
 
 updateSettings: (updates) => {
 set((state) => ({
 settings: { ...state.settings, ...updates },
 }));
 },
 
 updateDisplaySettings: (updates) => {
 set((state) => ({
 settings: {
 ...state.settings,
 display: { ...state.settings.display, ...updates },
 },
 }));
 },
 
 updateTerminalSettings: (updates) => {
 set((state) => ({
 settings: {
 ...state.settings,
 terminal: { ...state.settings.terminal, ...updates },
 },
 }));
 },
 
 updateSSHSettings: (updates) => {
 set((state) => ({
 settings: {
 ...state.settings,
 ssh: { ...state.settings.ssh, ...updates },
 },
 }));
 },
 
 updateSecuritySettings: (updates) => {
 set((state) => ({
 settings: {
 ...state.settings,
 security: { ...state.settings.security, ...updates },
 },
 }));
 },
 
 resetSettings: () => {
 set({ settings: defaultSettings });
 },
 }),
 {
 name: 'muxpod-settings',
 storage: createJSONStorage(() => AsyncStorage),
 }
 )
);
```

### 2.8 Dependencies

```json
{
 "name": "muxpod",
 "version": "1.0.0",
 "main": "expo-router/entry",
 "scripts": {
 "start": "expo start",
 "android": "expo run:android",
 "ios": "expo run:ios",
 "lint": "eslint . --ext .ts,.tsx",
 "typecheck": "tsc --noEmit"
 },
 "dependencies": {
 "expo": "~52.0.0",
 "expo-av": "~14.0.0",
 "expo-font": "~12.0.0",
 "expo-router": "~4.0.0",
 "expo-secure-store": "~13.0.0",
 "expo-status-bar": "~2.0.0",
 "react": "18.3.1",
 "react-native": "0.76.0",
 "react-native-gesture-handler": "~2.20.0",
 "react-native-reanimated": "~3.16.0",
 "react-native-safe-area-context": "4.12.0",
 "react-native-screens": "~4.1.0",
 "react-native-ssh-sftp": "^1.4.0",
 "zustand": "^5.0.0",
 "@react-native-async-storage/async-storage": "2.1.0"
 },
 "devDependencies": {
 "@babel/core": "^7.25.0",
 "@types/react": "~18.3.0",
 "eslint": "^9.0.0",
 "typescript": "^5.6.0"
 }
}
```

## 3. screen

```
┌─────────────────┐
│ Connections │ ←── 
│ (Net) │
└────────┬────────┘
 │ connectionselect
 ▼
┌─────────────────┐
│ Terminal │ ←── //display
│ (Term) │
└────────┬────────┘
 │
 ┌────┴────┐
 ▼ ▼
┌───────┐ ┌──────────────────┐
│ Keys │ │ Notification │
│ │ │ Rules │
└───────┘ └──────────────────┘
 │ │
 └──────┬───────┘
 ▼
 ┌─────────────┐
 │ Settings │
 └─────────────┘
```

## 4. security

| | |
|------|------|
| SSHkeysave | Android Keystore / Secure Enclave |
| passwordsave | expo-secure-store（） |
| | SSH（） |
| screen | |
| authentication | /authentication |

## 5. Development Roadmap

### Phase 1: MVP（3-4）
- [ ] SSHconnection（connection、authentication、）
- [ ] connectionmanagementUI（、、delete）
- [ ] tmuxbasicoperation（//list）
- [ ] terminaldisplay（ANSI、）
- [ ] input（、、Ctrl）

### Phase 2: feature（2-3）
- [ ] SSHkeymanagement（generate、import、Secure Enclave）
- [ ] notification（notification）
- [ ] settingsscreen（、、SSHsettings）
- [ ] support

### Phase 3: UXimprovement（1-2）
- [ ] 
- [ ] operation
- [ ] history/
- [ ] multipledisplay（）

### Phase 4: feature（）
- [ ] MOSHsupport
- [ ] ntfy（notification）
- [ ] SFTP（file）
- [ ] 

## 6. Reference Links

- [tmux man page](https://man.openbsd.org/tmux)
- [Expo Documentation](https://docs.expo.dev/)
- [react-native-ssh-sftp](https://github.com/aspect-apps/react-native-ssh-sftp)
- [Android Keystore](https://developer.android.com/training/articles/keystore)
