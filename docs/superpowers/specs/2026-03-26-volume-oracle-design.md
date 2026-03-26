# Volume Oracle Design Spec

**Date:** 2026-03-26
**Status:** Approved (brainstorm complete)
**Reference:** ThetaSwap FCI V2 (wvs-finance/ThetaSwap-core)

---

## 1. Overview

A fully modular, protocol-agnostic Volume Oracle that exposes all Tier 1 (raw accumulators) and Tier 2 (derived analytics) volume metrics on-chain. Follows the ThetaSwap FCI V2 orchestrator pattern: lightweight registry + delegatecall dispatch for protocol facets, standalone view contracts for metric reads.

## 2. Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hook vs standalone | Both — V4 hook inherits standalone orchestrator | FCI V1→V2 evolution path; V4-native + protocol-agnostic |
| Metric modularity | Tier-grouped facets (Accumulators + Analytics) | Natural storage boundary; Tier 2 reads Tier 1, not vice versa |
| Epoch system | Separate optional module | Orthogonal to metric tiers; matches FCI EpochStorageMod pattern |
| Query interface | Pull (view functions) + Events | Composable on-chain reads + off-chain indexing; no callback complexity |
| Initial protocol scope | V4 facet only, V3-ready interface | Ship fast; modularity guarantees future extensibility |
| Architecture pattern | Lightweight Registry + Delegatecall (Approach 2) | What FCI V2 actually does; simpler than full Diamond; protocol facets share storage |

## 3. Architecture

### 3.1 Contract Hierarchy

```
VolumeOracleV2 (abstract orchestrator)
│   ├── Protocol facet registry: bytes2 flags → IVolumeProtocolFacet
│   ├── Storage: VolumeAccumulatorsStorageMod (namespaced)
│   ├── Storage: VolumeAnalyticsStorageMod (namespaced)
│   └── Delegatecall dispatch to registered protocol facets
│
├── VolumeOracleHook (inherits VolumeOracleV2)
│   └── V4 IHooks callbacks → inherited orchestrator logic
│
├── IVolumeProtocolFacet (behavioral interface)
│   └── UniswapV4VolumeFacet (delegatecall target)
│
├── VolumeEpochFacet (optional, standalone)
│   └── VolumeEpochStorageMod (namespaced)
│
└── Readers (standalone view contracts)
    ├── VolumeAccumulatorsReader (Tier 1)
    ├── VolumeAnalyticsReader (Tier 2)
    └── VolumeEpochReader (epochs)
```

### 3.2 Storage Modules (Diamond-style namespaced slots)

**VolumeAccumulatorsStorageMod** — `keccak256("volumeOracle.accumulators")`
- Per-pool mappings: cumulativeVolumeA/B, buyVolume, sellVolume, cvd, feeVolumeA/B, cumulativePQ, cumulativeQ, lastUpdateTimestamp, lastUpdateBlock

**VolumeAnalyticsStorageMod** — `keccak256("volumeOracle.analytics")`
- Per-pool mappings: emaShort, emaLong, welfordCount/Mean/M2, obv, vpt, forceIndexEma, nvi, pvi, cusum, cusumReference, cumulativeLvr, lastClosePrice, lastPeriodVolume

**VolumeEpochStorageMod** — `keccak256("volumeOracle.epoch")`
- Per-pool: epochLength, currentEpochId, epochStartTimestamp
- Per-pool per-epoch: EpochState { volumeA, volumeB, cvd, vwapNumerator, vwapDenominator, obv, forceIndex }

**VolumeProtocolFacetRegistryMod** — `keccak256("volumeOracle.protocolRegistry")`
- bytes2 protocolFlags → IVolumeProtocolFacet address

### 3.3 Delegatecall Dispatch

The orchestrator dispatches protocol-specific logic via delegatecall:

```
VolumeOracleV2._recordSwap(flags, poolId, hookData):
    facet = registry.facets[flags]
    (amountA, amountB) = delegatecall(facet, swapAmount(hookData))
    isBuy = delegatecall(facet, swapDirection(hookData))
    price = delegatecall(facet, currentPrice(hookData, poolId))
    → _accumulateTier1(poolId, amountA, amountB, isBuy, price)
    → _accumulateTier2(poolId, amountA, amountB, isBuy, price)
```

Protocol facets execute in the orchestrator's storage context (delegatecall), enabling direct writes to namespaced slots.

### 3.4 V4 Hook Integration

VolumeOracleHook inherits VolumeOracleV2 directly:

```
beforeSwap  → delegatecall(facet, tstorePreSwapState(poolId, price, tick))
afterSwap   → _recordSwap(V4_FLAGS, poolId, hookData)
```

No cross-contract calls on the hot path. The hook IS the orchestrator.

## 4. Metrics Covered

### Tier 1: Raw Accumulators (O(1) per swap, ~88 bytes storage)

| Metric | Storage | Update Logic |
|--------|---------|-------------|
| Cumulative Volume (A, B) | 2 × uint256 | += amountA, += amountB |
| Buy/Sell Volume | 2 × uint256 | conditional += based on direction |
| Cumulative Volume Delta | int256 | += (buyAmount - sellAmount) |
| Fee Volume (A, B) | 2 × uint256 | += feeA, += feeB |
| VWAP accumulators | 2 × uint256 | cumulativePQ += price*qty, cumulativeQ += qty |
| Volume/TVL Ratio | derived | cumulativeVolume / TVL (read-time) |
| Net Volume Flow | derived | buyVolume - sellVolume (read-time) |

