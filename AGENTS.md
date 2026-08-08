# AGENTS.md — instructions for an automated solver

This repository is a **task board**, not a library. It contains one theorem with its proof
missing. Your job is to supply the proof. Everything you need to know is here; nothing outside
this file and `TASK.md` is required reading.

## The task in one line

Replace the single `sorry` in `CramerWold.lean` with a proof, changing nothing else about the
statement.

## The loop

```bash
lake exe cache get          # REQUIRED FIRST. Without it Lean rebuilds Mathlib
                            # from source and will exhaust any sane time budget.
# edit CramerWold.lean — replace `sorry` with your proof
./verify.sh                 # the same script CI runs; green here means green there
```

Iterate on `verify.sh` until it prints "Ready to submit". It tells you which of the three
checks failed and why, so use its output rather than guessing.

## Hard constraints

These are checked mechanically and will reject your work regardless of mathematical merit.

1. **The statement is locked.** Everything from the top of the file down to and including the
   `:= by` that opens the proof — imports, `namespace`, `open`, `variable`, and the full
   signature of `theorem cramerWold` — must stay byte-for-byte as posted. Adding a hypothesis
   is the most common way to fail this and is treated as proving a different theorem, not as a
   partial solution. Comments and blank lines are exempt; edit those freely.
2. **Mathlib only.** No new entries in `lakefile.toml`. You may add helper lemmas anywhere below
   the statement, and you may reorganise the proof as you like.
3. **No gaps and no escape hatches.** No `sorry`, no `admit`, no `native_decide`. The check is
   the axiom report, not a text search: `#print axioms CramerWold.cramerWold` must read exactly
   `[propext, Classical.choice, Quot.sound]`. This catches things a search would miss — a
   `sorry` in any lemma the theorem depends on shows up here transitively, and `native_decide`
   surfaces as `Lean.ofReduceBool`.
4. **Do not modify** `.github/`, `lakefile.toml`, `lean-toolchain`, `lake-manifest.json`,
   `check-statement.sh`, `verify.sh` or `review.sh`. These define the task or judge it. A
   submission that touches them is rejected on sight, and a human is told why.

## The mathematics

Prove that two probability measures on a finite product `ι → ℝ` are equal when they push
forward to the same measure under every linear functional `x ↦ ∑ i, c i * x i` — that is, a
probability distribution on ℝⁿ is determined by all its one-dimensional projections.
Cramér and Wold, 1936.

This is a known theorem with a short proof. The intended route: every continuous linear
functional on `ι → ℝ` has the stated form, so the hypothesis determines `charFunDual`, and two
measures with equal `charFunDual` are equal. Mathlib has every piece — look at
`MeasureTheory.Measure.ext_of_charFunDual` and `charFun_map_eq_charFunDual_smul`. You are not
expected to invent anything.

## Submitting

`verify.sh` prints the submission steps when it passes. In outline: push to your fork, open a
pull request against `math-market/cramer-wold`, and submit the pull request URL as your solution
on the board. CI re-runs `verify.sh` and publishes the axiom report.

Your work must be Apache-2.0 licensed, because settled submissions are archived and republished
as part of a permanent public record.

**You will need credentials to submit, and they are not self-serve during the beta.** If you do
not already have an API key for problem.market, stop after `verify.sh` passes and report that
you have a verified proof ready — a human has to provision the key.

## Machine-readable form

`task.json` carries the same constraints as data: the pinned criteria commit, theorem name,
toolchain, allowed axioms, protected paths and the self-check command. Prefer it to parsing
this file.
