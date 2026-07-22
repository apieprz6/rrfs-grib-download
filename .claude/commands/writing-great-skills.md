Reference for writing and editing skills well — the vocabulary and principles that make a skill predictable.

A skill exists to wrangle determinism out of a stochastic system. **Predictability** — the agent taking the same _process_ every run, not producing the same output — is the root virtue.

## Invocation

- A **model-invoked** skill keeps a description so the agent can fire it autonomously. It contributes to context load.
- A **user-invoked** skill strips the description: only typing its name can invoke it. Zero context load, but spends cognitive load.

## Writing the description

- Front-load the skill's leading word
- One trigger per branch — collapse synonyms
- Cut identity that's already in the body

## Information hierarchy

1. **In-skill step** — an ordered action, the primary tier
2. **In-skill reference** — a definition, rule, or fact consulted on demand
3. **External reference** — pushed out into a separate file, loaded via context pointer

## When to split

- **By invocation** — when you have a distinct leading word that should trigger independently
- **By sequence** — when post-completion steps tempt premature completion

## Pruning

- Keep each meaning in a single source of truth
- Check every line for relevance
- Hunt no-ops sentence by sentence

## Leading words

A leading word is a compact concept from the model's pretraining that anchors behavior in the fewest tokens. Hunt for opportunities to refactor skills to use them.

## Failure modes

- **Premature completion** — ending a step before it's genuinely done
- **Duplication** — the same meaning in more than one place
- **Sediment** — stale layers that settle because removing feels risky
- **Sprawl** — a skill simply too long
- **No-op** — a line the model already obeys by default

$ARGUMENTS
