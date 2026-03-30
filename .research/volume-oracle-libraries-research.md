# Volume Oracle Libraries Research Report

**Date:** 2026-03-30
**Author:** Papa Bear (Deep Analysis)
**Status:** Complete
**Purpose:** Identify existing DEX/AMM oracle libraries that store per-tick volume data and expose composable library interfaces, to map the competitive landscape and confirm the gap that volume-soldk-dev aims to fill.

---

## Executive Summary

After a thorough investigation of seven major DEX/AMM protocol families and their oracle implementations, the conclusion is unambiguous: **no existing on-chain oracle library stores actual swap volume data on a per-tick or per-timepoint basis in a composable, standalone library form.** Every oracle implementation found tracks price (tick accumulators, EMA prices) and sometimes liquidity or volatility, but none accumulate raw volume amounts (tokenA traded, tokenB traded, buy volume, sell volume) in a way that external contracts can query.

The closest implementation is Algebra Finance's `volumePerLiquidityCumulative` field in their Timepoint struct, which tracks a ratio of volume-to-liquidity rather than raw volume. Even this field was removed in later Algebra Integral versions. Trader Joe's Liquidity Book tracks `cumulativeVolatility` and `cumulativeBinCrossed` but not raw token volume per bin.

This confirms that volume-soldk-dev occupies a genuinely novel position in the ecosystem: a composable, protocol-agnostic volume oracle that accumulates raw volume metrics (cumulative volume A/B, buy/sell volume, CVD, fee volume, VWAP accumulators) on every swap and exposes them through standalone reader contracts.

---

## 1. Algebra Protocol (Algebra Finance)

### 1.1 Repository and File Paths

- **Organization:** https://github.com/cryptoalgebra
- **Main repo (Integral):** https://github.com/cryptoalgebra/Algebra
- **V1 repo:** https://github.com/cryptoalgebra/AlgebraV1
- **Plugin template:** https://github.com/cryptoalgebra/algebra-plugin-template
- **Fee simulation tool:** https://github.com/cryptoalgebra/IntegralFeeSimulation
- **Key files (V1 era):**
  - `src/core/contracts/DataStorageOperator.sol` -- standalone oracle operator
  - `src/core/contracts/libraries/DataStorage.sol` -- the ring buffer library
  - `src/core/contracts/AlgebraPool.sol` -- pool integrating the oracle
- **Key files (Integral / plugin era):**
  - `src/plugin/contracts/libraries/VolatilityOracle.sol` -- the timepoint ring buffer library
  - `src/plugin/contracts/AlgebraOracleV1TWAP.sol` or similar -- plugin contract
  - `src/plugin/contracts/types/AlgebraFeeConfiguration.sol` -- fee config using volatility data

### 1.2 Core Data Structure: Timepoint

The Algebra Timepoint struct (V1 / early Integral versions) contains:

```
struct Timepoint {
    bool     initialized;                          // 1 byte
    uint32   blockTimestamp;                        // 4 bytes
    int56    tickCumulative;                        // 7 bytes
    uint160  secondsPerLiquidityCumulative;         // 20 bytes  (REMOVED in later versions)
    uint88   volatilityCumulative;                  // 11 bytes
    int24    averageTick;                           // 3 bytes
    uint144  volumePerLiquidityCumulative;          // 18 bytes  (REMOVED in later versions)
}
```

Storage: timepoints are stored in a fixed-size ring buffer (UINT16_MODULO = 65,536 entries). A new entry is appended at most once per block. The buffer overwrites when full.

### 1.3 Volume Tracking Assessment

**What it tracks:** `volumePerLiquidityCumulative` -- a cumulative ratio of volume divided by current in-range liquidity. This is NOT raw volume; it is volume normalized by liquidity, designed to feed the adaptive fee algorithm (higher volume/liquidity ratio suggests more volatile conditions, warranting higher fees).

**Critical finding:** In Algebra Integral V2.0+, the `volumePerLiquidityCumulative` and `secondsPerLiquidityCumulative` fields were **removed** from the Timepoint struct. The rationale was to simplify the oracle and reduce gas costs. Current Algebra Integral versions track only: `blockTimestamp`, `tickCumulative`, `volatilityCumulative`, and `averageTick`.

**What it does NOT track:**
- Raw cumulative volume in token A or token B
- Buy volume vs. sell volume (directional breakdown)
- Fee volume
- VWAP accumulators (price * quantity sums)

### 1.4 Library Pattern

- **V1:** `DataStorageOperator` is a standalone contract deployed per pool. The pool calls `DataStorageOperator.write()` on every swap. External contracts call `DataStorageOperator.getSingleTimepoint()` or `getTimepoints()` to read.
- **Integral:** Moved to a **plugin architecture**. The VolatilityOracle is a library used inside a plugin contract that attaches to a pool. Only one plugin per pool at a time. The plugin receives callbacks from the pool (before/after swap hooks).

