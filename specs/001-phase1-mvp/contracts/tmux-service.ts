/**
 * tmux Service Contract
 *
 * tmuxcommandrunserviceinterface。
 * SSHtmuxcommandrun、resultparse。
 */

import type { TmuxSession, TmuxWindow, TmuxPane } from '../../../src/types/tmux';

/**
 * pane
 */
export interface CapturePaneOptions {
  /** startline（scrollback） */
  start?: number;
  /** closeline */
  end?: number;
  /** ANSIescapesequenceretain */
  escape?: boolean;
}

/**
 * tmuxserviceinterface
 */
export interface ITmuxService {
  /**
   * sessionlistretrieve
   * @returns sessioncolumn（column = tmuxrun）
   */
  listSessions(): Promise<TmuxSession[]>;

  /**
   * sessionwindowlistretrieve
   * @param sessionName session
   * @returns windowcolumn
   * @throws sessionwhen
   */
  listWindows(sessionName: string): Promise<TmuxWindow[]>;

  /**
   * windowpanelistretrieve
   * @param sessionName session
   * @param windowIndex window
   * @returns panecolumn
   * @throws session/windowwhen
   */
  listPanes(sessionName: string, windowIndex: number): Promise<TmuxPane[]>;

  /**
   * panecontents
   * @param sessionName session
   * @param windowIndex window
   * @param paneIndex pane
   * @param options 
   * @returns linecolumn（、ANSIescape）
   */
  capturePane(
    sessionName: string,
    windowIndex: number,
    paneIndex: number,
    options?: CapturePaneOptions
  ): Promise<string[]>;

  /**
   * panekey inputsend
   * @param sessionName session
   * @param windowIndex window
   * @param paneIndex pane
   * @param keys keycharacterscolumn（tmuxformat: Enter, Escape, C-c ）
   * @param literal send（escape）
   */
  sendKeys(
    sessionName: string,
    windowIndex: number,
    paneIndex: number,
    keys: string,
    literal?: boolean
  ): Promise<void>;

  /**
   * paneselect（active）
   * @param sessionName session
   * @param windowIndex window
   * @param paneIndex pane
   */
  selectPane(
    sessionName: string,
    windowIndex: number,
    paneIndex: number
  ): Promise<void>;

  /**
   * windowselect
   * @param sessionName session
   * @param windowIndex window
   */
  selectWindow(sessionName: string, windowIndex: number): Promise<void>;

  /**
   * paneresize
   * @param sessionName session
   * @param windowIndex window
   * @param paneIndex pane
   * @param width width（count）
   * @param height height（rows）
   */
  resizePane(
    sessionName: string,
    windowIndex: number,
    paneIndex: number,
    width: number,
    height: number
  ): Promise<void>;
}

/**
 * specialkey
 */
export const SPECIAL_KEYS = {
  Enter: 'Enter',
  Escape: 'Escape',
  Tab: 'Tab',
  Backspace: 'BSpace',
  Delete: 'DC',
  Up: 'Up',
  Down: 'Down',
  Left: 'Left',
  Right: 'Right',
  Home: 'Home',
  End: 'End',
  PageUp: 'PPage',
  PageDown: 'NPage',
  Insert: 'IC',
  F1: 'F1',
  F2: 'F2',
  F3: 'F3',
  F4: 'F4',
  F5: 'F5',
  F6: 'F6',
  F7: 'F7',
  F8: 'F8',
  F9: 'F9',
  F10: 'F10',
  F11: 'F11',
  F12: 'F12',
} as const;

/**
 * Ctrl+keygenerate
 * @param key key (a-z)
 * @returns tmuxformatCtrlkey (C-a )
 */
export function ctrlKey(key: string): string {
  return `C-${key.toLowerCase()}`;
}

/**
 * Alt+keygenerate
 * @param key key
 * @returns tmuxformatAltkey (M-a )
 */
export function altKey(key: string): string {
  return `M-${key}`;
}



