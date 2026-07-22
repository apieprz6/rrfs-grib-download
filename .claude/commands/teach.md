Teach the user a new skill or concept, within this workspace.

This is a stateful request - the user intends to learn the topic over multiple sessions.

## Teaching Workspace

Treat the current directory as a teaching workspace. The state of their learning is captured in:

- `MISSION.md`: The reason the user is interested in the topic.
- `./reference/*.html`: Compressed learnings — cheat sheets, reference algorithms, glossaries.
- `RESOURCES.md`: Resources to ground teaching in contextual knowledge.
- `./learning-records/*.md`: Records of what the user has learned (titled `0001-<dash-case-name>.md`).
- `./lessons/*.html`: Self-contained HTML lessons (titled `0001-<dash-case-name>.html`).
- `./assets/*`: Reusable components shared across lessons.
- `NOTES.md`: User preferences and working notes.

## Philosophy

To learn deeply, the user needs:

- **Knowledge** from high-quality, high-trust resources
- **Skills** acquired through interactive lessons
- **Wisdom** from real-world interaction

## Lessons

Each lesson is one self-contained HTML file. It should be **beautiful**, short, and completable quickly. Each gives the user a single tangible win tied to the mission, in their zone of proximal development.

Each lesson should:
- Link to other lessons and reference documents
- Recommend a primary source for the user to read
- Contain a reminder to ask followup questions

## The Mission

Every lesson should be tied to the mission. If `MISSION.md` is not populated, first question the user on why they want to learn this.

## Zone Of Proximal Development

Figure out the right thing to teach by reading learning records and fitting it to the mission.

What would you like to learn about? $ARGUMENTS
