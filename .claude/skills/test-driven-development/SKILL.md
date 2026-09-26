---
name: test-driven-development
description: iOS 適配版 TDD 行為約束。Iron Law：沒有 failing test 就不准寫 production code。適用新功能和 bugfix 開發階段。
---

# Test-Driven Development (iOS)

## Iron Law

**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.**

If you didn't watch the test fail, you don't know if it tests the right thing.

## When to Apply

**Always apply to:**
- New ViewModel methods
- New Service methods
- Bug fixes (write test reproducing bug first)
- Data transformation / mapping logic
- Validation logic

**Exceptions (require human approval):**
- Pure UI adjustments (color, spacing, font changes)
- Third-party SDK wrappers
- Configuration / plist changes
- Generated code (e.g., Xcode templates, code generators)

## RED → GREEN → REFACTOR

### RED: Write a Failing Test

Write ONE minimal test that demonstrates the desired behavior.

**iOS patterns:**

| What you're building | Test-first approach |
|---------------------|---------------------|
| ViewModel method | Write Input → expected Output test. Assert on publisher values. |
| Service method | Write mock API response → expected domain model. Assert mapping. |
| Bug fix | Write test that reproduces the exact bug symptom. |
| Snapshot test | Create empty/stub view, run snapshot — it fails because UI is empty. |

```swift
// Example: ViewModel TDD
func test_login_withValidCredentials_shouldEmitSuccess() {
    // Given
    let mockService = MockAuthService()
    mockService.mockResult = .success(User(name: "test"))
    let vm = LoginViewModel(authService: mockService)

    // When
    vm.inputs.login(email: "test@example.com", password: "pass")

    // Then — THIS MUST FAIL because LoginViewModel doesn't exist yet
    XCTAssertEqual(vm.outputs.loginState.value, .success)
}
```

### Verify RED (Mandatory)

Run the test. Confirm:
- [ ] Test **fails** (not errors — compilation errors mean test is wrong)
- [ ] Failure message matches expectation
- [ ] Failure is because the feature is **missing**, not because the test is broken

### GREEN: Write Minimal Production Code

Write the **simplest** code that makes the test pass. Nothing more.

- No unrequested features
- No "while I'm here" improvements
- No premature optimization

### Verify GREEN (Mandatory)

- [ ] New test passes
- [ ] All existing tests still pass
- [ ] No warnings or errors

### REFACTOR

Only after green:
- Remove duplication
- Improve naming
- Extract helpers
- Keep all tests green throughout

## Red Flags — Restart Required

If any of these happen, **delete the production code and start over from RED**:

- Wrote production code before the test
- Test passes immediately on first run (never failed)
- Can't explain why the test failed
- Wrote multiple features before running tests
- "I'll add the test after" — no. Now.
- "Too simple to need a test" — simple code breaks too

## Common Rationalizations (All Rejected)

| Excuse | Response |
|--------|----------|
| "I'll test after" | Tests written after prove what code does, not what it should do |
| "Too simple to test" | Simple code breaks. Testing it takes 30 seconds. |
| "I already know it works" | Then the test will pass quickly. Write it anyway. |
| "TDD slows me down" | Debugging untested code slows you down more |
| "Existing code doesn't have tests" | That's technical debt, not permission to add more |

## Bug Fix TDD

1. **RED**: Write test reproducing the exact bug
2. **Verify RED**: Test fails showing the bug exists
3. **GREEN**: Fix the bug with minimal change
4. **Verify GREEN**: Test passes, all other tests pass
5. **REFACTOR**: Clean up if needed

## Integration with Project

- References `rules/testing.md` for snapshot environment (iPhone 14 Pro, iOS 17.2, EN)
- References `skills/testing-best-practices/` for test naming and coverage targets
- `@testing-expert` agent should enforce TDD flow when guiding test writing
