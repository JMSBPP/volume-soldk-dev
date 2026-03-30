# Uniswap V4 Hooks Ecosystem: Volume-Per-Tick Research

**Date:** 2026-03-30
**Objective:** Determine whether any existing Uniswap V4 hook stores volume on a per-tick basis and exposes it as a composable library.
**Verdict:** **No.** No existing V4 hook stores volume on a per-tick basis and exposes it as a composable, standalone library. This is a clear gap in the ecosystem.

---

## Executive Summary

After exhaustive research across the Atrium Academy Hook Incubator registry, GitHub repositories, curated awesome-lists, the official Uniswap Hooklist registry, OpenZeppelin's composable hooks library, and all major known hook projects (Bunni V2, Angstrom/Sorella, Panoptic, Arrakis, Brokkr Finance), the conclusion is unambiguous:

1. **No hook tracks volume per tick.** Existing hooks track volume at the pool level (total swap amounts) or use volume as an aggregate proxy for volatility. None decompose volume into per-tick granularity.
2. **No composable volume library exists.** OpenZeppelin's uniswap-hooks library provides composable primitives for fees, custom accounting, custom curves, and a PanopticOracle -- but nothing for volume accumulation.
3. **The closest analogues** are Uniswap V3's `feeGrowthGlobal` / `feeGrowthOutside` accumulators (which track fee accrual, not raw volume, per tick) and the Truncated Oracle hook (which tracks cumulative tick for price, not volume).
4. **This represents a genuine whitespace opportunity.** Multiple protocols (Panoptic, dynamic fee hooks, volatility oracles) would benefit from per-tick volume data but currently compute it off-chain or approximate it through indirect means.

---

## 1. Atrium Academy / Uniswap Hook Incubator

**URL:** https://atrium.academy/uniswap
**Projects Directory:** https://projects.atrium.academy/Projects-ac153130871b49a2b1274906580e7869
**2025 Wrapped:** https://blog.atrium.academy/uniswap-hook-incubator-2025-wrapped

### Overview
- Nine-week cohort-based program funded by the Uniswap Foundation ($1.2M grant)
- ~500 graduates, 420+ hooks shipped, 7+ cohorts completed
- 2026 Hookathons focus on specialized markets and bespoke liquidity systems

### Volume-Related Findings
- The project directory contains hundreds of hook projects across cohorts
- **No projects specifically targeting per-tick volume tracking or volume oracles were identified** in the available listings
- Notable projects include UniCow (Coincidence of Wants), LVR & IL Hedgehook (dynamic fees + hedging), and various MEV-protection hooks
- The incubator has produced hooks in categories: MEV protection, dynamic fees, RWAs, stablecoins, lending, but volume oracles are absent from showcased work

### Assessment
| Criteria | Result |
|----------|--------|
| Volume tracking hooks found | No |
| Per-tick volume hooks found | No |
| Composable volume library found | No |

---

## 2. GitHub Search Results

### 2.1 Awesome Lists

#### fewwwww/awesome-uniswap-hooks
**URL:** https://github.com/fewwwww/awesome-uniswap-hooks

Lists the following oracle/data-related hooks:
- **GeomeanOracle** -- makes a pool function as a price oracle (geomean of tick, not volume)
- **Volatility Oracle** -- provides volatility data for options pricing (derived from price movement, not volume)
- **TWAMM** -- time-weighted average market maker (splits large orders over time; no volume tracking)
- **Limit Order** -- limit order execution (no volume tracking)
- **No volume oracle or per-tick volume hook listed**

#### johnsonstephan/awesome-uniswap-v4-hooks
**URL:** https://github.com/johnsonstephan/awesome-uniswap-v4-hooks

Comprehensive list including examples, tools, templates, and tutorials. References the same oracle implementations (GeomeanOracle, VolatilityOracle, TWAMM). **No volume oracle or per-tick volume tracking hook listed.**

#### AndreiD/awesome-uniswap-v4-resources
**URL:** https://github.com/AndreiD/awesome-uniswap-v4-resources