### Tier 2: Derived Analytics (O(1) per swap, ~88 bytes storage)

| Metric | Storage | Update Logic |
|--------|---------|-------------|
| Volume EMA (short + long) | 2 × uint256 | α*vol + (1-α)*ema_old |
| Volume Oscillator | derived | emaShort - emaLong (read-time) |
| Welford z-score | 3 values | Online mean/variance, z = (vol - mean) / σ |
| OBV | int256 | += vol if price up, -= vol if price down |
| VPT | int256 | += vol * (price_change / prev_price) |
| Force Index (EMA) | int256 | EMA(price_change * volume) |
| NVI / PVI | 2 × uint256 | Conditional update based on volume vs previous |
| CUSUM | 2 × uint256 | cusum += max(0, vol - reference - k) |
| Breakout Signal | derived | zScore > threshold (read-time) |
| LVR | uint256 | += σ²/8 per swap (with oracle price) |

## 5. Events

- `VolumeAccumulated(poolId, amountA, amountB, isBuy, price, timestamp)` — every swap
- `BreakoutDetected(poolId, zScore, volume, timestamp)` — z-score exceeds threshold
- `RegimeChangeDetected(poolId, cusum, reference, timestamp)` — CUSUM threshold crossed
- `ProtocolFacetRegistered(protocolFlags, facet)` — facet registration
- `EpochInitialized(poolId, epochLength)` — epoch setup
- `EpochReset(poolId, oldEpochId, newEpochId)` — epoch boundary crossed

## 6. Libraries

- **LibCall** — delegatecall helper with revert propagation
- **FixedPointMathLib** — Q128 arithmetic for EMA, VWAP, Welford, sqrt

## 7. Protocol Facet Interface

`IVolumeProtocolFacet` defines:
- `swapDirection(hookData)` → bool isBuy
- `swapAmount(hookData)` → (uint256 amountA, uint256 amountB)
- `swapFee(hookData)` → (uint256 feeA, uint256 feeB)
- `currentPrice(hookData, poolId)` → uint256
- `currentTick(hookData, poolId)` → int24
- `tstorePreSwapState(poolId, price, tick)` — transient cache
- `tloadPreSwapState(poolId)` → (price, tick)
- `addVolumeTerm(poolId, amountA, amountB, isBuy, price)` — accumulate

Protocol flags: `0xFFFF` = Uniswap V4 native.

## 8. Project Structure

```
src/
├── volume-oracle/
│   ├── interfaces/
│   │   └── IVolumeOracle.sol            # Public read interface (Tier 1 + 2)
│   ├── modules/
│   │   ├── VolumeAccumulatorsStorageMod.sol  # Tier 1 storage
│   │   └── VolumeAnalyticsStorageMod.sol     # Tier 2 storage
│   └── libraries/
│       └── FixedPointMathLib.sol         # Q128 math
│
├── volume-oracle-v2/
│   ├── VolumeOracleV2.sol               # Orchestrator (abstract)
│   ├── interfaces/
│   │   └── IVolumeProtocolFacet.sol     # Protocol facet behavioral interface
│   ├── modules/
│   │   └── VolumeProtocolFacetRegistryMod.sol  # bytes2 → facet registry
│   ├── protocols/
│   │   └── uniswap-v4/
│   │       └── UniswapV4VolumeFacet.sol # V4-specific delegatecall target
│   ├── readers/
│   │   ├── VolumeAccumulatorsReader.sol # Tier 1 view contract
│   │   ├── VolumeAnalyticsReader.sol    # Tier 2 view contract
│   │   └── VolumeEpochReader.sol        # Epoch view contract
│   └── libraries/
│       ├── LibCall.sol                  # Delegatecall helper
│       └── VolumeEvents.sol             # Event definitions
│
├── epoch/
│   ├── VolumeEpochFacet.sol             # Optional epoch module
│   ├── interfaces/
│   │   └── IVolumeEpoch.sol             # Epoch interface
│   └── modules/
│       └── VolumeEpochStorageMod.sol    # Epoch storage
│
└── hook/
    └── VolumeOracleHook.sol             # V4 hook (inherits VolumeOracleV2)

test/
├── unit/
│   ├── VolumeAccumulators.t.sol
│   ├── VolumeAnalytics.t.sol
│   └── VolumeEpoch.t.sol
├── integration/
│   └── VolumeOracleHook.t.sol
└── mocks/
    └── MockProtocolFacet.sol
```

## 9. Dependencies

- Uniswap V4 Core (`v4-core`) — IHooks, PoolManager, PoolId, BalanceDelta
- Uniswap V4 Periphery (`v4-periphery`) — BaseHook utilities
- forge-std — testing

## 10. Future Extensions (not in scope)

- Uniswap V3 protocol facet (reactive adapter pattern)
- Callback hooks for reactive consumers (e.g., notify on breakout)
- Tier 3 metrics (checkpoint ring buffer, per-tick-range counters)
- Tier 4 off-chain metrics with on-chain verification
- Cross-pool volume flow aggregation
