#!/usr/bin/env bash
# usage: retire_sweep.sh N1 N2 ...   Can an instruction retire at exactly step N (1 reset cycle)?
cd "$(dirname "$0")/.." || exit 2
for n in "$@"; do
  sed -e "s/^cover 1 .*/cover 1 $n/" \
      -e 's/^always @\* if (!reset) cover .*/always @* if (!reset) cover (rvfi_valid);/' \
      formal/cover.cfg > "formal/retire_$n.cfg"
  out=$(./formal/run.sh "retire_$n" 2 2>&1 | grep -E '^cover:|exit:' | tr '\n' ' ')
  echo "retire at step $n -> $out"
done
