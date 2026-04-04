# Implementation Plan: Component Tests

**Branch**: `001-component-tests` | **Date**: 2026-01-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-component-tests/spec.md`

## Summary

Add component tests for the four main UI components: ConnectionCard, TerminalView, SpecialKeys, and SessionTabs. Use React Native Testing Library, reuse the existing `jest.config.js` and `jest.setup.js`, and place the test files in `__tests__/components/`.

## Technical Context

**Language/Version**: TypeScript 5.6+
**Primary Dependencies**: React Native 0.76.0, Expo ~52.0.0, React Native Testing Library
**Storage**: N/A (no persistence needed for a test feature)
**Testing**: Jest (jest-expo preset), React Native Testing Library, @testing-library/jest-native
**Target Platform**: Android (React Native)
**Project Type**: mobile
**Performance Goals**: N/A (test feature)
**Constraints**: Use the existing Jest configuration; `@expo/vector-icons` mocking is required
**Scale/Scope**: 4 components x 5 test cases = 20 test cases

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety | ✅ PASS | Test files are also written in TypeScript with type safety |
| II. KISS & YAGNI | ✅ PASS | Implement only the minimum necessary tests |
| III. Test-First (TDD) | ✅ PASS | The goal is to add tests and promote TDD |
| IV. Security-First | ✅ PASS | Use mocks in tests; do not use real credentials |
| V. SOLID | ✅ PASS | Each test file targets only a single component |
| VI. DRY | ✅ PASS | Share common mocks and helpers appropriately |
| Prohibited Naming | ✅ PASS | `__tests__/components/` follows standard Jest naming conventions |

**GATE RESULT**: ✅ ALL PASS - no violations

## Project Structure

### Documentation (this feature)

```text
specs/001-component-tests/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (minimal - test fixtures)
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
__tests__/
└── components/
    ├── ConnectionCard.test.tsx
    ├── TerminalView.test.tsx
    ├── SpecialKeys.test.tsx
    └── SessionTabs.test.tsx

src/
├── components/
│   ├── connection/
│   │   └── ConnectionCard.tsx      # test target
│   ├── terminal/
│   │   ├── TerminalView.tsx        # test target
│   │   └── SpecialKeys.tsx         # test target
│   └── navigation/
│       └── SessionTabs.tsx         # test target
└── types/
    ├── connection.ts               # mock data types used in tests
    ├── tmux.ts                     # mock data types used in tests
    └── terminal.ts                 # mock data types used in tests
```

**Structure Decision**: Follow the existing MuxPod project structure and place the test files in `__tests__/components/`. Conform to the `testMatch` pattern in `jest.config.js` (`**/__tests__/**/*.test.{ts,tsx}`).

## Complexity Tracking

> No violations - this section is empty

