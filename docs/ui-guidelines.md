# MuxPod UI/UX Guidelines

## Color Palette

Based on Material Design 3 Dark Theme.

| Purpose | Color | Description |
|---------|-------|-------------|
| Background | `#1E1E1E` | Main background |
| Surface | `#2D3133` | Cards, containers |
| Primary | `#00C0D1` | Accent, buttons, active state |
| Text | `#FFFFFF` | Primary text |
| Text (sub) | `#9E9E9E` | Secondary text |
| Error | `#CF6679` | Error state |
| Success | `#4CAF50` | Connected, etc. |

## Design Tokens

### Border Radius
- Cards/Containers: `40px` (MD3 style)
- Buttons: `20px`
- Inputs: `12px`
- Indicators (pill): `10px`

### Spacing
- xs: `4px`
- sm: `8px`
- md: `16px`
- lg: `24px`
- xl: `32px`

## Screen Layout

### Bottom Navigation

| Icon | Label | Screen |
|------|-------|--------|
| Server | Net | Connection list |
| Terminal | Term | Terminal display |
| Key | Keys | SSH key management |
| Gear | Settings | Settings |

### Connection List (Net)
- Connection cards are expandable
- Session list displayed as tree
- Attached/Detached status badges
- "+ New Session" button

### Terminal (Term)
- Top: Session/Window/Pane tabs
- Center: Terminal output
- Bottom: Special key bar (ESC/TAB/CTRL/ALT)
- Very bottom: Input field + cmd button

### Notification Rule Settings
- Active rule list
- Rule add form
- Condition types: TEXT/REGEX/IDLE/ANY
- Pattern test feature

## Fonts

| Purpose | Font |
|---------|------|
| Terminal (English) | JetBrainsMono, FiraCode |
| Terminal (Japanese) | HackGen, PlemolJP |
| UI | System font |

## Foldable Device Support

- Left panel: Session tree
- Right panel: Terminal display
- Portrait mode: Normal single column

## Icons

- Use Material Icons or Lucide Icons
- Connection state: Green circle (connected), Gray circle (disconnected), Red circle (error)

## Logo

See `docs/logo/logo.svg`.