### 1.5 Composability

- **V1:** Moderate composability. DataStorageOperator is a separate contract, but it is tightly coupled to a single pool and written to only by that pool.
- **Integral:** Plugin contracts are modular and replaceable (upgradeable without liquidity migration), but they are NOT standalone composable libraries. A plugin is attached to exactly one pool. External contracts cannot easily compose with the oracle data without going through the pool's plugin interface.

### 1.6 Storage Layout and Gas

- Ring buffer of 65,536 timepoints
- Each timepoint fits in approximately 2 storage slots (64 bytes, depending on version)
- Write cost: ~5,000-20,000 gas per swap (one SSTORE for the new timepoint, conditional on same-block deduplication)
- Read cost: Binary search over the ring buffer, O(log n) SLOADs
- UINT16_MODULO capacity: ~45 values/minute over 24 hours on Ethereum mainnet; potentially insufficient for L2s with faster block times

### 1.7 Key Interfaces

```solidity
// V1 DataStorageOperator
function getSingleTimepoint(uint32 time, int24 tick, uint16 index, uint128 liquidity)
    external view returns (int56 tickCumulative, uint160 secondsPerLiquidityCumulative,
                           uint88 volatilityCumulative, uint144 volumePerLiquidityCumulative);

function getTimepoints(uint32[] calldata secondsAgos)
    external view returns (int56[] tickCumulatives, uint160[] secondsPerLiquidityCumulatives,
                           uint112[] volatilityCumulatives, uint256[] volumePerLiquidityCumulatives);

// Integral Plugin
function timepoints(uint256 index)
    external view returns (bool initialized, uint32 blockTimestamp, int56 tickCumulative,
                           uint88 volatilityCumulative, int24 averageTick, ...);
```

---

## 2. Uniswap

### 2.1 Uniswap V3 Oracle.sol

#### Repository and File Paths

- **Core:** https://github.com/Uniswap/v3-core
  - `contracts/libraries/Oracle.sol` -- the oracle library
  - `contracts/UniswapV3Pool.sol` -- pool integrating the oracle
  - `contracts/interfaces/pool/IUniswapV3PoolState.sol` -- observation accessor
- **Periphery:** https://github.com/Uniswap/v3-periphery
  - `contracts/libraries/OracleLibrary.sol` -- helper library for TWAP queries

#### Core Data Structure: Observation

```solidity
struct Observation {
    uint32  blockTimestamp;                        // 4 bytes
    int56   tickCumulative;                        // 7 bytes
    uint160 secondsPerLiquidityCumulativeX128;     // 20 bytes
    bool    initialized;                           // 1 byte
}
// Total: 32 bytes -- fits in exactly ONE storage slot
```

Storage: observations are stored in a growable ring buffer. Initial capacity is 1 slot. Anyone can pay to expand up to 65,535 observations via `increaseObservationCardinalityNext()`. Observations are overwritten when the buffer is full.

#### Volume Tracking Assessment

**Tracks:** tick (price), liquidity density (seconds per liquidity). That is all.

**Does NOT track:**
- Any form of volume (cumulative, directional, per-token, fee volume)
- Volatility
- VWAP

The V3 oracle is purely a **TWAP (Time-Weighted Average Price)** and **TWAL (Time-Weighted Average Liquidity)** oracle. Volume is entirely absent from the on-chain observation data.

#### Library Pattern

`Oracle.sol` is a pure **Solidity library** (using `library Oracle` with functions operating on `Observation[65535] storage`). It is the gold standard of the "library operating on caller's storage" pattern. Functions include:
- `initialize()` -- set up the first observation
- `write()` -- append a new observation (called by the pool on every swap, max once per block)
- `observe()` -- binary search + interpolation to return cumulative values at arbitrary past timestamps
- `grow()` -- expand the ring buffer capacity

#### Composability

**High composability of the library itself** -- any contract can import Oracle.sol and use it with its own storage array. However, in practice, it is embedded inside UniswapV3Pool and not designed to be used by external contracts directly. External contracts read observations through `pool.observe()` or use `OracleLibrary.consult()`.

#### Storage Layout and Gas

- Each Observation = 1 storage slot (32 bytes)
- Observation at index X is at storage slot `8 + X` in the pool contract
- Write cost: ~5,000 gas (warm SSTORE) per swap for the observation update
- Read cost: O(log n) binary search over the ring buffer
- Growing the buffer: 20,000 gas per new slot (cold SSTORE)

#### Key Interfaces

```solidity
// Pool-level
function observe(uint32[] calldata secondsAgos)
    external view returns (int56[] memory tickCumulatives,
                           uint160[] memory secondsPerLiquidityCumulativeX128s);

// OracleLibrary (periphery)
function consult(address pool, uint32 secondsAgo)
    external view returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity);
```

