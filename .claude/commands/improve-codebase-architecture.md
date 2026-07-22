Scan a codebase for deepening opportunities, present them as a visual HTML report, then grill through whichever one you pick.

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities** — refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

This command is informed by the project's domain model and built on a shared design vocabulary:

- Use the `/codebase-design` vocabulary (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) and its principles. Use these terms exactly.
- The domain language in `CONTEXT.md` gives names to good seams; ADRs in `docs/adr/` record decisions this command should not re-litigate.

## Process

### 1. Explore

Read the project's domain glossary (`CONTEXT.md`) and any ADRs first.

Then use the Agent tool with `subagent_type=Explore` to walk the codebase. Note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test**: would deleting it concentrate complexity, or just move it?

### 2. Present candidates as an HTML report

Write a self-contained HTML file to the OS temp directory. Use Tailwind via CDN for layout and Mermaid via CDN for diagrams. Open it for the user.

For each candidate, render a card with:

- **Files** — which files/modules are involved
- **Problem** — why the current architecture is causing friction
- **Solution** — plain English description of what would change
- **Benefits** — explained in terms of locality and leverage
- **Before / After diagram** — side-by-side
- **Recommendation strength** — `Strong`, `Worth exploring`, or `Speculative`

End with a **Top recommendation** section.

Do NOT propose interfaces yet. Ask the user: "Which of these would you like to explore?"

### 3. Grilling loop

Once the user picks a candidate, run the `/grilling` skill to walk the design tree with them.

Side effects happen inline as decisions crystallize — run `/domain-modeling` to keep the domain model current.

$ARGUMENTS
