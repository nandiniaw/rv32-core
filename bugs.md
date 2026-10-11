# Bug log

## BUG-001 (tooling): `make -C smoke` could not find counter.sv
- Found by: scripts/regress.sh smoke check (make exit 2); logs/smoke.log showed "No rule to make target '/home/no_one/rv32-core/counter.sv'".
- Root cause: smoke/Makefile used $(PWD), which is the shell's directory. `make -C` changes make's directory, not $PWD.
- Fix: use $(CURDIR).
- Caught now by: scripts/regress.sh, which runs smoke from the repo root.
