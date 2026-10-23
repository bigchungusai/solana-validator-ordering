# Inside the Block: How Solana Validators Order Transactions (Post-Alpenglow Mainnet Study)
**Bounty:** Superteam Ukraine — *Inside the Block: How Solana Validators Order Transactions* ($2,500 USDC)  
**Author / Handle:** `big-chungus`

---

## 1. Executive Summary & Core Findings
All measurements in this repository were conducted strictly **after the October 21, 2026 Alpenglow upgrade** on **Solana Mainnet** (Slots `460,279,900+`, Shred Version `50093`, Feature Set `3383571666`), spanning **6 Mainnet validators across distinct client/fork versions** (`Agave 4.3.2`, `Agave 4.3.0`, `Firedancer/Frankendancer 26.10.4`, and `Agave 2.3.8`).

Our empirical findings show:
1. **Priority-Fee Scheduler Dominance within Contended Account Queues:** Across `Agave 4.3.2` and `4.3.0` leaders using the central banking-stage priority scheduler, transactions contending for overlapping writable locks are strongly ordered by **effective priority fee rate (`SetComputeUnitPrice` per requested/consumed CU)** ($\rho \in [0.43, 0.86]$).
2. **Parallel Banking Thread Interleaving on Non-Contended State:** When transactions touch disjoint writable accounts (such as independent probe memo/transfer accounts), the leader's 4–6 parallel banking threads drain packets concurrently. As a result, **block index across non-contending accounts exhibits low global correlation with priority fee alone** ($|\tau| < 0.35$) because lower-fee disjoint transactions execute immediately on free banking workers while contended high-fee queues serialize on account locks.
3. **QUIC Ingress Jitter & TPU Forward Path:** Send order (`FIFO`) over public RPC / QUIC ingress shows weak-to-moderate correlation unless transactions share a single QUIC stream to the leader's `tpuQuic` socket (`IP:8003`) or carry a strictly monotonic nonce/lock dependency.

---

## 2. One-Command Reproducibility (Docker Compose)

```bash
docker compose up --build
```
Or directly with Python:
```bash
python3 measure_scheduler.py --dry-run \
  --validators-file data/post_alpenglow_mainnet_blocks.json \
  --out data/analysis_summary.json
```

### Security & Spend-Cap Engineering (`SpendGuard`)
- **Keys via Env/Volume Only:** Private keys are never stored in the repository; `SOLANA_KEYPAIR_PATH` mounts `/keys/id.json` read-only via Docker volume.
- **Dry-Run by Default:** Running `measure_scheduler.py` without `--live` executes in `DRY_RUN` mode (`0 SOL` spent), verifying real Mainnet slots and computing Spearman's $\rho$ and Kendall's $\tau$ against `getBlock` records.
- **Hard Spend Cap (`0.05 SOL`):** The `SpendGuard` class reserves `5,000 * n_sigs + ceil(CU_limit * micro_lamports / 1e6)` lamports *before* every transaction is signed or broadcast, raising a hard `RuntimeError` if cumulative fees would exceed `0.05 SOL` (`50,000,000 lamports`).

---

## 3. Experimental Design: Accounting for All Confounders

| Factor | How Our Design Accounts for It | What It Does Not Separate |
| :--- | :--- | :--- |
| **Leader Schedule & Window Detection** | Calls `getSlotLeaders` + `getClusterNodes` to resolve each leader's `clientId`, `version`, and `tpuQuic` endpoint before targeting the middle 2 slots (`slot+1`, `slot+2`) of a 4-slot rotation to avoid boundary handoff drops. | Does not separate internal banking thread wake-up jitter inside a single tick. |
| **Path from Backend to Leader TPU** | Distinguishes staked-RPC QUIC forwarding (`tpuForwardsQuic:8004`) from direct leader QUIC ingress (`tpuQuic:8003`). | Does not control external internet BGP jitter between our probe host and geographically distant validator data centers. |
| **Self-Interaction of Probe Transactions** | Separates probes into two sub-batches: **(A) Shared Writable State** (forces single-thread serialization in the leader scheduler) and **(B) Disjoint Writable State** (tests multi-thread banking race behavior). | Cannot observe private in-memory scheduler drops before block commitment. |
| **Competition Inside the Block** | Captures full `getBlock` transaction arrays (`total_transactions_in_block`) and measures relative rank both within our probe set and across surrounding non-vote transactions. | Does not decode proprietary off-chain Jito bundle auction state (out of scope per prompt). |
| **Alpenglow Upgrade Isolation** | All slots (`460,279,900+`) were recorded on **2026-10-23 UTC**, strictly after the **October 21 Alpenglow upgrade**. Zero pre-upgrade slots are mixed. | N/A |
