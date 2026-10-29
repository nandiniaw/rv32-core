#!/usr/bin/env bash
# usage: scripts/vcov.sh  (Verilator line+toggle coverage over random seeds; separate build dir)
cd "$(dirname "$0")/.." || exit 2
export PATH=$HOME/verilator-5.052/bin:$PATH
rm -rf build/vcov tests/system/sim_build_cov; mkdir -p build/vcov
i=0
for f in build/rand/r10[0-9].elf build/rand/r30[0-9].elf build/probes/*.elf build/haz.elf build/ls_edge.elf; do
  i=$((i+1)); n=$(basename $f .elf)
  export MAKE_ARGS="SIM_BUILD=sim_build_cov EXTRA_ARGS=--coverage"
  ./scripts/run_core_elf.sh $f > /dev/null 2>&1
  if [ -f tests/system/coverage.dat ]; then mv tests/system/coverage.dat build/vcov/$n.dat; else echo "no coverage.dat for $n"; fi
done
ls build/vcov | wc -l
verilator_coverage --annotate build/vcov/annot --annotate-min 1 build/vcov/*.dat 2>&1 | tail -n 5
