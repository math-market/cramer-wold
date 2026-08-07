# Task — The Cramér–Wold theorem in Lean

*Proof-tier board. The checker is CI: `lake build` against the pinned Mathlib, plus an axiom
audit. Package: `TASK.md` · `CramerWold.lean` (the locked statement) · `lakefile.toml` and
`lean-toolchain` (the pin) · `.github/workflows/verify.yml`.*

---

## The problem

Prove the **Cramér–Wold theorem**: two probability measures on a finite product `ι → ℝ` are
equal if they push forward to the same measure under every linear functional
`x ↦ ∑ i, c i * x i`.

In words: *a probability distribution on ℝⁿ is determined by the distributions of all its
one-dimensional projections.* It is the standard device for reducing multivariate convergence
and identification questions to the one-dimensional case, and it underlies the multivariate
central limit theorem.

Cramér and Wold, 1936.

## The locked statement

```lean
theorem cramerWold
    (ν₁ ν₂ : Measure (ι → ℝ))
    [IsProbabilityMeasure ν₁] [IsProbabilityMeasure ν₂]
    (h : ∀ c : ι → ℝ,
      ν₁.map (fun x => ∑ i : ι, c i * x i) =
      ν₂.map (fun x => ∑ i : ι, c i * x i)) :
    ν₁ = ν₂
```

**The statement uses only Mathlib** — `Measure`, `Measure.map`, `IsProbabilityMeasure`. There
are no definitions of ours to audit, so the faithfulness question reduces to reading five lines
against the textbook statement. That is unusual, and deliberate: this board is a calibration of
the verification pipeline as much as a mathematical target.

## Win condition (locked)

1. Close the `sorry` in `CramerWold.lean`, keeping the statement **verbatim**.
2. Sorry-free — no `sorry`, no `admit`, no `native_decide`.
3. Axiom-clean — `#print axioms CramerWold.cramerWold` reports only `propext`,
   `Classical.choice`, `Quot.sound`. `sorryAx` is caught transitively.
4. `lake build` green against the pinned toolchain and Mathlib revision.
5. **Mathlib only.** A proof may reorganise the file and add helper lemmas, but must not add
   dependencies beyond Mathlib. This is what makes the result portable and the check cheap to
   reproduce.

## How to submit

Fork, close the sorry, open a pull request, and submit the PR link as your solution. CI runs the
identical build and audit and publishes the axiom report.

## A note on difficulty

This is a **known theorem with a short proof** — the intended route goes through characteristic
functions: every continuous linear functional on `ι → ℝ` has the stated form, so the hypothesis
determines `charFunDual`, and measures with equal `charFunDual` are equal. Mathlib has all the
pieces. It is posted at a modest prize because the work is bounded and the outcome is not in
doubt; the value is a machine-checked, citable statement of a classical result.

## Sourcing

Cramér–Wold is classical and not owned by anyone. Do not copy Lean source except per its
licence; this repository is Apache-2.0, as Mathlib is.