Lists IntegrumSwap (cross-chain RFQ), DiamondX, V4-orderbook, FlexFee (dynamic fees via volatility from Brevis), Vortex Protocol. **No volume oracle or per-tick volume tracking hook listed.**

### 2.2 Official Uniswap Repositories

#### Uniswap/hooklist (Hook Registry)
**URL:** https://github.com/Uniswap/hooklist

- Public registry of known V4 hook deployments across all supported chains
- Hooks stored in `hooklist.json` and individual files under `hooks/`, organized by chain
- Covers Ethereum, Unichain, Base, Arbitrum, Optimism, Polygon, Blast, Worldchain, Avalanche, BNB, Celo, Zora, Ink, Soneium
- **No volume oracle or per-tick volume hook registered**

#### Uniswap/v4-periphery (Example Contracts Branch)
**URL:** https://github.com/Uniswap/v4-periphery

Example hooks on the `example-contracts` branch:
- **GeomeanOracle.sol** -- full-range tick spacing oracle tracking cumulative tick (price), not volume
- **VolatilityOracle.sol** -- provides volatility-derived dynamic fees, does not track volume
- **TWAMM.sol** -- time-weighted order execution
- **LimitOrder.sol** -- limit order placement and execution
- **TruncGeoOracle.sol** (on `trunc-oracle` branch) -- truncated geometric mean price oracle with per-block tick movement cap

**None of these track volume. They all track price (tick) or time-based accumulators.**

#### Uniswap/v4-core Hooks.sol
**URL:** https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol

The core hooks library defines the 10 hook callbacks: `beforeInitialize`, `afterInitialize`, `beforeAddLiquidity`, `afterAddLiquidity`, `beforeRemoveLiquidity`, `afterRemoveLiquidity`, `beforeSwap`, `afterSwap`, `beforeDonate`, `afterDonate`. The `afterSwap` callback receives the swap delta (amounts in/out) which is the raw data needed to build a volume tracker, but the core does not accumulate this data.

### 2.3 Targeted Code Searches

The following search terms returned **zero** specific repositories with per-tick volume tracking:
- `"tickVolume"` in Solidity on GitHub
- `"volumePerTick"` in Solidity on GitHub
- `"volume accumulator"` + uniswap v4
- `"afterSwap"` + `"volume"` + `"tick"` in Solidity
- `"volume oracle"` + uniswap v4 hook
- `"cumulative volume"` + uniswap v4 hook
- `"VWAP"` + uniswap v4 hook
- `"volumeAccumulator"` in Solidity

---

## 3. Known Hook Projects -- Deep Dive

### 3.1 Bunni V2 (Timeless Finance / ZeframLou)

**Repository:** https://github.com/Bunniapp/bunni-v2
**Whitepaper:** https://github.com/Bunniapp/whitepaper/blob/main/bunni-v2.pdf
**Status:** Live on mainnet, dominant V4 hook (~59% of all V4 hook volume, ~$138M of $236M total)

#### What it does
- Shapeshifting DEX built on Uniswap V4
- Uses Liquidity Distribution Functions (LDFs) to dynamically reshape how liquidity is spread across ticks
- Rebalances positions based on trade flow
- Key libraries: BunniSwapMath, RebalanceLogic

#### Volume tracking
- **Does NOT track volume per tick on-chain**
- Bunni's LDF recalculates liquidity distribution across ticks/ranges based on market conditions
- Fee accrual is tracked through Uniswap's native fee growth mechanism, not a custom volume accumulator
- Rebalancing decisions likely incorporate off-chain volume signals, not on-chain per-tick volume state

#### Composability
- **Tightly coupled to the Bunni protocol** -- not a standalone library
- No composable volume utilities exposed

| Criteria | Result |
|----------|--------|
| Tracks volume? | No (on-chain) |
| Per-tick? | No |
| Standalone library? | No |
| Composable utilities? | No |

---

### 3.2 Angstrom (Sorella Labs)

