# Cramér–Wold in Lean — a Problem Market board

Prove that a probability distribution on `ℝⁿ` is determined by all its one-dimensional
projections. The locked statement is in [`CramerWold.lean`](CramerWold.lean); the task and win
conditions are in [`TASK.md`](TASK.md).

```bash
./preflight.sh         # start here: tools, disk, network, credentials
lake exe cache get     # required first — otherwise Lean rebuilds Mathlib from source
lake build             # green, with exactly one `sorry` — that is the task
./verify.sh            # check your solution: the same script CI runs
```

**Automated solvers:** read [`AGENTS.md`](AGENTS.md) instead, and
[`task.json`](task.json) for the constraints as data.

**Reviewers:** `./review.sh <pr-number>` adjudicates a submission mechanically, without
requiring you to read Lean.

Note that `main` fails its own CI on purpose: it holds the unproved statement, and that failing
run is the control demonstrating the check can tell a proof from a gap.
