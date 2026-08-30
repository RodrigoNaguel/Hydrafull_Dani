# HydraFuel Engineering Rules

## Primary Goal

Produce reliable, maintainable and minimal changes to this codebase.

Understand the existing implementation before modifying code.

Never assume an API, SDK behavior, Garmin Connect IQ capability or project convention without verifying it in the existing project or available documentation.

## Development Workflow

For any non-trivial task:

1. Use `architect` first to analyze the request.
2. Inspect the existing codebase before implementation.
3. Create a minimal implementation plan.
4. Implement only what is required.
5. Run the relevant build and tests.
6. Use `code-reviewer` for an independent review.
7. Fix all CRITICAL and HIGH findings.
8. Fix relevant MEDIUM findings.
9. Use `qa-tester` for final validation.
10. Only report completion after validation succeeds.

For very small and isolated changes, the architect step can be skipped.

## Architect

Use `architect` when the task involves:

- multiple files
- architecture
- Garmin Connect IQ lifecycle
- notifications
- background services
- persistence
- phone/watch communication
- settings
- permissions
- API changes
- refactoring
- new functionality

Architect must:

- inspect existing implementation
- identify affected files
- identify risks
- propose the smallest safe solution
- identify required tests

## Implementation Rules

Before creating new code:

- search for an existing implementation
- reuse existing helpers and abstractions
- follow current project conventions

Avoid:

- unnecessary rewrites
- duplicate logic
- speculative refactoring
- unrelated formatting changes
- introducing dependencies without justification

Never remove working behavior simply to simplify implementation.

## Garmin Connect IQ

This project uses Garmin Connect IQ / Monkey C.

Pay special attention to:

- API level compatibility
- device-specific behavior
- permissions
- background execution limitations
- notification behavior
- Application.Properties persistence
- temporal events
- phone communication
- memory limitations
- resource files
- manifest compatibility

Never assume behavior is identical between Garmin device models.

## Code Review

After implementation, delegate review to `code-reviewer`.

Reviewer must inspect:

- git diff
- modified files
- surrounding code
- logic correctness
- regression risks
- edge cases
- error handling
- lifecycle problems
- asynchronous behavior
- Garmin API compatibility
- security/privacy issues
- unnecessary complexity
- missing tests

Reviewer must not approve code simply because it compiles.

All CRITICAL and HIGH findings must be resolved before completion.

## QA

After review fixes, delegate validation to `qa-tester`.

QA should validate when applicable:

- project build
- Monkey C compilation
- tests
- device compatibility
- simulator behavior
- regression scenarios
- settings
- persistence
- notifications
- edge cases

Never claim a build or test passed unless it was actually executed.

## Git Safety

Never execute automatically:

git push --force
git reset --hard
git clean -fd
git checkout .
git restore .
git branch -D

Never overwrite unrelated user changes.

Never commit credentials, tokens or secrets.

## Definition of Done

A task is complete only when:

- requested behavior is implemented
- unrelated behavior is preserved
- relevant build/tests succeed
- independent code review is completed
- no unresolved CRITICAL/HIGH review issues remain
- QA validation is completed
