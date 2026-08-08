#!/usr/bin/env bash
# verify.sh — check your solution before you submit it.
#
# This is the same script CI runs. Not an equivalent one, the same one: if it
# says PASS here, the build on our side will agree, and if it says FAIL you know
# why before you have spent a submission finding out.
#
#   ./verify.sh
#
# Requires elan (https://lean-lang.org/install) and python3. The first run
# downloads the Mathlib build cache and takes a few minutes; later runs are fast.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

THEOREM="CramerWold.cramerWold"
SPEC="CramerWold.lean"
ALLOWED='[propext, Classical.choice, Quot.sound]'
EXPECTED="'$THEOREM' depends on axioms: $ALLOWED"

step() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
no()   { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; }
hint() { printf '        %s\n' "$1"; }

# ---------------------------------------------------------------------- 1/3
step "1/3  Is the statement still the one that was posted?"
if out=$(./check-statement.sh 2>&1); then
  ok "statement identical to the pinned criteria commit"
else
  no "the statement has changed"
  sed 's/^/        /' <<<"$out"
  hint ""
  hint "The theorem, its hypotheses and the imports must stay verbatim. You may"
  hint "reorganise the proof and add helper lemmas below the statement, but"
  hint "changing the statement — even adding a hypothesis — means proving a"
  hint "different theorem, and will be rejected. Comments you may edit freely."
  exit 1
fi

# ---------------------------------------------------------------------- 2/3
step "2/3  Does it build against the pinned toolchain and Mathlib?"
hint "(first run downloads the Mathlib cache — a few minutes, and ~7.4 GB on disk)"
# Deliberately not silenced: this is the longest step in the loop, and a script
# that prints nothing for five minutes is indistinguishable from a hung one.
if ! lake exe cache get; then
  no "could not fetch the Mathlib build cache"
  hint "Without it, Lean rebuilds Mathlib from source, which takes hours."
  hint "Check your network, then retry:  lake exe cache get"
  exit 1
fi
if build=$(lake build 2>&1); then
  ok "lake build succeeded"
else
  no "lake build failed"
  tail -30 <<<"$build" | sed 's/^/        /'
  exit 1
fi

# ---------------------------------------------------------------------- 3/3
step "3/3  What does the finished proof rest on?"
cat > Audit.lean <<AUDIT
import CramerWold
#print axioms $THEOREM
AUDIT
lake env lean Audit.lean > axiom-report.txt 2>&1
rm -f Audit.lean
actual=$(grep "depends on axioms" axiom-report.txt | head -1)
hint "${actual:-<no axiom line produced — see axiom-report.txt>}"

if [ "$actual" = "$EXPECTED" ]; then
  ok "rests on Mathlib's three foundations and nothing else"
else
  no "the axiom report is not the required one"
  hint "  required: $EXPECTED"
  hint ""
  if grep -q "sorryAx" axiom-report.txt; then
    hint "sorryAx means part of the proof is still missing. Note this is caught"
    hint "transitively: a 'sorry' in any lemma the theorem leans on shows up here,"
    hint "not only one in the theorem itself."
  elif grep -q "ofReduceBool\|ofReduceNat" axiom-report.txt; then
    hint "Lean.ofReduceBool comes from 'native_decide', which trusts compiled code"
    hint "rather than the kernel. This board does not accept it."
  else
    hint "Something beyond the three standard axioms is being assumed — most often"
    hint "an 'axiom' declaration somewhere in the file. Everything must be proved."
  fi
  exit 1
fi

# -------------------------------------------------------------------- done
cat <<'EOT'

===========================================================
  Ready to submit.

  Your proof is complete, gap-free, rests on nothing beyond Mathlib, and
  proves exactly the theorem that was posted. CI will reach the same verdict,
  because it runs this same script.

  To submit:
    1. Push your branch to your fork.
    2. Open a pull request against math-market/cramer-wold.
    3. Submit the pull request URL as your solution on the board:
       https://problem.market/tasks/019fde86-943c-72a4-8c0d-1bd8ecfc787c

  Your submission must be Apache-2.0 licensed so it can be archived and
  republished as part of the public record. See TASK.md.
===========================================================
EOT
