Break a plan, spec, or PRD into independently-grabbable issues on the project issue tracker using tracer-bullet vertical slices.

# To Issues

Break a plan into independently-grabbable issues using vertical slices (tracer bullets).

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes an issue reference as an argument, fetch it from the issue tracker.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state. Issue titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs.

Look for opportunities to prefactor the code to make the implementation easier.

### 3. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Any prefactoring should be done first

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Blocked by**: which other slices must complete first
- **User stories covered**: which user stories this addresses

Ask the user if the granularity feels right and iterate until approved.

### 5. Publish the issues to the issue tracker

For each approved slice, publish a new issue using this template:

```
## Parent

A reference to the parent issue (if applicable).

## What to build

A concise description of this vertical slice — end-to-end behavior, not layer-by-layer.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- A reference to blocking tickets (if any)
```

Publish issues in dependency order (blockers first).

$ARGUMENTS
