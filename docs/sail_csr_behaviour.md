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
- mcause: SUPERSEDED by the measured section below (this early list only named the values tried first).
- mtvec: base always written; a reserved mode (2 or 3) keeps the previous mode.
- mepc bits 1:0 always 0. mstatus: only MIE and MPIE writable; MPP = 3 after the first write or trap, 0 at reset.

## Consequences
- Phase 4 programs must not enable interrupts (mip.MTIP is pending in Sail).
- CSRs in the accepted list that the core does not implement (PMP, counters, mhpm*) are out of scope: tests must not touch them.

## mcause write rule and mstatush (measured, sw/probes/mcause_all.S: 138 values, each preceded by a write of 0xB)
- Accepted exception codes: 0-9, 0xB, 0xC, 0xD, 0xF, 0x13. Rejected: 0xA, 0xE, 0x10-0x12, 0x14-0x3F, and every sampled value with bits above bit 5 set (0x40, 0x80, 0x100, 0x1000, 0x40000000, 0x7FFFFFFF, 0xFFFFFFFF).
- Accepted interrupt codes (bit 31 set): 1, 3, 5, 7, 9, 0xB. Every other tested interrupt code was rejected.
- A rejected write leaves mcause unchanged (117 rejected values all read back 0xB; none changed to another value). Not swept: all 2^32 values.
- mstatush (0x310) reads 0 initially, after writing -1 and after writing 0.
- Consistent with the Sail 0.15 source reading (legalize_cause) reported by the other agent; code 0x13 is accepted, matching privileged_isa_version Privileged_ISA_1_13 in config/config.json.in.

## Interrupt entry (observed, sw/probes csr_wr_basic first draft: mie=0x888 with mstatus.MIE=1)
- Line: `handling int#machine-timer-interrupt at priv M | tval=... | tval2=... | tinst=...`, printed under the record of the instruction before the handler.
- Then: mstatus 0x1888 -> 0x1880, mstatush, mcause <- 0x80000007, mtval <- 0, mepc <- 0x80000038. compare_trace.py now fails on any such line (D5 guard).