### 2.2 Uniswap V4 Oracle Hooks

#### Repository and File Paths

- **V4 Core:** https://github.com/Uniswap/v4-core
  - `src/libraries/Hooks.sol` -- hook permission flags
- **V4 Periphery (example branches):**
  - `contracts/hooks/examples/GeomeanOracle.sol` (branch: `example-contracts`)
    - https://github.com/Uniswap/v4-periphery/blob/example-contracts/contracts/hooks/examples/GeomeanOracle.sol
  - `contracts/hooks/TruncGeoOracle.sol` (branch: `trunc-oracle`)
    - https://github.com/Uniswap/v4-periphery/blob/trunc-oracle/contracts/hooks/TruncGeoOracle.sol
  - `contracts/libraries/TruncatedOracle.sol` (branch: `trunc-oracle`)
    - https://github.com/Uniswap/v4-periphery/blob/trunc-oracle/contracts/libraries/TruncatedOracle.sol
- **Community hooks list:** https://github.com/johnsonstephan/awesome-uniswap-v4-hooks

#### Core Data Structure

The TruncatedOracle library replicates the V3 Observation pattern (ring buffer of tick cumulatives) but adds **truncation logic**: within a single block, the recorded price can only move up or down by a maximum delta (approximately 9,116 tick units). This blunts large-trade price impact and makes the oracle more manipulation-resistant.

The GeomeanOracle similarly stores tick cumulatives but computes geometric mean prices.

#### Volume Tracking Assessment

**Neither the TruncatedOracle nor GeomeanOracle track volume.** They are purely price (tick) oracles with enhanced manipulation resistance. No community V4 hook found in public repositories stores per-swap volume data on-chain as of this research date.

#### Library Pattern

- `TruncatedOracle.sol` is a Solidity **library** (same pattern as V3 Oracle.sol)
- `TruncGeoOracle.sol` is a V4 **hook contract** that uses the library
- Pools using these hooks must have full-range tick spacing with permanently locked liquidity

#### Composability

The library itself is composable (any hook could import TruncatedOracle and use it), but the hook contracts are pool-specific. There is no general-purpose volume oracle hook in the V4 ecosystem.

---

## 3. Balancer

### 3.1 Repository and File Paths

- **V2 Monorepo:** https://github.com/balancer/balancer-v2-monorepo
  - `pkg/pool-weighted/contracts/WeightedPool2Tokens.sol` -- oracle-enabled weighted pool (2 tokens only)
  - `pkg/pool-utils/contracts/oracle/PoolPriceOracle.sol` -- oracle ring buffer implementation
  - `pkg/solidity-utils/contracts/helpers/LogCompression.sol` -- log-space arithmetic for oracle samples
  - `pkg/pool-utils/contracts/oracle/Buffer.sol` -- ring buffer utilities
- **V3 Monorepo:** https://github.com/balancer/balancer-v3-monorepo
  - `pkg/pool-weighted/contracts/WeightedPool.sol` -- V3 weighted pool (no built-in oracle)

### 3.2 Core Data Structure

Balancer V2's oracle uses a **log-compressed sample buffer**. Each sample packs three values into a single `bytes32` storage slot using logarithmic compression:

- **logPairPrice** -- log2 of the pair price
- **logBptPrice** -- log2 of the BPT (pool token) price
- **logInvariant** -- log2 of the pool invariant

These are accumulated as time-weighted sums, similar to Uniswap's tick cumulatives but in log-space.

### 3.3 Volume Tracking Assessment

**Balancer V2 oracles track ZERO volume data.** They store only:
- Pair price (time-weighted, log-compressed)
- BPT price (time-weighted, log-compressed)
- Pool invariant (time-weighted, log-compressed)

**Balancer V3 removed the built-in oracle entirely.** The V3 WeightedPool has no oracle functionality; the team deprecated oracles as a core feature.

### 3.4 Library Pattern

`PoolPriceOracle` is an **abstract contract** (not a pure library) that pools inherit from. It uses `Buffer` library for ring buffer index management and `LogCompression` for packing/unpacking values. The oracle is deeply embedded in the pool inheritance hierarchy and cannot be used standalone.

### 3.5 Composability

