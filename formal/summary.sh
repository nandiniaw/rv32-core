#!/usr/bin/env bash
# usage: formal/summary.sh <cfg-name>   Lists every generated check with its sby status.
rf="${RISCV_FORMAL:-$HOME/riscv-formal}"
d="$rf/cores/rv32core/${1:?cfg-name}"
for c in "$d"/*/; do n=$(basename "$c"); [ -f "$c/status" ] && echo "$n $(head -n 1 "$c/status")"; done | sort