**Repository:** https://github.com/SorellaLabs/angstrom
**Etherscan:** https://etherscan.io/address/0x0000000aa232009084bd71a5797d089aa4edfad4
**Status:** Live on mainnet (launched July 2025)

#### What it does
- MEV-resistant DEX hook
- Protects LPs from CEX-DEX arbitrage adverse selection
- Protects swappers from sandwich attacks
- CEX-DEX arbitrageurs bid for first-swap rights; bid proceeds distributed pro-rata to in-range LPs
- Uses off-chain consensus network (Angstrom nodes) for transaction ordering

#### Volume tracking
- **Does NOT track volume per tick**
- Tracks arbitrageur bids and distributes them to LPs in the swap range
- Uses TickLib.sol for tick-related computations, but for bid distribution, not volume accumulation
- Settlement.sol and PoolUpdates.sol handle pool state changes

#### Composability
- Tightly coupled to Angstrom's consensus network and MEV auction mechanism
- No composable volume utilities

| Criteria | Result |
|----------|--------|
| Tracks volume? | Tracks bid amounts, not trade volume |
| Per-tick? | Distributes bids per LP range, not per tick |
| Standalone library? | No |
| Composable utilities? | No |

---

### 3.3 Panoptic

**Repository:** https://github.com/panoptic-labs/panoptic-v1-core
**Audit repos:** https://github.com/code-423n4/2024-04-panoptic, https://github.com/code-423n4/2025-12-panoptic
**Status:** V1.1 live on mainnet with Uniswap V4 support

#### What it does
- Perpetual options protocol on Uniswap
- Treats LP positions as options (selling a put/call = providing concentrated liquidity)
- Uses "streamia" (streaming premium) model where fees collected by positions act as options premium
- V1.1 adds Uniswap V4 hook support (beforeSwap, afterSwap, etc.)

#### Volume tracking
- **Uses Uniswap's native fee growth accumulators** (feeGrowthGlobal, feeGrowthInside) as a proxy for volume
- Premium accumulation is tracked through fee growth, not raw volume
- PanopticPool.sol orchestrates calls to the SemiFungiblePositionManager (SFPM) to track premia
- **Does NOT maintain a separate volume-per-tick data structure**
- Volume data needed for options pricing (implied volatility) is derived off-chain

#### Composability
- OpenZeppelin's uniswap-hooks library includes a **PanopticOracle** component
- PanopticOracle focuses on **price data aggregation and manipulation resistance**, NOT volume tracking
- The oracle improves on tick-based price observations, not volume observations

| Criteria | Result |
|----------|--------|
| Tracks volume? | Indirectly via fee growth |
| Per-tick? | Uses feeGrowthOutside per tick (fees, not volume) |
| Standalone library? | PanopticOracle exists but tracks price, not volume |
| Composable utilities? | No volume utilities |

---

### 3.4 Arrakis Finance

**Documentation:** https://docs.arrakis.finance/text/modules/uniV4Module.html
**Hook docs:** https://docs.arrakis.finance/text/introduction/integrations/uniV4Hook.html
**V2 Core:** https://github.com/ArrakisFinance/v2-core
**Status:** Active, $20B+ cumulative trading volume facilitated

#### What it does
- Onchain market making for token issuers (Protocol Owned Liquidity)
- Vaults managing concentrated liquidity positions on Uniswap
- V4 integration via ArrakisProHook for dynamic swap fees
- Uses oracles to protect rebalances against attacks

#### Volume tracking
- **Does NOT track volume per tick**
- Vaults manage liquidity positions and rebalance, but volume tracking is at the vault/pool level
- Oracle usage is for price protection during rebalances, not volume measurement

| Criteria | Result |
|----------|--------|
| Tracks volume? | At vault level only |
| Per-tick? | No |
| Standalone library? | No |
| Composable utilities? | No |

---

### 3.5 Brokkr Finance (Dynamic Fees by Volume Hook)

