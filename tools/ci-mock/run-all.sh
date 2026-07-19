#!/bin/bash
# Host-side driver: push every nvchecker bump through the CI-mock container in parallel,
# classify each result. Reads "cat/pkg ver #issue" lines on stdin.
# Usage:  cat list.txt | run-all.sh <outdir>
set -uo pipefail
OUTDIR="${1:?usage: run-all.sh <outdir> < list}"
mkdir -p "$OUTDIR"; : > "$OUTDIR/summary.txt"
RB=/home/zakk/code/autobump-rb; OV=/home/zakk/code/gentoo-zh

run_one() {
  local pkg=$1 ver=$2 issue=${3:-}
  local log="$OUTDIR/${pkg//\//_}.log"
  timeout 1200 sudo docker run --rm --net=host --privileged \
    -v "$RB":/autobump-rb:ro -v "$OV":/host-overlay:ro \
    autobump-ci:ready bash /autobump-rb/tools/ci-mock/run-issue.sh "$pkg" "$ver" \
    > "$log" 2>&1
  local rc=$? v
  if   grep -q 'ok committed:'                            "$log"; then v="✅ COMMIT  "
  elif grep -qE 'ESCALATE:|not mechanically safe'         "$log"; then v="⛔ ESCALATE"
  elif grep -qE 'Deferring|cannot smoke-test|been masked|timed out' "$log"; then v="⏸  DEFER  "
  else v="❓ ERR rc=$rc"
  fi
  printf '%s  %-34s %-14s %s\n' "$v" "$pkg" "$ver" "$issue" | tee -a "$OUTDIR/summary.txt"
}
export -f run_one; export OUTDIR RB OV

# each emerge is independent; -P sets parallelism (9950x3d has the cores)
xargs -P "${PARALLEL:-4}" -L 1 bash -c 'run_one "$@"' _
echo "==== done: $(grep -c COMMIT "$OUTDIR/summary.txt") commit / $(grep -c ESCALATE "$OUTDIR/summary.txt") escalate / $(grep -c DEFER "$OUTDIR/summary.txt") defer ===="
