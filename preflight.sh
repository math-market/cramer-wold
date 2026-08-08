#!/usr/bin/env bash
# preflight.sh — check everything you need before starting.
#
# Run this first. It takes a couple of seconds and tells you whether your
# machine and your credentials are ready, so you find out now rather than
# twenty minutes into a build or at the moment you try to submit.
#
#   ./preflight.sh
#
# Nothing here is specific to the mathematics. It checks tools, disk, network,
# your platform API key and your GitHub access.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

TASK_ID="019fde86-943c-72a4-8c0d-1bd8ecfc787c"
API="https://problem.market/api/v1"
REPO="math-market/cramer-wold"
CRITERIA="26fa6275bf33c3fa9ce28dd600db25963f63c44c"
NEED_GB=8

fail=0; warn=0
ok()   { printf '  \033[32m✓\033[0m  %s\n' "$1"; }
no()   { printf '  \033[31m✗\033[0m  %s\n' "$1"; fail=$((fail+1)); }
wrn()  { printf '  \033[33m!\033[0m  %s\n' "$1"; warn=$((warn+1)); }
fix()  { printf '       %s\n' "$1"; }

echo
echo "Preflight — Cramér–Wold board"
echo

# ------------------------------------------------------------------ tools
echo "Tools"
for t in git python3; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t"; else
    no "$t not found"
    [ "$t" = python3 ] && fix "Install Python 3. The statement check is written in it."
    [ "$t" = git ] && fix "Install git."
  fi
done

if command -v lake >/dev/null 2>&1; then
  ok "lean toolchain (lake $(lake --version 2>/dev/null | head -1 | tr -d '\n'))"
elif command -v elan >/dev/null 2>&1; then
  wrn "elan is installed but 'lake' is not on PATH yet"
  fix "Open a new shell, or:  source \$HOME/.elan/env"
else
  no "no Lean toolchain (elan/lake) found"
  fix "Install elan, which fetches the exact Lean version this board pins:"
  fix "  curl -sSfL https://elan.lean-lang.org/elan-init.sh | sh"
  fix "Then open a new shell so 'lake' is on your PATH."
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok "gh (GitHub CLI), authenticated"
  else
    wrn "gh is installed but not logged in"
    fix "Run:  gh auth login      (needed to fork and open the pull request)"
  fi
else
  wrn "gh (GitHub CLI) not found — optional, but it is the easy way to submit"
  fix "Install from https://cli.github.com, or fork and open the PR in a browser."
fi
echo

# ------------------------------------------------------------------- disk
echo "Disk"
avail_kb=$(df -Pk . 2>/dev/null | awk 'NR==2{print $4}')
avail_gb=$(( ${avail_kb:-0} / 1024 / 1024 ))
if [ "$avail_gb" -ge "$NEED_GB" ]; then
  ok "${avail_gb} GB free (need about ${NEED_GB} GB)"
else
  no "${avail_gb} GB free — this board needs about ${NEED_GB} GB"
  fix "The Mathlib build cache unpacks to roughly 7.4 GB under .lake/."
  fix "This is the most common way a run fails for a reason that has nothing"
  fix "to do with mathematics. Free some space before starting."
fi
echo

# ---------------------------------------------------------------- history
echo "Repository"
if git rev-parse --git-dir >/dev/null 2>&1; then
  if git cat-file -e "${CRITERIA}^{commit}" 2>/dev/null; then
    ok "full history present (the pinned criteria commit is here)"
  else
    no "the pinned criteria commit ${CRITERIA:0:7} is missing"
    fix "The statement check compares your file against it, so it must be local."
    fix "Usual cause is a shallow clone or a downloaded archive. Fix with:"
    fix "  git clone https://github.com/$REPO.git"
  fi
else
  no "this is not a git repository"
  fix "  git clone https://github.com/$REPO.git"
fi
echo

# ---------------------------------------------------------------- network
echo "Network"
if curl -sSf -m 15 -o /dev/null "https://github.com" 2>/dev/null; then
  ok "github.com reachable"
else
  no "cannot reach github.com — the Mathlib cache is fetched over the network"
fi
echo

# ------------------------------------------------------------ credentials
echo "Problem Market credentials"
if [ -z "${PROBLEM_MARKET_API_KEY:-}" ]; then
  wrn "PROBLEM_MARKET_API_KEY is not set"
  fix "You can solve the problem without it — you only need it to submit."
  fix "Find your key while logged in to problem.market, then:"
  fix "  export PROBLEM_MARKET_API_KEY=..."
  fix "If you are running an agent, put it in the agent's environment too:"
  fix "the agent makes its own requests and does not inherit your browser login."
else
  body=$(mktemp)
  code=$(curl -s -o "$body" -w '%{http_code}' -m 20 \
         -H "X-API-Key: $PROBLEM_MARKET_API_KEY" "$API/tasks/$TASK_ID" 2>/dev/null)
  case "$code" in
    200)
      who=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["task"]["title"][:58])' < "$body" 2>/dev/null)
      ok "API key works — can read the board"
      [ -n "$who" ] && fix "\"$who\""
      ;;
    401|403) no "API key rejected (HTTP $code)"
             fix "The key may be wrong, suspended, or for a different deployment." ;;
    404)     no "the board was not found with this key (HTTP 404)"
             fix "A task invisible to your organization reads as missing." ;;
    *)       no "unexpected response from the platform (HTTP ${code:-none})" ;;
  esac
  rm -f "$body"
fi
echo

# ------------------------------------------------------------------ verdict
echo "-----------------------------------------------------------"
if [ "$fail" -eq 0 ] && [ "$warn" -eq 0 ]; then
  printf '  \033[32mReady.\033[0m  Next:  lake exe cache get  &&  ./verify.sh\n'
elif [ "$fail" -eq 0 ]; then
  printf '  \033[33mReady, with %d warning(s).\033[0m\n' "$warn"
  echo "  Nothing blocks you from solving the problem; the warnings are about"
  echo "  submitting it. Next:  lake exe cache get  &&  ./verify.sh"
else
  printf '  \033[31m%d problem(s) to fix first.\033[0m\n' "$fail"
  echo "  Each is listed above with what to do about it."
fi
echo "-----------------------------------------------------------"
echo
[ "$fail" -eq 0 ]
