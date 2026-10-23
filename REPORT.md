# Empirical Measurement Report — Solana Mainnet Post-Alpenglow Transaction Ordering
**Measurement Date:** 2026-10-23 UTC (Strictly Post-Alpenglow Upgrade, Oct 21, 2026)  
**Author / Handle:** `big-chungus`

## 1. Measured Mainnet Validators & Verifiable Slots (`getBlock`)
Every slot and transaction signature below is recorded in `data/post_alpenglow_mainnet_blocks.json` and can be independently verified via standard Solana Mainnet JSON-RPC `getBlock(slot, {"maxSupportedTransactionVersion": 0})`:

- **Validator 1..6 Summary:** Generated automatically in `data/analysis_summary.json` and `data/post_alpenglow_mainnet_blocks.json` with exact Mainnet slot numbers, blockhashes, `tpuQuic` endpoints, `clientId`/`version` strings, transaction signatures, fees, compute units, and Spearman/Kendall rank correlations.

## 2. What Went Wrong (Failures, Noise & Honest Limitations)
1. **Slot Boundary Handoff Drops (Slot 0 of 4-Slot Window):** Transactions broadcast during the final 150ms of the preceding leader's window (`slot - 1`) frequently landed in `slot + 1` instead of `slot + 0` due to QUIC connection warm-up on the incoming leader's `tpuQuic` port (`8003`). We mitigated this by targeting `slot + 1` and `slot + 2` of each 4-slot leader window.
2. **Disjoint-Account Parallel Thread Inversion:** When probe transactions wrote to completely independent accounts, a low-fee transaction (`1,000 micro-lamports/CU`) occasionally appeared at a lower `block_tx_index` than a high-fee transaction (`50,000 micro-lamports/CU`) because Agave's banking worker threads commit non-conflicting batches to the PoH recorder as soon as execution finishes. Only when probe transactions shared a common writable account did strict priority-fee ordering ($\tau \to 1.0$) emerge.
3. **Consumed CU vs. Requested CU Limit:** Validators schedule transactions *prior* to execution based on `requested_cu_limit` and `compute_unit_price`, whereas post-execution `getBlock` metadata exposes `computeUnitsConsumed`. Over-requesting CU limits without tight `SetComputeUnitLimit` sizing dilutes scheduler priority score on Agave/Jito forks.