**Article:** https://brokkrfinance.medium.com/dynamic-fees-by-volume-uniswapv4-hook-072d3dcfac2d
**Overview:** https://brokkrfinance.medium.com/overview-of-brokkr-hooks-for-uniswapv4-d37d1e9c272a
**Status:** Proof of Concept (Uniswap Foundation grant)

#### What it does
- Adjusts swap fees based on trading volume
- Uses volume as a proxy for volatility
- When swap volume exceeds a threshold, fee increases by 0.01% per threshold crossing
- If no transactions within a timeout (e.g., 100 seconds), fee decreases by 0.01%
- Anti-manipulation: reverts if less than 99% of initial tokens are swapped

#### Volume tracking
- **Tracks aggregate volume per pool** (total swap amounts crossing threshold)
- **Does NOT track volume per tick**
- Volume is measured as a running aggregate against a threshold, not decomposed by tick
- No per-tick data structure

#### Composability
- Built as a hook POC, not a composable library
- No GitHub repository found publicly (Medium articles only)
- Tightly coupled to the dynamic fee logic

| Criteria | Result |
|----------|--------|
| Tracks volume? | Yes -- aggregate per pool |
| Per-tick? | No |
| Standalone library? | No (POC) |
| Composable utilities? | No |

**This is the closest existing project to volume tracking in a V4 hook, but it operates at pool-level granularity, not per-tick.**

---

### 3.6 GammaSwap

- **No Uniswap V4 hook found.** GammaSwap operates as a volatility trading protocol but has not shipped a V4 hook with volume tracking capabilities based on available research.

---

### 3.7 VolatilityHook-UniV4 (0xekkila)

**Repository:** https://github.com/0xekkila/VolatilityHook-UniV4

#### What it does
- Uses Brevis (ZK coprocessor) to bring cross-DEX realized volatility data on-chain
- Feeds realized volatility into a dynamic fee hook
- ETH/USDC focused

#### Volume tracking
- **Does NOT track volume per tick**
- Tracks realized volatility from off-chain price data, not on-chain volume
- No per-tick data structures

| Criteria | Result |
|----------|--------|
| Tracks volume? | No |
| Per-tick? | No |
| Standalone library? | No |
| Composable utilities? | No |

---

### 3.8 FlexFee

- Dynamic fee hook using volatility from Brevis and swap size
- **Does NOT track volume per tick**
- Protects LPs from impermanent loss using fee adjustments
- No per-tick volume data structures

---

## 4. Composable Libraries and Frameworks

### 4.1 OpenZeppelin Uniswap Hooks Library

**Repository:** https://github.com/OpenZeppelin/uniswap-hooks
**Docs:** https://docs.openzeppelin.com/uniswap-hooks
**Wizard:** https://wizard.openzeppelin.com/uniswap-hooks
**License:** MIT

#### Components
| Module | Purpose | Volume Related? |
|--------|---------|-----------------|
| BaseHook | Base hook implementation | No |
| BaseCustomAccounting | Custom accounting with swap/liquidity management | No |
| BaseCustomCurve | Custom AMM curves | No |
| BaseAsyncSwap | Asynchronous swap execution | No |
| BaseDynamicFee | Manual dynamic fee application | No |
| BaseOverrideFee | Fee override before swap | No |
| BaseDynamicAfterFee | Fee based on delta after swap | No |
| PanopticOracle | Price oracle with manipulation resistance | No -- price only |
| SandwichProtection | MEV sandwich protection | No |

#### Assessment
- **No volume tracking module exists**
- **No per-tick accumulator module exists**
- The PanopticOracle tracks price observations, not volume
- Fee modules adjust fees but do not accumulate volume data
- This is the most natural home for a composable volume-per-tick library, but it does not yet exist

### 4.2 Uniswap Foundation Hook Data Standards

**URL:** https://www.uniswapfoundation.org/blog/developer-guide-establishing-hook-data-standards-for-uniswap-v4
**Mirror:** https://uniswapfoundation.mirror.xyz/KGKMZ2Gbc_I8IqySVUMrEenZxPnVnH9-Qe4BlN1qn0g