**Low composability.** Oracle functionality is:
- Only available in 2-token weighted pools (not 3+ token pools, which are Balancer's primary use case)
- Deeply coupled to pool inheritance
- Deprecated in V3
- Not extractable as a standalone library

### 3.6 Storage Layout and Gas

- 1,024 samples in a ring buffer (10 bits of index)
- Each sample = 1 storage slot (32 bytes), log-compressed
- Write cost: ~5,000 gas per swap (warm SSTORE)
- Read cost: Binary search, O(log 1024) = ~10 SLOADs worst case

### 3.7 Key Interfaces

```solidity
// IPriceOracle (from Balancer V2)
struct OracleAverageQuery {
    Variable variable;  // PAIR_PRICE, BPT_PRICE, INVARIANT
    uint256 secs;       // duration of the average
    uint256 ago;        // how far in the past
}

function getTimeWeightedAverage(OracleAverageQuery[] memory queries)
    external view returns (uint256[] memory results);

function getLatest(Variable variable) external view returns (uint256);
function getLargestSafeQueryWindow() external view returns (uint256);
```

---

## 4. Curve Finance

### 4.1 Repository and File Paths

- **Organization:** https://github.com/curvefi
- **Tricrypto-NG:** https://github.com/curvefi/tricrypto-ng (Vyper)
- **Stableswap-NG:** https://github.com/curvefi/stableswap-ng (Vyper)
- **Classic tricrypto:** https://github.com/curvefi/curve-crypto-contract
  - `contracts/tricrypto/CurveCryptoSwap.vy`
- **Documentation:** https://docs.curve.finance/cryptoswap-exchange/tricrypto-ng/pools/oracles/

### 4.2 Core Data Structure

Curve does NOT use a ring buffer of observations. Instead, it uses a **single EMA (Exponential Moving Average) value** that is updated on every trade:

```python
# Pseudocode from Vyper implementation
alpha = exp(-(block.timestamp - last_timestamp) * 10**18 / ma_time)
price_oracle = last_price * (10**18 - alpha) + price_oracle_old * alpha
```

Key stored values:
- `price_oracle` -- EMA of the price (one per token pair relative to coin[0])
- `last_prices` -- the most recent spot price after a trade
- `last_prices_timestamp` -- when the oracle was last updated
- `ma_time` / `ma_exp_time` -- the EMA half-life (typically 600-866 seconds)

### 4.3 Volume Tracking Assessment

**Curve tracks ZERO volume data on-chain.** The oracle is purely a price EMA. There are no:
- Cumulative volume counters
- Per-trade volume recording
- Volume-weighted metrics
- Fee volume accumulators

Curve's `_tweak_price()` internal function updates `price_oracle` and `last_prices` but does not record the trade size (dx, dy) in any persistent oracle state. Trade sizes are emitted in events (`TokenExchange`) but not stored.

### 4.4 Library Pattern

Curve's oracle logic is **inline within the pool contract** (written in Vyper, not Solidity). There is no separate library, no plugin, and no standalone oracle contract. The EMA update is a few lines of code inside `_tweak_price()`.

### 4.5 Composability

**Minimal composability.** The oracle is:
- Inline Vyper code, not extractable
- Readable only through pool view functions (`price_oracle()`, `last_prices()`)
- No observation history (single EMA value, no ring buffer)
- Updates only once per block (prevents intra-block manipulation)

### 4.6 Storage Layout and Gas

- Storage: 2-3 slots total (price_oracle, last_prices, timestamp). Extremely minimal.
- Write cost: ~5,000 gas for the EMA update (one SSTORE per price pair)
- Read cost: Single SLOAD
- No historical data -- only the current EMA and last price

### 4.7 Key Interfaces

```python
# Vyper view functions (Tricrypto-NG)
@external
@view
def price_oracle(k: uint256) -> uint256:
    """Returns the EMA price for coin k relative to coin 0"""

@external
@view
def last_prices(k: uint256) -> uint256:
    """Returns the last traded price for coin k"""
```

---

## 5. PancakeSwap

### 5.1 Repository and File Paths

- **Organization:** https://github.com/pancakeswap
- **V3 contracts (Uniswap V3 fork):**
  - `pancake-v3-contracts/` -- contains forked Oracle.sol
  - Developer docs: https://developer.pancakeswap.finance/contracts/v3/pancakev3pool
- **V2 periphery:**
  - `pancake-swap-periphery/contracts/libraries/PancakeOracleLibrary.sol`
  - `pancake-swap-periphery/contracts/examples/ExampleSlidingWindowOracle.sol`

### 5.2 Core Data Structure

PancakeSwap V3 is a **direct fork of Uniswap V3** with minor fee tier differences. The Observation struct is identical:

```solidity
struct Observation {
    uint32  blockTimestamp;
    int56   tickCumulative;
    uint160 secondsPerLiquidityCumulativeX128;
    bool    initialized;
}
```

The only notable difference: PancakeSwap V3 uses a 0.25% fee tier with 50 tick spacing (vs. Uniswap's 0.3% / 60 tick spacing).

### 5.3 Volume Tracking Assessment

**Identical to Uniswap V3: no volume tracking.** Price (tick) and liquidity density only. PancakeSwap has not added any volume-related fields to their oracle fork.

### 5.4 Library Pattern

Same as Uniswap V3: `Oracle.sol` as a Solidity library embedded in the pool contract.

### 5.5 Algebra-Based Oracle (V4 / Algebra Fork)

PancakeSwap has explored Algebra-based pool designs for some chains. In those deployments, the oracle follows the Algebra DataStorage pattern (see Section 1). No additional volume tracking was added in PancakeSwap's Algebra forks.

### 5.6 Key Interfaces

Identical to Uniswap V3's `observe()` pattern:

```solidity
function observe(uint32[] calldata secondsAgos)
    external view returns (int56[] memory tickCumulatives,
                           uint160[] memory secondsPerLiquidityCumulativeX128s);
```

---

## 6. SushiSwap / Trident

### 6.1 Repository and File Paths

- **Trident:** https://github.com/sushiswap/trident
- **Sushi Oracle (V2 TWAP):** https://github.com/sushiswap/sushi-oracle
- **V3 Core (Uniswap V3 fork):** https://github.com/sushiswap/v3-core

### 6.2 Core Data Structure

**Trident:** Uses Uniswap V2-style cumulative price accumulators (`price0CumulativeLast`, `price1CumulativeLast`) with an innovative planned feature: storage proofs for instant TWAP snapshots. The storage proof approach would allow presenting a Merkle proof of a past storage slot to derive TWAP without on-chain ring buffers.

**SushiSwap V3:** Direct fork of Uniswap V3. Identical oracle (Observation struct, ring buffer, `observe()`).

### 6.3 Volume Tracking Assessment

**No volume tracking in any SushiSwap oracle.** Trident's TWAP oracle tracks price cumulatives only. The storage proof innovation is about cheaper reads, not richer data.

### 6.4 Library Pattern

- Trident: custom pool contracts with inline TWAP logic; pools can optionally disable TWAP to save gas
- V3: identical to Uniswap V3's Oracle.sol library

### 6.5 Composability

- Trident allows pool deployers to disable TWAP oracles as a gas optimization
- No standalone oracle library; TWAP logic is embedded in pool contracts
- The planned storage proof approach (if realized) would improve read composability but still only for price data

---

## 7. Other Protocols

### 7.1 Trader Joe / Liquidity Book (LFJ)

#### Repository and File Paths

- **joe-v2:** https://github.com/lfj-gg/joe-v2 (previously traderjoe-xyz/joe-v2)
  - `src/libraries/OracleHelper.sol` -- oracle helper library
  - `src/libraries/OracleSample.sol` -- sample encoding/decoding
  - `src/LBPair.sol` -- pair contract integrating the oracle

#### Core Data Structure: OracleSample

Each sample is packed into a single `bytes32` (32 bytes) using bit manipulation:

```
OracleSample {
    uint40  cumulativeId;              // cumulative active bin ID (analogous to tick cumulative)
    uint104 cumulativeVolatility;      // cumulative volatility accumulator
    uint40  cumulativeBinCrossed;      // cumulative number of bin crossings
    // (remaining bits for timestamp/metadata)
}
```

The **Volatility Accumulator** is the key innovation: it measures instantaneous volatility by tracking how many bins a swap crosses and how much time has elapsed since the last swap. This feeds into the "surge pricing" dynamic fee mechanism.

#### Volume Tracking Assessment

**Does NOT track raw volume.** Tracks:
- `cumulativeId` -- analogous to tick cumulative (price tracking)
- `cumulativeVolatility` -- a measure derived from bin crossings and time, NOT from trade amounts
- `cumulativeBinCrossed` -- how many bins were crossed (a proxy for price impact, not volume)

The Volatility Accumulator specifically counts bin-boundary crossings as a volatility signal. A large trade that crosses 10 bins registers differently from a small trade that crosses 1 bin, but the actual token amounts (volume) are not recorded.

#### Library Pattern

`OracleHelper.sol` and `OracleSample.sol` are Solidity **libraries** with internal functions. They operate on packed `bytes32` values. Clean library pattern similar to Uniswap's Oracle.sol.

#### Composability

Moderate -- the libraries are clean and could theoretically be imported by other contracts, but they are designed specifically for LBPair's storage layout and bin-based architecture. Not protocol-agnostic.

### 7.2 Maverick Protocol

#### Repository and File Paths

- **V2 examples:** https://github.com/maverickprotocol/maverick-v2-examples
- **Docs:** https://docs.mav.xyz/technical-reference/maverick-v2/

#### Core Data Structure

Maverick V2 stores a **Time-Weighted Average (TWA) state** accessible via `pool.getState()`:
- `activeTick` -- current active bin
- TWA price in 8-decimal scale in the fractional tick domain (e.g., 12.3e8 means 3/10ths into the 12th tick)

Maverick V2 uses a **programmable pool / accessor** pattern where an "accessor" smart contract is designated as the only address that can alter pool state (fees, etc.). Accessor contracts can read pool state and adjust fees based on external inputs (volume, price, oracles).

#### Volume Tracking Assessment

**No on-chain volume oracle.** Maverick stores price TWA data but not volume accumulators. The accessor pattern is designed for fee customization, not volume tracking. The documentation suggests accessors could theoretically read volume from events and adjust fees, but no on-chain volume accumulation exists.

### 7.3 Ambient / CrocSwap

#### Repository and File Paths

- **Protocol:** https://github.com/CrocSwap/CrocSwap-protocol
  - `contracts/mixins/KnockoutCounter.sol` -- knockout liquidity tracking
  - `docs/Layout.md` -- contract architecture documentation
- **Docs:** https://docs.ambient.finance/

#### Core Data Structure

Ambient uses a monolithic single-contract architecture with **sidecar contracts** for different functionalities (KnockoutPath, etc.). KnockoutCounter tracks LP positions for knockout (limit-order-like) liquidity.

#### Volume Tracking Assessment

**No dedicated volume oracle.** Ambient tracks:
- Knockout liquidity positions (entry/exit at specific ticks)
- Fee accumulation for positions
- Pool price state

No cumulative volume accumulators exist. The protocol focuses on gas efficiency through its monolithic design, which deprioritizes auxiliary data tracking.

#### Composability

Low -- the monolithic architecture means all logic lives in a single contract with sidecar delegates. There is no standalone oracle library to compose with.

---

## Comparative Analysis

### What Each Protocol's Oracle Actually Tracks

| Protocol | Price/Tick | Liquidity | Volatility | Volume | Per-Tick Volume | Library Pattern |
|----------|-----------|-----------|------------|--------|-----------------|-----------------|
| Uniswap V3 | tickCumulative | secondsPerLiquidity | No | No | No | Pure library (Oracle.sol) |
| Uniswap V4 (hooks) | tickCumulative (truncated) | No | No | No | No | Library + Hook |
| Algebra V1 | tickCumulative | secondsPerLiquidity | volatilityCumulative | volumePerLiquidity* | No | Standalone contract |
| Algebra Integral | tickCumulative | Removed | volatilityCumulative | Removed | No | Plugin contract |
| Balancer V2 | logPairPrice | logInvariant | No | No | No | Abstract contract |
| Balancer V3 | Removed | Removed | No | No | No | None (deprecated) |
| Curve | EMA price | No | No | No | No | Inline Vyper |
| PancakeSwap V3 | tickCumulative | secondsPerLiquidity | No | No | No | Library (fork) |
| SushiSwap/Trident | priceCumulative | No | No | No | No | Inline + library |
| Trader Joe LB | cumulativeId | No | cumulativeVolatility | No | No | Pure library |
| Maverick V2 | TWA price | No | No | No | No | Accessor pattern |
| Ambient | Pool state | Fee accumulators | No | No | No | Monolithic |

*Algebra V1's `volumePerLiquidityCumulative` is volume/liquidity ratio, not raw volume, and was removed in later versions.

### Library Pattern Comparison

| Pattern | Protocol | Composability | Pros | Cons |
|---------|----------|---------------|------|------|
| Pure Solidity library | Uniswap V3, Trader Joe | High (importable) | Clean separation, any contract can use | Operates on caller's storage, no cross-contract reads |
| Standalone contract | Algebra V1 | Medium | Independent deployment, readable | Tightly coupled to one pool |
| Plugin contract | Algebra Integral | Medium | Upgradeable, modular | One plugin per pool, not standalone |
| Abstract contract | Balancer V2 | Low | Deep integration | Must inherit, not composable |
| Hook contract | Uniswap V4 | Medium-High | Per-pool customization | V4-specific, hook address constraints |
| Inline code | Curve, Trident | Very Low | Minimal overhead | Not extractable |

---

## The Gap: What Does NOT Exist

### 1. No On-Chain Raw Volume Oracle

No existing protocol stores **raw cumulative volume** (actual token amounts traded) in an on-chain oracle. Every oracle focuses on price. Volume data exists only in:
- Transaction calldata (ephemeral)
- Event logs (off-chain only)
- Subgraph indexers (off-chain)

### 2. No Directional Volume Tracking

No protocol tracks **buy volume vs. sell volume** on-chain. Cumulative Volume Delta (CVD), a critical trading metric, cannot be computed from any existing on-chain oracle.

### 3. No Fee Volume Accumulators

While protocols track fees for LP position accounting, no protocol accumulates **total fee volume** as an oracle-readable metric.

### 4. No VWAP Accumulators

No protocol stores cumulative price*quantity and cumulative quantity values needed to compute on-chain VWAP.

### 5. No Volume Analytics (EMA, Z-Score, OBV, etc.)

Zero on-chain implementations of:
- Volume EMA (short/long)
- Volume z-score (Welford online algorithm)
- On-Balance Volume (OBV)
- Volume-Price Trend (VPT)
- Force Index
- Negative/Positive Volume Index (NVI/PVI)
- CUSUM regime detection

### 6. No Protocol-Agnostic Volume Oracle

Every oracle is tightly coupled to its parent protocol. No standalone, composable volume oracle exists that can:
- Receive volume data from multiple DEX protocols
- Expose uniform read interfaces
- Be deployed independently of any specific AMM

### 7. No Composable Reader Pattern for Volume

While Uniswap V3's `OracleLibrary.sol` provides a composable read layer for price data, no equivalent exists for volume data. External contracts (vaults, strategies, fee managers) cannot query on-chain volume metrics.

---

## Implications for volume-soldk-dev

### Confirmed Novel Position

The volume-soldk-dev project fills a genuine gap. Its architecture addresses every identified absence:

| Gap | volume-soldk-dev Solution |
|-----|---------------------------|
| No raw volume oracle | `VolumeAccumulatorsStorageMod` -- cumulative volumeA/B |
| No directional volume | Buy/sell volume + CVD accumulators |
| No fee volume | feeVolumeA/B accumulators |
| No VWAP | cumulativePQ + cumulativeQ accumulators |
| No volume analytics | `VolumeAnalyticsStorageMod` -- EMA, z-score, OBV, VPT, NVI/PVI, CUSUM, LVR |
| No protocol-agnostic design | Registry + delegatecall dispatch to protocol facets |
| No composable readers | Standalone `VolumeAccumulatorsReader`, `VolumeAnalyticsReader`, `VolumeEpochReader` |

### Design Validation from Existing Patterns

Several architectural choices in volume-soldk-dev are validated by patterns found in the research:

1. **Ring buffer / cumulative accumulator pattern** -- Proven by Uniswap V3 (Oracle.sol), Algebra (DataStorage), and Trader Joe (OracleHelper). The cumulative accumulator with time-weighting is the standard.

2. **Library + reader separation** -- Uniswap V3's Oracle.sol (library) + OracleLibrary.sol (reader) establishes this pattern. volume-soldk-dev's storage modules + reader contracts follow the same principle.

3. **Plugin/hook architecture** -- Algebra's plugin model and Uniswap V4's hook model both validate the "attach to pool, receive swap callbacks" approach. VolumeOracleHook follows this directly.

4. **Protocol facet dispatch** -- Novel to volume-soldk-dev. No existing protocol uses a registry + delegatecall pattern for multi-protocol oracle support. This is a genuine architectural innovation.

5. **Namespaced storage (Diamond-style)** -- Used in some DeFi protocols for upgradeable contracts. volume-soldk-dev's use of `keccak256("volumeOracle.accumulators")` etc. follows established patterns.

### Recommended Next Steps

1. **Prioritize the O(1) write path** -- Every successful oracle (Uniswap, Algebra, Trader Joe) keeps per-swap writes to O(1) with minimal SSTOREs. The current design's ~88 bytes per tier is aggressive; verify gas costs against the ~32-byte single-slot targets of mature oracles.

2. **Consider a ring buffer for historical volume** -- Current design uses only running accumulators (no historical snapshots). Adding an optional ring buffer of volume snapshots (like Uniswap's observation array) would enable time-windowed volume queries (e.g., "volume in the last hour").

3. **Benchmark against Algebra's removed fields** -- Algebra removed `volumePerLiquidityCumulative` in later versions, likely for gas reasons. Understand why and ensure the more comprehensive volume-soldk-dev metrics justify their gas overhead.

4. **Study Trader Joe's bit-packing** -- `OracleSample.sol` packs three accumulators into a single `bytes32` slot. Consider similar packing for Tier 1 accumulators to reduce SSTORE count.

5. **Leverage the "no competition" advantage** -- Since no existing volume oracle exists, even a minimal viable version (cumulative volumeA/B + buy/sell + CVD) would be first-to-market. Consider shipping Tier 1 before Tier 2 analytics.

---

## Sources

### Protocol Repositories
- [Uniswap V3 Core - Oracle.sol](https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/Oracle.sol)
- [Uniswap V3 Periphery - OracleLibrary.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/OracleLibrary.sol)
- [Uniswap V4 Periphery - TruncGeoOracle.sol](https://github.com/Uniswap/v4-periphery/blob/trunc-oracle/contracts/hooks/TruncGeoOracle.sol)
- [Uniswap V4 Periphery - GeomeanOracle.sol](https://github.com/Uniswap/v4-periphery/blob/example-contracts/contracts/hooks/examples/GeomeanOracle.sol)
- [Uniswap V4 Periphery - TruncatedOracle.sol](https://github.com/Uniswap/v4-periphery/blob/trunc-oracle/contracts/libraries/TruncatedOracle.sol)
- [Algebra Main Repository](https://github.com/cryptoalgebra/Algebra)
- [Algebra V1](https://github.com/cryptoalgebra/AlgebraV1)
- [Algebra Plugin Template](https://github.com/cryptoalgebra/algebra-plugin-template)
- [Algebra Integral Fee Simulation](https://github.com/cryptoalgebra/IntegralFeeSimulation)
- [Balancer V2 Monorepo](https://github.com/balancer/balancer-v2-monorepo)
- [Balancer V3 Monorepo](https://github.com/balancer/balancer-v3-monorepo)
- [Curve Tricrypto](https://github.com/curvefi/curve-crypto-contract)
- [Curve Stableswap-NG](https://github.com/curvefi/stableswap-ng)
- [PancakeSwap Periphery - Oracle Library](https://github.com/pancakeswap/pancake-swap-periphery/blob/master/contracts/libraries/PancakeOracleLibrary.sol)
- [SushiSwap Trident](https://github.com/sushiswap/trident)
- [SushiSwap Oracle](https://github.com/sushiswap/sushi-oracle)
- [Trader Joe V2 (LFJ)](https://github.com/lfj-gg/joe-v2)
- [Maverick V2 Examples](https://github.com/maverickprotocol/maverick-v2-examples)
- [CrocSwap/Ambient Protocol](https://github.com/CrocSwap/CrocSwap-protocol)

### Documentation
- [Uniswap Oracle Concepts](https://docs.uniswap.org/concepts/protocol/oracle)
- [Uniswap V3 Oracle Reference](https://docs.uniswap.org/contracts/v3/reference/core/libraries/Oracle)
- [Uniswap V4 Hooks Concepts](https://docs.uniswap.org/contracts/v4/concepts/hooks)
- [Uniswap V4 Truncated Oracle Blog](https://blog.uniswap.org/uniswap-v4-truncated-oracle-hook)
- [Algebra Integral Documentation](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/core-logic/plugins)
- [Algebra Integral Plugin Development Guide](https://docs.algebra.finance/algebra-integral-documentation/algebra-integral-technical-reference/guides/plugin-development)
- [Algebra API Reference V2.0](https://docs.algebra.finance/algebra-integral-documentation/algebra-v1-technical-reference/contracts/api-reference-v2.0)
- [Balancer V2 Oracles (deprecated)](https://balancer.gitbook.io/balancer-v2/products/oracles)
- [Curve Tricrypto-NG Oracles](https://docs.curve.finance/cryptoswap-exchange/tricrypto-ng/pools/oracles/)
- [Curve Stableswap-NG Oracles](https://docs.curve.finance/stableswap-exchange/stableswap-ng/pools/oracles/)
- [Curve Oracle Security Explained](https://news.curve.finance/curves-oracle-security-explained/)
- [PancakeSwap V3 Developer Docs](https://developer.pancakeswap.finance/contracts/v3/pancakev3pool)
- [Trader Joe Liquidity Book Docs](https://docs.traderjoexyz.com/)
- [Maverick V2 Pool Docs](https://docs.mav.xyz/technical-reference/maverick-v2/v2-contracts/maverick-v2-amm-contracts/maverickv2pool)
- [Ambient Finance Docs](https://docs.ambient.finance/)

### Analysis and Audits
- [Algebra Finance Plugins Audit (MixBytes)](https://github.com/mixbytes/audits_public/blob/master/Algebra%20Finance/Plugins/README.md)
- [Algebra Integral Plugins Technical Overview (Medium)](https://medium.com/@crypto_algebra/algebra-integral-plugins-technical-overview-315e6e7bc72f)
- [Chaos Labs - Uniswap V3 TWAP Deep Dive Pt. 1](https://chaoslabs.xyz/posts/chaos-labs-uniswap-v3-twap-deep-dive-pt-1)
- [Chaos Labs - Uniswap V3 TWAP Deep Dive Pt. 2](https://chaoslabs.xyz/posts/chaos-labs-uniswap-v3-twap-deep-dive-pt-2)
- [Uniswap V3 Price Oracle Development Book](https://uniswapv3book.com/milestone_5/price-oracle.html)
- [Hacken - Uniswap V4 Truncated Oracle Analysis](https://hacken.io/discover/uniswap-v4-truncated-oracle/)
- [Trader Joe V2 Code4rena Contest Report](https://code4rena.com/reports/2022-10-traderjoe)
- [Awesome Uniswap V4 Hooks (Community List)](https://github.com/johnsonstephan/awesome-uniswap-v4-hooks)
