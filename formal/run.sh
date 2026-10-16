#!/usr/bin/env bash
# usage: formal/run.sh <cfg-name> [jobs]    (cfg-name = formal/<cfg-name>.cfg, e.g. cover)
# Copies our RTL into riscv-formal/cores/rv32core (out-of-tree generation is unsupported), generates the
# checks and runs them inside a subshell so the OSS CAD Suite tools do not leak into the global PATH.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
rf="${RISCV_FORMAL:-$HOME/riscv-formal}"
cfg="${1:?usage: run.sh <cfg-name> [jobs]}"
jobs="${2:-2}"
core="$rf/cores/rv32core"
mkdir -p "$core" "$repo/logs"
rm -rf "${core:?}/$cfg"
rm -f "$core/rv32_pkg.sv"
python3 "$here/inline_pkg.py" "$repo/rtl" "$core" || exit 3
python3 "$here/check_derived.py" "$repo/rtl" "$core" || exit 4
cp "$here/wrapper.sv" "$core/wrapper.sv"
cp "$here/$cfg.cfg" "$core/$cfg.cfg"
( source "$HOME/oss-cad-suite/environment" && cd "$core" \
  && python3 ../../checks/genchecks.py "$cfg" && make -C "$cfg" -j"$jobs" ) 2>&1 | tee "$repo/logs/formal_$cfg.log"
rc=${PIPESTATUS[0]}
echo "formal $cfg exit: $rc"
echo "--- status files (if sby wrote them) ---"
for d in "$core/$cfg"/*/; do
  [ -f "$d/status" ] && echo "$(basename "$d"): $(head -n 1 "$d/status")"
done
exit $rc
