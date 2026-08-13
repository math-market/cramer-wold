/-
Copyright (c) 2026 AletheAI Inc. All rights reserved.
Released under Apache 2.0 license.

# Cramér–Wold — locked statement

This file is the specification for the Problem Market task "Cramér–Wold theorem
in Lean". The statement is kept verbatim from the locked specification; only the proof is added.

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
  -- Every continuous linear functional on `ι → ℝ` has the form `x ↦ ∑ i, c i * x i`,
  -- so the hypothesis covers all of them.
  have hmap : ∀ L : (ι → ℝ) →L[ℝ] ℝ, ν₁.map ⇑L = ν₂.map ⇑L := by
    intro L
    have hL : (⇑L : (ι → ℝ) → ℝ) = fun x => ∑ i : ι, L (Pi.single i 1) * x i := by
      ext x
      conv_lhs => rw [pi_eq_sum_univ' x]
      rw [map_sum]
      congr 1; ext i
      rw [map_smul, smul_eq_mul, mul_comm]
    rw [hL]
    exact h _
  -- Equal pushforwards give equal `charFunDual`, and that determines the measure.
  apply Measure.ext_of_charFunDual
  ext L
  rw [show charFunDual ν₁ L = charFun (ν₁.map ⇑L) 1 from by
        rw [charFun_map_eq_charFunDual_smul, one_smul],
      show charFunDual ν₂ L = charFun (ν₂.map ⇑L) 1 from by
        rw [charFun_map_eq_charFunDual_smul, one_smul],
      hmap L]

end CramerWold
