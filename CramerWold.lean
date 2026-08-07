/-
Copyright (c) 2026 AletheAI Inc. All rights reserved.
Released under Apache 2.0 license.

# Cramér–Wold — locked statement

This file is the specification for the Problem Market task "Cramér–Wold theorem
in Lean". A submission closes the `sorry` below, keeping the statement verbatim.

The statement uses **only Mathlib**: `Measure`, `Measure.map` and
`IsProbabilityMeasure`. There are no definitions of ours to audit — the whole
trust surface is the theorem itself, which is why this is a good first board.
-/
import Mathlib.MeasureTheory.Measure.CharacteristicFunction.Basic
import Mathlib.MeasureTheory.Measure.ProbabilityMeasure

namespace CramerWold

open MeasureTheory Finset

variable {ι : Type*} [Fintype ι] [DecidableEq ι]

/-- **The Cramér–Wold theorem.**

Two probability measures on a finite product `ι → ℝ` are equal if they push
forward to the same measure under every linear functional
`x ↦ ∑ i, c i * x i`.

In words: a probability distribution on `ℝⁿ` is determined by the distributions
of all of its one-dimensional projections. -/
theorem cramerWold
    (ν₁ ν₂ : Measure (ι → ℝ))
    [IsProbabilityMeasure ν₁] [IsProbabilityMeasure ν₂]
    (h : ∀ c : ι → ℝ,
      ν₁.map (fun x => ∑ i : ι, c i * x i) =
      ν₂.map (fun x => ∑ i : ι, c i * x i)) :
    ν₁ = ν₂ := by
  sorry

end CramerWold
