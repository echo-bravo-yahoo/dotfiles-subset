# Testing Changes

After making code changes, run applicable test suites in this order:

1. **Formatting** (if repo has formatter config): `prettier`, `biome format`, `cargo fmt`, etc.
2. **Linting** (if repo has linter config): `eslint`, `biome lint`, `tsc --noEmit`, `cargo clippy`, etc.
3. **Unit tests**: Scope to files/modules affected by the change
4. **Integration tests**: Scope to features touched by the change
5. **E2E tests**: Scope to workflows affected by the change

## Scoping rules

- Run only the subset of a test suite that covers the changes made
- Skip a test suite entirely if no tests cover the changed code
- When unsure what tests exist, explore the test directory structure first

## Test authoring workflow

When implementing a feature or fixing a bug, follow this order:

1. **Determine the testing strategy.** Read the project's CLAUDE.md or `test/` directory to understand the repo's test framework, helpers, and conventions. Match the style of existing tests.
2. **Write tests first.** Write behavioral tests that describe the expected outcome — both for new features and for regressions. Do not write implementation code yet.
3. **Place tests intentionally.** Add new test cases to an existing test file if they logically belong with its scope. Create a new test file only when the behavior doesn't fit any existing file.
4. **Verify tests fail (red).** Run the new tests and confirm they fail for the right reason (missing feature / unfixed bug). If they pass, the change may already be implemented — undo the implementation, keep the tests, then re-apply the change after confirming the red state.
5. **Implement the change (green).** Write the minimal code to make the failing tests pass.
6. **Verify tests pass.** Run the new tests and the surrounding test suite to confirm nothing is broken.
