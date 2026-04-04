# MuxPod

Android app (Flutter/Dart) for controlling tmux/psmux sessions on remote servers via SSH. Primary target is Android; iOS config exists but is not actively developed.

## Dev Commands

```bash
flutter run -d android   # Run on device/emulator
flutter analyze          # Static analysis — must pass before commit
flutter test             # Run unit tests
flutter build apk        # Build release APK
```

## Docs

- `docs/tmux-mobile-design-v2.md` — authoritative design doc
- `docs/ui-guidelines.md` — colors, spacing, layout rules
- `docs/muxpod-psmux-plan.md` — psmux backend integration plan
- `docs/screens/` — screen design references
- `docs/coding-conventions.md` — STALE (TypeScript/React from prior codebase), do not follow

## Architecture Rules

- **State:** flutter_riverpod — providers in `lib/providers/`
- **Mux abstraction:** `lib/services/mux/` — MuxBackend interface with TmuxBackend/PsmuxBackend. Never call tmux/psmux CLI directly; go through MuxBackend. MuxNode is the unified tree model for sessions/windows/panes
- **Terminal:** xterm.dart widget with real-time PTY streams (`MuxPtySession`), not polling. The old ANSI parser/polling system was removed
- **SSH:** dartssh2 via `lib/services/ssh/`. Dedicated input shell for non-blocking keystroke sending
- **Deep linking:** `muxpod://` URL scheme — handled in `lib/services/deep_link/`
- **Security:** SSH keys and passwords via flutter_secure_storage (encrypted). Never log credentials. Shell-escape all user input sent to remote commands

## Working Rules

- Commit messages: conventional commits (`feat:`, `fix:`, `perf:`, `chore:`). No Co-Authored-By lines
- Run `flutter analyze` before considering work complete
- Tests exist for mux backends, widgets, and services in `test/` — run `flutter test` after changes to those areas

## Gotchas

- `terminal_screen.dart` is ~2800 lines — the largest file in the codebase. Tread carefully
- psmux has different CLI flags than tmux — see PsmuxBackend for compatibility handling
- PTY stream attach timing matters: psmux needs prompt-wait before sending commands
- RAW input mode bypasses IME for direct keystroke passthrough — uses hidden TextField with sentinel backspace
- Windows dev environment: use `git -C <path>` or absolute paths, not `cd`
