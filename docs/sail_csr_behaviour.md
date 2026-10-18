# Sail 0.15 M-only config: CSR behaviour (probes sw/probes/csr_rw.S, csr_rw2.S; sweep of all 4096 csrr addresses)
Provenance: CERTAIN = read directly from a trace read; LIKELY = derived by lining up readbacks with the inputs in order (the trace logs post-mask values on both write and read lines).

## CERTAIN
- misa reads 0x40000100 and ignores writes. mip reads 0x80 and ignores writes.
- mie: writing -1 reads 0x888 (writable bits 3, 7, 11). mscratch and mtval: writing -1 reads 0xFFFFFFFF.
- mstatus: first read 0; writing -1 reads 0x1888; writing 0 reads 0x1800.
- mepc: writing -1 reads 0xFFFFFFFC. mtvec: writing -1 (old mode 0) reads 0xFFFFFFFC.
- mvendorid, marchid, mimpid, mhartid, mconfigptr (0xF11-0xF15): read 0; 15 illegal-instruction traps occurred for 3 writes each.
- Accepted csr addresses (everything else raises illegal-instruction): 0x300-0x301 0x304-0x305 0x310 0x320 0x323-0x344 0x3A0-0x3A3 0x3B0-0x3BF 0xB00 0xB02-0xB1F 0xB80 0xB82-0xB9F 0xF11-0xF15.

## LIKELY
- mcause ignores writes of 0x1F, 0x7FFFFFFF and -1; accepts 0, 3, 4, 6, 0xB, 0x80000003.
- mtvec: base always written; a reserved mode (2 or 3) keeps the previous mode.
- mepc bits 1:0 always 0. mstatus: only MIE and MPIE writable; MPP = 3 after the first write or trap, 0 at reset.

## Consequences
- Phase 4 programs must not enable interrupts (mip.MTIP is pending in Sail).
- CSRs in the accepted list that the core does not implement (PMP, counters, mhpm*) are out of scope: tests must not touch them.
