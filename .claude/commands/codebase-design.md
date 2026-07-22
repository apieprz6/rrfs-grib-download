Shared vocabulary for designing deep modules. Use when you want to design or improve a module's interface, find deepening opportunities, decide where a seam goes, or make code more testable or AI-navigable.

# Codebase Design

Design **deep modules**: a lot of behaviour behind a small interface, placed at a clean seam, testable through that interface.

## Glossary

Use these terms exactly — don't substitute "component," "service," "API," or "boundary."

**Module** — anything with an interface and an implementation. Scale-agnostic: a function, class, package, or tier-spanning slice.

**Interface** — everything a caller must know to use the module correctly: type signature, invariants, ordering constraints, error modes, required configuration, and performance characteristics.

**Implementation** — what's inside a module. Distinct from **Adapter**: a thing can be a small adapter with a large implementation or vice versa.

**Depth** — leverage at the interface: the amount of behaviour a caller can exercise per unit of interface they have to learn. **Deep** = large behaviour behind small interface. **Shallow** = interface nearly as complex as implementation.

**Seam** _(Michael Feathers)_ — a place where you can alter behaviour without editing in that place; the *location* at which a module's interface lives.

**Adapter** — a concrete thing that satisfies an interface at a seam. Describes *role*, not substance.

**Leverage** — what callers get from depth: more capability per unit of interface they learn.

**Locality** — what maintainers get from depth: change, bugs, knowledge, and verification concentrate in one place.

## Deep vs shallow

**Deep module** = small interface + lots of implementation:

```
┌─────────────────────┐
│   Small Interface   │  ← Few methods, simple params
├─────────────────────┤
│                     │
│  Deep Implementation│  ← Complex logic hidden
│                     │
└─────────────────────┘
```

**Shallow module** = large interface + little implementation (avoid):

```
┌─────────────────────────────────┐
│       Large Interface           │  ← Many methods, complex params
├─────────────────────────────────┤
│  Thin Implementation            │  ← Just passes through
└─────────────────────────────────┘
```

## Principles

- **Depth is a property of the interface, not the implementation.**
- **The deletion test.** Imagine deleting the module. If complexity reappears across N callers, it was earning its keep.
- **The interface is the test surface.** Callers and tests cross the same seam.
- **One adapter means a hypothetical seam. Two adapters means a real one.**

## Designing for testability

1. **Accept dependencies, don't create them.**
2. **Return results, don't produce side effects.**
3. **Small surface area.** Fewer methods = fewer tests needed.

$ARGUMENTS