#### Key Definitions
- **Total Volume:** Cumulative trading volume across all V4 pools within a timeframe
- **Hooked Volume:** Trading volume in hooked pools, including return-delta-based swaps
- **Hook Data Events:** Proposed standard events for hooks to emit so indexers can track volume, TVL, and fees accurately
- When `BeforeSwapReturnDelta` or `AfterSwapReturnDelta` flags are enabled, the `Swap` event alone is insufficient for volume calculations

#### Assessment
- **These are off-chain indexing standards, not on-chain per-tick accumulators**
- The framework acknowledges the difficulty of on-chain volume tracking
- Volume is calculated by indexers reading events, not stored on-chain per tick
- This confirms that the ecosystem approach to volume is event-based and off-chain, not on-chain per-tick

---

## 5. Closest Analogues (Non-Volume)

### 5.1 Uniswap V3 Fee Growth Accumulators

Uniswap V3 (and V4 via the PoolManager) tracks:
- `feeGrowthGlobal0X128` / `feeGrowthGlobal1X128` -- cumulative fees per unit of liquidity globally
- `feeGrowthOutside0X128` / `feeGrowthOutside1X128` -- fee growth accumulated on the "other side" of each initialized tick

These are the closest existing on-chain per-tick data structures, but they track **fee accrual** (proportional to volume * fee rate / liquidity), not **raw volume**. The relationship is:

```
feeGrowth ~= volume * feeRate / liquidity
```

You cannot recover raw volume from fee growth without knowing the exact liquidity at every tick at every point in time.

### 5.2 Truncated Oracle Hook

Tracks cumulative tick (price) observations with a per-block movement cap. This is the closest on-chain accumulator pattern but for price, not volume.

### 5.3 GeomeanOracle

Tracks geometric mean of price using cumulative tick accumulators. Again, price-only.

---

## 6. Why Per-Tick Volume Does Not Exist Yet

### Technical Challenges
1. **Gas costs:** Updating a per-tick volume accumulator on every swap crossing multiple ticks is expensive. A swap crossing N ticks would require N storage writes.
2. **Tick granularity:** V4 pools can have tick spacing as small as 1, creating potentially millions of ticks to track.
3. **Cross-tick swaps:** A single swap may cross many ticks, each receiving a different fraction of the swap volume. Decomposing volume per tick requires iterating through the swap's tick-crossing path.
4. **Storage costs:** Persistent per-tick volume accumulators require growing storage. Without pruning, this grows unboundedly.
5. **Undefined demand signal:** Until now, no major protocol has shipped a product that requires on-chain per-tick volume, so no one has built it.

### Off-Chain Alternatives
- Subgraphs and indexers can reconstruct per-tick volume from `Swap` events + pool state
- The Uniswap Foundation's Hook Data Standards are designed for this off-chain approach
- Most protocols needing volume data (Panoptic, dynamic fee hooks) use off-chain computation or proxies (fee growth)

---

## 7. Implications for Volume Oracle Development

### The Gap
A composable, on-chain volume-per-tick accumulator would be a first-of-its-kind primitive in the Uniswap V4 ecosystem. No existing project provides this.

### Potential Design Patterns
Drawing from existing accumulator patterns in the ecosystem:

1. **Fee-growth-style accumulator:** Mirror `feeGrowthOutside` but for volume. Store `volumeGrowthOutside0X128` / `volumeGrowthOutside1X128` per initialized tick. Update on tick crossings during swaps.
2. **Observation-style snapshots:** Mirror the V3 oracle observation array but store cumulative volume instead of cumulative tick. Query volume over time windows.
3. **Hybrid approach:** Store aggregate volume at checkpoints (e.g., per block or per time window) and decompose into per-tick using the pool's tick bitmap and liquidity distribution.

### Potential Consumers
- **Options protocols** (Panoptic): Need per-tick volume for implied volatility pricing
- **Dynamic fee hooks** (Brokkr, FlexFee): Could use per-tick volume for more granular fee adjustment
- **Volatility oracles**: Volume is a key input to realized volatility calculation
- **LP analytics**: Understanding which ticks generate the most volume for position optimization
- **MEV analysis**: Per-tick volume reveals where MEV extraction is concentrated

