Configure this repo for the engineering skills — set up its issue tracker, triage label vocabulary, and domain doc layout. Run once before first use of the other engineering skills.

## Process

### 1. Explore

Look at the current repo to understand its starting state:

- `git remote -v` and `.git/config` — is this a GitHub repo?
- `AGENTS.md` and `CLAUDE.md` at the repo root
- `CONTEXT.md` and `CONTEXT-MAP.md` at the repo root
- `docs/adr/` and any `src/*/docs/adr/` directories
- `docs/agents/` — does prior output already exist?

### 2. Present findings and ask

Walk the user through three decisions **one at a time**:

**Section A — Issue tracker.**
- **GitHub** — issues live in the repo's GitHub Issues (uses `gh` CLI)
- **GitLab** — issues live in the repo's GitLab Issues (uses `glab` CLI)
- **Local markdown** — issues live as files under `.scratch/<feature>/`
- **Other** (Jira, Linear, etc.) — ask the user to describe the workflow

If GitHub/GitLab: ask about PRs as a request surface (yes/no, default no).

**Section B — Triage label vocabulary.**
Five canonical roles: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. Ask if the user wants to override any.

**Section C — Domain docs.**
- **Single-context** — one `CONTEXT.md` + `docs/adr/` at the repo root
- **Multi-context** — `CONTEXT-MAP.md` at the root pointing to per-context files

### 3. Confirm and edit

Show the user a draft of the `## Agent skills` block and `docs/agents/*.md` files. Let them edit before writing.

### 4. Write

Pick `CLAUDE.md` or `AGENTS.md` (whichever exists). Write the agent skills block and the three docs files.

### 5. Done

Tell the user the setup is complete and which skills will now read from these files.

$ARGUMENTS
