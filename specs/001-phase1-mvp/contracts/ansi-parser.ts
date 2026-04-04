/**
 * ANSI Parser Contract
 *
 * ANSIescapesequenceparse、。
 */

/**
 * （same）
 */
export interface AnsiSpan {
  /** contents */
  text: string;
  /** color (0-255, undefined=default) */
  fg?: number;
  /** color (0-255, undefined=default) */
  bg?: number;
  /**  */
  bold?: boolean;
  /**  */
  dim?: boolean;
  /**  */
  italic?: boolean;
  /**  */
  underline?: boolean;
  /**  */
  blink?: boolean;
  /**  */
  inverse?: boolean;
  /** display */
  hidden?: boolean;
  /**  */
  strikethrough?: boolean;
}

/**
 * parseline
 */
export interface AnsiLine {
  /** column */
  spans: AnsiSpan[];
}

/**
 * ANSIparserinterface
 */
export interface IAnsiParser {
  /**
   * ANSIescapesequencelineparse
   * @param line 
   * @returns parsecolumn
   */
  parseLine(line: string): AnsiSpan[];

  /**
   * multiplelineparse
   * @param lines linecolumn
   * @returns parselinecolumn
   */
  parseLines(lines: string[]): AnsiLine[];

  /**
   * ANSIescapesequencedelete
   * @param text ANSIsequence
   * @returns 
   */
  stripAnsi(text: string): string;
}

/**
 * 16color（standard）
 */
export const ANSI_16_COLORS = {
  // standardcolor (30-37, 40-47)
  0: '#000000', // Black
  1: '#CC0000', // Red
  2: '#00CC00', // Green
  3: '#CCCC00', // Yellow
  4: '#0000CC', // Blue
  5: '#CC00CC', // Magenta
  6: '#00CCCC', // Cyan
  7: '#CCCCCC', // White
  // color (90-97, 100-107)
  8: '#666666',  // Bright Black
  9: '#FF0000',  // Bright Red
  10: '#00FF00', // Bright Green
  11: '#FFFF00', // Bright Yellow
  12: '#0000FF', // Bright Blue
  13: '#FF00FF', // Bright Magenta
  14: '#00FFFF', // Bright Cyan
  15: '#FFFFFF', // Bright White
} as const;

/**
 * 256color16countcolorcode
 * @param colorIndex 0-255
 * @returns #RRGGBBformatcolor
 */
export function ansi256ToHex(colorIndex: number): string {
  if (colorIndex < 16) {
    return ANSI_16_COLORS[colorIndex as keyof typeof ANSI_16_COLORS];
  }

  if (colorIndex < 232) {
    // 6x6x6 color (16-231)
    const index = colorIndex - 16;
    const r = Math.floor(index / 36);
    const g = Math.floor((index % 36) / 6);
    const b = index % 6;
    const toHex = (v: number) => (v === 0 ? 0 : 55 + v * 40).toString(16).padStart(2, '0');
    return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
  }

  //  (232-255)
  const gray = (colorIndex - 232) * 10 + 8;
  const hex = gray.toString(16).padStart(2, '0');
  return `#${hex}${hex}${hex}`;
}

/**
 * theme（terminalcolor）
 */
export interface TerminalTheme {
  /** color */
  background: string;
  /** color（default） */
  foreground: string;
  /** color */
  cursor: string;
  /** selectcolor */
  selection: string;
  /** 16color */
  palette: readonly [
    string, string, string, string, string, string, string, string,
    string, string, string, string, string, string, string, string
  ];
}

/**
 * Draculatheme
 */
export const DRACULA_THEME: TerminalTheme = {
  background: '#282A36',
  foreground: '#F8F8F2',
  cursor: '#F8F8F2',
  selection: '#44475A',
  palette: [
    '#21222C', '#FF5555', '#50FA7B', '#F1FA8C',
    '#BD93F9', '#FF79C6', '#8BE9FD', '#F8F8F2',
    '#6272A4', '#FF6E6E', '#69FF94', '#FFFFA5',
    '#D6ACFF', '#FF92DF', '#A4FFFF', '#FFFFFF',
  ],
};



