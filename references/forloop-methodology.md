# ForLoop Planning Methodology

ForLoop runs **Loop Engineering**: Plan → Code → Review → Deploy → Learn. You own
the Plan phase; ForLoop agents (Developer, Tester, Devops, Creator) own the rest.
Knowledge captured now feeds the next loop.

## Space design

A well-designed space has:

- One-sentence objective — what this space achieves
- Explicit scope: what is in, and what is out
- Realistic capacity — see multipliers below
- Measurable outcomes — every story has verifiable acceptance criteria
- Documented dependencies — what must happen first

### Capacity multipliers

| Strategy | Multiplier | When |
|----------|-----------|------|
| Conservative | 60% | New team, unclear requirements, high uncertainty |
| Standard | 80% | Established context, moderate clarity |
| Aggressive | 100% | Clear requirements, low risk |

Available time = space duration × number of agents. Example: a 2-week space with
3 agents at standard capacity is roughly 4.8 agent-weeks of work.

### Anti-patterns

| Anti-pattern | Fix |
|--------------|-----|
| No objective | Write the one-sentence objective first |
| Overfilled space | Apply the capacity multiplier |
| Everything high priority | Max ~30% high/critical |
| No dependencies | List prerequisite stories explicitly |
| Many 1-point stories | Merge related work into 2–3 point stories |
| One 10+ point story | Split into deliverable slices |

## Story sizing

Use Fibonacci points: 1, 2, 3, 5, 8. Split anything above 8 (the CLI accepts
0–10 but a 10 is a smell). Judge four dimensions:

| Dimension | Question |
|-----------|----------|
| Complexity | How hard is the problem? |
| Uncertainty | How much is unknown? |
| Effort | How many files/systems change? |
| Verification | How hard is it to prove done? |

A good story is independently completable in one agent session, has a single
deliverable, and its acceptance criteria are checkable without reading code.

## Agent assignment

| Work type | `--type` | `--assignee-agent` |
|-----------|----------|---------------------|
| Code implementation, features, bug fixes | `basic-task` | `forLoopDeveloper` |
| Tests, QA, validation | `basic-task` | `forLoopTester` |
| Deployment, infrastructure, CI/CD | `basic-task` | `forLoopDevops` |
| File/media generation (DOCX, PDF, XLSX, PPTX, images, video) | `basic-task` | `forLoopCreator` |
| Documentation, decisions, notes | `basic-note` | (none) |
| Document folder (S3 organization) | (omit `--type`) | (none) |

Rules:

- One agent per story. Split cross-agent work into separate stories.
- Creator + Developer is always two stories: generate the asset, then integrate it.
- Testing is separate from implementation.
- DevOps stories usually depend on implementation stories.

## Knowledge capture standard

Every session should leave behind knowledge notes that answer:

- What was decided, and why
- What constraints or non-goals were agreed
- What remains open or risky

Knowledge lives in `~/.forloop/sprint-<id>/knowledge/` and is uploaded to
`project/knowledge` linked to the doc folder. Capture immediately — sessions are
ephemeral; only uploaded state survives.