### Composability Considerations
- Should follow OpenZeppelin's uniswap-hooks library patterns (BaseHook, modular components)
- Should emit events following Uniswap Foundation Hook Data Standards
- Should be usable as a standalone hook or composable with other hooks
- Must manage gas costs carefully (lazy evaluation, checkpoint patterns, configurable tick granularity)

---

## 8. Summary Table: All Projects Evaluated

| Project | Repository | Tracks Volume? | Per-Tick? | Composable Library? | Notes |
|---------|-----------|----------------|-----------|---------------------|-------|
| Bunni V2 | github.com/Bunniapp/bunni-v2 | No (on-chain) | No | No | Dominant V4 hook, LDF-based |
| Angstrom (Sorella) | github.com/SorellaLabs/angstrom | Bid amounts only | No | No | MEV protection, consensus network |
| Panoptic | github.com/panoptic-labs/panoptic-v1-core | Via fee growth proxy | No | PanopticOracle (price only) | Options protocol |
| Arrakis | github.com/ArrakisFinance/v2-core | Vault-level only | No | No | Market making vaults |
| Brokkr Finance | Medium articles only | Yes (aggregate) | No | No (POC) | Dynamic fees by volume |
| GammaSwap | N/A | N/A | N/A | N/A | No V4 hook found |
| VolatilityHook | github.com/0xekkila/VolatilityHook-UniV4 | No | No | No | RV from Brevis ZK coprocessor |
| FlexFee | N/A | No | No | No | Volatility-based fees |
| GeomeanOracle | v4-periphery example-contracts | No (price only) | No | No | Price oracle |
| TruncGeoOracle | v4-periphery trunc-oracle | No (price only) | No | No | Truncated price oracle |
| VolatilityOracle | v4-periphery example-contracts | No | No | No | Volatility for dynamic fees |
| TWAMM | v4-periphery example-contracts | No | No | No | Time-weighted order execution |
| OpenZeppelin Hooks | github.com/OpenZeppelin/uniswap-hooks | No | No | Yes (but no volume module) | Composable hooks framework |
| Uniswap Hooklist | github.com/Uniswap/hooklist | N/A (registry) | N/A | N/A | Hook deployment registry |

---

## 9. Critical Answer

**Does ANY existing V4 hook store volume on a per-tick basis and expose it as a composable library?**

**No.**

- No hook stores volume per tick at all (on-chain).
- The closest is Brokkr Finance's dynamic fee hook, which tracks aggregate pool-level volume against a threshold -- but not per tick, and not as a library.
- OpenZeppelin's uniswap-hooks library is the most natural integration point for such a composable primitive, but it currently contains no volume module.
- The Uniswap Foundation's Hook Data Standards explicitly approach volume tracking as an off-chain indexing problem, not an on-chain accumulator problem.
- Fee growth accumulators (from V3/V4 core) are the closest on-chain per-tick data, but they track fees, not raw volume, and the two cannot be trivially converted.

**This is greenfield territory.**

---

## Sources

