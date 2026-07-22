Turn the current conversation into a PRD and publish it to the project issue tracker — no interview, just synthesis of what you've already discussed.

## Process

1. Explore the repo to understand the current state, if you haven't already. Use the project's domain glossary vocabulary throughout, and respect any ADRs.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Check with the user that these seams match their expectations.

3. Write the PRD using the template below, then publish it to the project issue tracker.

## PRD Template

### Problem Statement

The problem from the user's perspective.

### Solution

The solution from the user's perspective.

### User Stories

A LONG, numbered list of user stories:

1. As an <actor>, I want a <feature>, so that <benefit>

This list should be extremely extensive and cover all aspects of the feature.

### Implementation Decisions

- Modules to build/modify
- Interfaces to modify
- Technical clarifications
- Architectural decisions
- Schema changes
- API contracts

Do NOT include specific file paths or code snippets (they go stale fast). Exception: prototype snippets that encode a decision more precisely than prose.

### Testing Decisions

- What makes a good test (only test external behavior)
- Which modules will be tested
- Prior art for the tests

### Out of Scope

What is explicitly out of scope.

### Further Notes

Any additional context.

$ARGUMENTS
