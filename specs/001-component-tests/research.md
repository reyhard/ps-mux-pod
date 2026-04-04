# Research: Component Tests

**Date**: 2026-01-10
**Branch**: `001-component-tests`

## Research Summary

Summarize the technical research needed to implement the component tests.

---

## 1. React Native Testing Library Best Practices

### Decision
Use `@testing-library/react-native` to write user-focused tests.

### Rationale
- Follow Testing Library's philosophy of testing behavior rather than implementation details
- Simulate user actions with `getByText`, `getByTestId`, and `fireEvent`
- Prefer accessibility-focused queries such as `getByRole` and `getByLabelText`

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| Enzyme | Incomplete React 18+ support, maintenance has stalled |
| react-test-renderer | Too low-level, event handling is difficult |

---

## 2. @expo/vector-icons Mock Strategy

### Decision
Use `jest.mock('@expo/vector-icons')` to replace icon components with dummies.

### Rationale
- Icon rendering itself is out of scope for testing because it is a visual concern
- Avoid native module work to speed up test execution
- Mock both `MaterialCommunityIcons` and `MaterialIcons`

### Implementation Pattern
```typescript
jest.mock('@expo/vector-icons', () => ({
  MaterialCommunityIcons: 'MaterialCommunityIcons',
  MaterialIcons: 'MaterialIcons',
}));
```

---

## 3. Pressable Component Test Pattern

### Decision
Use `fireEvent.press` to verify callback invocation.

### Rationale
- React Native `Pressable` handles interaction through `onPress`
- `fireEvent.press` is the most direct and reliable approach
- Disabled-state verification is also possible

### Testing Pattern
```typescript
const onPress = jest.fn();
render(<Component onPress={onPress} />);
fireEvent.press(screen.getByTestId('button'));
expect(onPress).toHaveBeenCalledTimes(1);
```

---

## 4. FlatList/ScrollView Test Pattern

### Decision
Take `initialNumToRender` into account and test only the elements that are actually rendered.

### Rationale
- `FlatList` does not render every item because of performance optimization
- Use a small amount of data in tests, typically 5 to 10 items, to ensure all items are rendered
- Scrolling behavior itself is the responsibility of the native layer

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| Full data mock | Large data sets affect test runtime |
| Triggering scroll events | Simulating native behavior is unstable |

---

## 5. State Change Test Pattern

### Decision
Check state changes after `rerender` or `fireEvent`.

### Rationale
- CTRL/ALT mode switching in SpecialKeys is internal component state
- Verify style changes after `fireEvent` to confirm the active state
- Handle asynchronous state updates with `waitFor`

### Testing Pattern
```typescript
// CTRL mode toggle
fireEvent.press(screen.getByText('CTRL'));
// After press, button should show active state
expect(screen.getByText('CTRL')).toHaveStyle({ backgroundColor: colors.primary });
```

---

## 6. Test Data (Fixtures) Design

### Decision
Define mock data inside each test file and extract shared data into a common file when needed.

### Rationale
- Keep each file independent and simple in the initial stage
- Consolidate after duplication appears three or more times (Rule of Three)
- Reflect the real data structure with type-safe mock data

### Mock Data Examples
```typescript
// Connection mock
const mockConnection: Connection = {
  id: 'test-id',
  name: 'Test Server',
  host: 'example.com',
  port: 22,
  username: 'testuser',
  authMethod: 'password',
  timeout: 30,
  keepAliveInterval: 60,
  createdAt: Date.now(),
  updatedAt: Date.now(),
};

// TmuxSession mock
const mockSession: TmuxSession = {
  name: 'main',
  created: Date.now(),
  attached: true,
  windowCount: 2,
  windows: [],
};
```

---

## Unresolved Items

None - all technical questions have been resolved.