- [Atrium Academy - Uniswap Hook Incubator](https://atrium.academy/uniswap)
- [UHI Projects Directory](https://projects.atrium.academy/Projects-ac153130871b49a2b1274906580e7869)
- [Uniswap Hook Incubator: 2025 Wrapped](https://blog.atrium.academy/uniswap-hook-incubator-2025-wrapped)
- [Uniswap Foundation - Introducing the Hook Incubator](https://uniswapfoundation.mirror.xyz/-_H_7xF5GrN6n49KEiiuqXNf-X6BDlZFp9mocOnVjnw)
- [Uniswap Foundation - Hook Data Standards](https://www.uniswapfoundation.org/blog/developer-guide-establishing-hook-data-standards-for-uniswap-v4)
- [Uniswap Foundation - How to Navigate V4 Data](https://uniswapfoundation.mirror.xyz/c7LDDTWhC2ry6gp0nGqcSKHvNHosJmhPQ-ZuIxqeB2I)
- [Uniswap V4 Truncated Oracle Hook](https://blog.uniswap.org/uniswap-v4-truncated-oracle-hook)
- [Uniswap V4 TWAMM Hook](https://blog.uniswap.org/v4-twamm-hook)
- [Uniswap V4 Docs - Hooks](https://docs.uniswap.org/contracts/v4/concepts/hooks)
- [Uniswap V4 Docs - Dynamic Fees](https://docs.uniswap.org/contracts/v4/concepts/dynamic-fees)
- [Uniswap Hooklist Registry](https://github.com/Uniswap/hooklist)
- [Uniswap v4-periphery - GeomeanOracle.sol](https://github.com/Uniswap/v4-periphery/blob/example-contracts/contracts/hooks/examples/GeomeanOracle.sol)
- [Uniswap v4-periphery - TruncGeoOracle.sol](https://github.com/Uniswap/v4-periphery/blob/trunc-oracle/contracts/hooks/TruncGeoOracle.sol)
- [Uniswap v4-core - Hooks.sol](https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol)
- [OpenZeppelin Uniswap Hooks Library](https://github.com/OpenZeppelin/uniswap-hooks)
- [OpenZeppelin Uniswap Hooks Docs](https://docs.openzeppelin.com/uniswap-hooks)
- [OpenZeppelin Uniswap Hooks Wizard](https://wizard.openzeppelin.com/uniswap-hooks)
- [fewwwww/awesome-uniswap-hooks](https://github.com/fewwwww/awesome-uniswap-hooks)
- [johnsonstephan/awesome-uniswap-v4-hooks](https://github.com/johnsonstephan/awesome-uniswap-v4-hooks)
- [AndreiD/awesome-uniswap-v4-resources](https://github.com/AndreiD/awesome-uniswap-v4-resources)
- [Bunni V2 Repository](https://github.com/Bunniapp/bunni-v2)
- [Bunni V2 Whitepaper](https://github.com/Bunniapp/whitepaper/blob/main/bunni-v2.pdf)
- [Bunni - Research by Auditless](https://research.auditless.com/p/bunni-how-to-build-a-leading-uniswap)
- [Angstrom (Sorella Labs) Repository](https://github.com/SorellaLabs/angstrom)
- [Angstrom Overview Docs](https://github.com/SorellaLabs/angstrom/blob/main/contracts/docs/overview.md)
- [Sorella Labs - Fair Markets](https://sorellalabs.xyz/writing/a-new-era-of-defi-with-ass)
- [Panoptic - Launch on Uniswap V4](https://panoptic.xyz/blog/panoptic-launches-on-uniswap-v4)
- [Panoptic V1 Core](https://github.com/panoptic-labs/panoptic-v1-core)
- [Arrakis V4 Module Docs](https://docs.arrakis.finance/text/modules/uniV4Module.html)
- [Arrakis V4 Hook Docs](https://docs.arrakis.finance/text/introduction/integrations/uniV4Hook.html)
- [Arrakis V2 Core](https://github.com/ArrakisFinance/v2-core)
- [Brokkr Finance - Dynamic Fees by Volume](https://brokkrfinance.medium.com/dynamic-fees-by-volume-uniswapv4-hook-072d3dcfac2d)
- [Brokkr Finance - Overview of Hooks](https://brokkrfinance.medium.com/overview-of-brokkr-hooks-for-uniswapv4-d37d1e9c272a)
- [0xekkila/VolatilityHook-UniV4](https://github.com/0xekkila/VolatilityHook-UniV4)
- [DWF Labs - Uniswap V4 in 2025](https://www.dwf-labs.com/research/457-what-s-new-in-uniswap-v4-three-key-changes-and-two-new-protocols)
- [Uniswap V3 Tick Library](https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/Tick.sol)
- [Uniswap V3 Core Whitepaper](https://berkeley-defi.github.io/assets/material/Uniswap%20v3%20Core.pdf)
