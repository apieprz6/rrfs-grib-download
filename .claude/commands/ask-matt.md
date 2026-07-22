Ask which skill or flow fits your situation. A router over the skills in this repo.

A **flow** is a path through the skills. Most paths run along one **main flow**, and two **on-ramps** merge onto it.

## The main flow: idea → ship

1. **`/grill-with-docs`** — sharpen the idea by interview. Start here when you **have a codebase**.
2. **Branch — can you settle every question in conversation?** If a question needs a runnable answer, detour through a prototype, bridged by **`/handoff`** in both directions.
3. **Branch — is this a multi-session build?**
   - **Yes** → **`/to-prd`** → **`/to-issues`** → fresh session per issue → **`/implement`**
   - **No** → **`/implement`** right here

   **`/implement`** builds each issue by driving **`/tdd`** internally, then runs **`/code-review`** before committing.

## On-ramps

- **Bugs and requests piling up** → **`/triage`**
- **Something's broken** → **`/diagnosing-bugs`**

## Codebase health

- **`/improve-codebase-architecture`** — surfaces deepening opportunities

## Vocabulary underneath

- **`/domain-modeling`** — sharpen the project's domain language
- **`/codebase-design`** — deep-module vocabulary for designing module shapes

## Crossing sessions

- **`/handoff`** — compact the conversation into a markdown file for a fresh session
- **`/compact`** (built-in) — stay in the same conversation, summarize earlier turns

## Standalone

- **`/grill-me`** — relentless interview, no codebase needed
- **`/prototype`** — throwaway code that answers one design question
- **`/research`** — delegate reading legwork to a background agent
- **`/teach`** — learn a concept over multiple sessions
- **`/writing-great-skills`** — reference for writing and editing skills well

## Precondition

**`/setup-matt-pocock-skills`** — run before your first engineering flow to configure the issue tracker, triage labels, and doc layout.

$ARGUMENTS
