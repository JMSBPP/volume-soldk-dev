# Definitive Reference: Volume Metrics for DeFi/AMM/DEX Contexts

**Date**: 2026-03-26
**Purpose**: Exhaustive catalog of every volume metric applicable to decentralized exchange and automated market maker analysis, with definitions, formulas, significance, computational complexity, and on-chain feasibility assessment.

---

## Table of Contents

1. [Raw Volume Metrics](#1-raw-volume-metrics)
2. [Derived / Computed Volume Metrics (Traditional)](#2-derived--computed-volume-metrics-traditional)
3. [DeFi-Specific Volume Metrics](#3-defi-specific-volume-metrics)
4. [Statistical Volume Metrics](#4-statistical-volume-metrics)
5. [Time-Series Volume Features](#5-time-series-volume-features)
6. [On-Chain vs Off-Chain Feasibility Summary](#6-on-chain-vs-off-chain-feasibility-summary)

---

## Notation Conventions

Throughout this document:

- `V_t` = volume at time t (or in period t)
- `P_t` = price at time t
- `C_t`, `H_t`, `L_t`, `O_t` = close, high, low, open price at time t
- `n` = number of periods in a window
- `EMA(X, k)` = exponential moving average of X over k periods
- `SMA(X, k)` = simple moving average of X over k periods
- `sigma` = standard deviation
- All summations use 1-based indexing unless stated otherwise

---

## 1. Raw Volume Metrics

These are the foundational, directly observable volume measurements.

### 1.1 Total Trading Volume (USD-denominated)

**Definition**: The aggregate notional value of all trades executed within a given time period, expressed in USD (or another fiat-equivalent stablecoin).

**Formula**:
```
V_usd(T) = SUM over all trades i in period T of (q_i * P_i)
```
where `q_i` is the quantity of token traded and `P_i` is the USD price at trade execution.

**What it measures / Why it matters**: The most fundamental activity metric for any exchange. It indicates total economic throughput. Used for ranking DEXes, measuring protocol adoption, and calculating fee revenue.

**Time complexity**: O(n) where n is the number of trades in the period. Each swap event emits volume data that must be accumulated.

**On-chain feasibility**: FULLY FEASIBLE on-chain. Every swap already records amounts. An accumulator variable in the pool contract can track cumulative volume. The main challenge is USD denomination, which requires a price oracle. Most implementations store token-denominated volume on-chain and compute USD off-chain.

---

### 1.2 Total Trading Volume (Token-denominated)

**Definition**: The aggregate quantity of a specific token traded within a time period, without USD conversion.

**Formula**:
```
V_token(T) = SUM over all trades i in period T of q_i
```

**What it measures / Why it matters**: Avoids oracle dependency. Directly observable from swap events. Useful for computing ratios like volume/TVL in native terms.

**Time complexity**: O(n) where n is number of trades.

**On-chain feasibility**: FULLY FEASIBLE. Trivially computed as a running sum in the pool contract. Solana programs can maintain a u128 accumulator updated on every swap instruction.

---

### 1.3 Buy Volume vs Sell Volume

**Definition**: Volume decomposed by trade direction. In an AMM context, "buy volume" typically means volume where the trader is acquiring Token A (selling Token B), and "sell volume" is the reverse.

**Formula**:
```
V_buy(T)  = SUM of q_i for all trades i in T where direction_i = BUY
V_sell(T) = SUM of q_i for all trades i in T where direction_i = SELL
```

Direction classification in AMMs: A swap of Token B for Token A is a "buy" of Token A. The direction is inherent in the swap function called (e.g., `swap_b_to_a` vs `swap_a_to_b`).

**What it measures / Why it matters**: Reveals directional pressure. A market with heavily skewed buy/sell ratio signals demand imbalance. Critical input for volume delta, CVD, and flow toxicity metrics.

**Time complexity**: O(n) with a simple conditional accumulator.

**On-chain feasibility**: FULLY FEASIBLE. Two accumulators (buy_volume, sell_volume) updated per swap based on the swap direction. Minimal additional compute.

---

### 1.4 Volume Per Token Pair

**Definition**: Trading volume isolated to a specific token pair (e.g., SOL/USDC, ETH/USDT).

**Formula**:
```
V_pair(A,B,T) = SUM of q_i for all trades i in pool(A,B) during period T
```

**What it measures / Why it matters**: Essential for multi-pool DEX analytics. Identifies which pairs drive the most activity. Used for fee tier optimization and liquidity incentive allocation.

**Time complexity**: O(1) per swap if each pool tracks its own volume (natural in AMM architecture where each pool is a separate contract/account).

**On-chain feasibility**: FULLY FEASIBLE. Each pool contract naturally tracks its own volume. This is the default architecture in Uniswap, Raydium, Orca, etc.

---

### 1.5 Volume Per Time Window

**Definition**: Volume aggregated over standard time intervals: 1m, 5m, 15m, 1h, 4h, 1d, 7d, 30d.

**Formula**:
```
V_window(w) = SUM of q_i for all trades i where timestamp_i is in window w
```

**What it measures / Why it matters**: Time-bucketed volume is the foundation for all time-series analysis. Different windows serve different purposes: 1m for microstructure analysis, 1h for intraday patterns, 1d for trend analysis, 30d for macro views.

**Time complexity**: O(1) per swap for accumulation. O(1) for reading a specific window if pre-computed. Maintaining rolling windows requires either checkpoint-based snapshots or ring buffer approaches.

**On-chain feasibility**: PARTIALLY FEASIBLE. Cumulative volume with timestamps is trivially on-chain. However, maintaining pre-bucketed time windows (e.g., "volume in the last 1 hour") requires either:
- A checkpoint/snapshot system where an oracle or crank periodically records cumulative volume (the difference between two checkpoints gives the window volume)
- Ring buffer with fixed slots (high storage cost on Solana at ~0.00089 SOL per byte of rent)

Most practical approach: store cumulative volume + last-update timestamp on-chain; compute windowed volumes off-chain from event logs or snapshots.

---

## 2. Derived / Computed Volume Metrics (Traditional)

These metrics originate from traditional technical analysis and quantitative finance, adapted for DeFi.

### 2.1 VWAP (Volume Weighted Average Price)

**Definition**: The average price of an asset weighted by volume traded at each price level over a specified period.

**Formula**:
```
VWAP(T) = SUM(P_i * q_i) / SUM(q_i)  for all trades i in period T
```

**What it measures / Why it matters**: VWAP represents the "fair" average execution price. Institutional traders benchmark execution quality against VWAP. In DeFi, VWAP is used by oracle systems (Chainlink uses a VWAP-based approach across multiple venues) and for detecting price manipulation.

**Time complexity**: O(n) for n trades, but can be maintained incrementally with two running accumulators (sum of P*q and sum of q), making per-swap cost O(1).

**On-chain feasibility**: FEASIBLE with accumulators. Store `cumulative_pq` (sum of price times quantity) and `cumulative_q` (sum of quantity). VWAP for any period is computable from the difference of two snapshots: `(cumulative_pq_end - cumulative_pq_start) / (cumulative_q_end - cumulative_q_start)`. This is the approach used by Uniswap v2/v3 oracle accumulators (though Uniswap uses TWAP, the same pattern applies to VWAP). Requires ~32 bytes of additional on-chain storage.

---

### 2.2 Volume Simple Moving Average (Volume SMA)

**Definition**: The arithmetic mean of volume over the last n periods.

**Formula**:
```
SMA_V(t, n) = (1/n) * SUM from i=0 to n-1 of V_(t-i)
```

**What it measures / Why it matters**: Smooths volume fluctuations to identify the underlying volume trend. A rising SMA suggests increasing participation; a declining SMA suggests waning interest. Common windows: 10, 20, 50 periods.

**Time complexity**: O(n) for initial computation; O(1) for incremental updates using a sliding window sum (add new, subtract oldest).

**On-chain feasibility**: DIFFICULT on-chain. Requires storing the last n period volumes to perform the sliding window subtraction. For a 20-period SMA with hourly buckets, that is 20 stored values. Feasible but storage-expensive on Solana. Better computed off-chain with on-chain verification via snapshots.

---

### 2.3 Volume Exponential Moving Average (Volume EMA)

**Definition**: An exponentially weighted moving average that gives more weight to recent volume observations.

**Formula**:
```
EMA_V(t, k) = alpha * V_t + (1 - alpha) * EMA_V(t-1, k)
where alpha = 2 / (k + 1)
```

**What it measures / Why it matters**: More responsive than SMA to recent changes. Widely used as a component in other indicators (Klinger, MACD-Volume). The EMA reacts faster to volume spikes, making it preferable for real-time alerting.

**Time complexity**: O(1) per update -- only requires the previous EMA value and the current volume.

**On-chain feasibility**: FEASIBLE. Requires storing only one value (the previous EMA) plus a fixed-point multiplication per update. The key challenge is defining "periods" on-chain (block-based vs time-based). EMA updates can be triggered per-swap or per-block. Fixed-point arithmetic for `alpha` is well-supported on Solana via u128 or i128 with scaling.

---

### 2.4 Volume Rate of Change (VROC)

**Definition**: The percentage change in volume relative to a prior period.

**Formula**:
```
VROC(t, n) = ((V_t - V_(t-n)) / V_(t-n)) * 100
```

**What it measures / Why it matters**: Measures the acceleration or deceleration of volume. A sharply rising VROC indicates volume surge (potential breakout). A falling VROC with rising price suggests a weakening trend (bearish divergence).

**Time complexity**: O(1) per computation given stored historical volume. Requires access to V_(t-n).

**On-chain feasibility**: PARTIALLY FEASIBLE. Requires storing at least one historical volume checkpoint (the value n periods ago). With a ring buffer of checkpoints, this becomes feasible. Simpler with off-chain computation.

---

### 2.5 Volume Momentum

**Definition**: The difference (not ratio) between current volume and volume n periods ago.

**Formula**:
```
VMom(t, n) = V_t - V_(t-n)
```

**What it measures / Why it matters**: Similar to VROC but in absolute terms. Useful when percentage changes are misleading due to low base volumes.

**Time complexity**: O(1) given stored checkpoints.

**On-chain feasibility**: Same as VROC -- requires historical volume storage.

---

### 2.6 Volume Oscillator

**Definition**: The difference between two volume moving averages (typically a short and long EMA), often expressed as a percentage.

**Formula**:
```
VO(t) = ((EMA_V(t, short) - EMA_V(t, long)) / EMA_V(t, long)) * 100
```
Common settings: short = 5, long = 20.

**What it measures / Why it matters**: Identifies whether volume is expanding or contracting relative to its own trend. Positive values indicate volume expansion; negative values indicate contraction. Useful for confirming price breakouts.

**Time complexity**: O(1) per update (two EMA updates + division).

**On-chain feasibility**: FEASIBLE. Requires storing two EMA values. Each swap or period update performs two EMA calculations. Total additional storage: ~32 bytes.

---

### 2.7 Relative Volume (RVOL)

**Definition**: Current volume expressed as a multiple of the historical average volume for the same time period.

**Formula**:
```
RVOL(t) = V_t / SMA_V(t, n)
```
Or more precisely, for intraday context:
```
RVOL(t) = V_current_period / AVG(V_same_period_over_last_n_days)
```

**What it measures / Why it matters**: Contextualizes volume relative to what is "normal." RVOL > 2 means current volume is 2x the average -- signals unusual activity. Critical for anomaly detection, whale detection, and event-driven analysis.

**Time complexity**: O(1) per computation given a pre-computed average.

**On-chain feasibility**: PARTIALLY FEASIBLE. The denominator (historical average) must be maintained, which requires periodic snapshots. An EMA-based approximation is more practical: `RVOL_approx = V_t / EMA_V(t, n)`, which requires only one stored EMA value.

---

### 2.8 Volume Profile (at Price Levels)

**Definition**: A histogram showing volume traded at each price level (or price range) over a specified period.

**Formula**:
```
VP(p, T) = SUM of q_i for all trades i in T where P_i is in price_bucket(p)
```
Price buckets are typically defined by rounding to the nearest tick or percentage band.

**What it measures / Why it matters**: Reveals price levels where the most trading occurred -- these become support/resistance zones. The "Point of Control" (POC) is the price level with the highest volume. In concentrated liquidity AMMs (Uniswap v3, Orca Whirlpools), this directly maps to tick-level liquidity utilization.

**Time complexity**: O(n) for n trades, O(k) storage for k price buckets.

**On-chain feasibility**: DIFFICULT. Requires maintaining a histogram of volume per price bucket, which grows linearly with the number of distinct price levels traded. In concentrated liquidity AMMs, tick-level volume tracking is somewhat natural (each tick already tracks crossings), but full volume profile storage is expensive. Better suited to off-chain indexing of swap events with on-chain checksum verification.

---

### 2.9 Volume Delta (Buy-Sell Imbalance)

**Definition**: The net difference between buy volume and sell volume in a given period.

**Formula**:
```
Delta(T) = V_buy(T) - V_sell(T)
```

**What it measures / Why it matters**: The most direct measure of directional pressure. Positive delta = net buying pressure; negative delta = net selling pressure. In AMM context, sustained positive delta with rising price confirms bullish conviction. Delta divergence (price rising but delta falling) signals potential reversal.

**Time complexity**: O(1) per swap (increment or decrement a single accumulator).

**On-chain feasibility**: FULLY FEASIBLE. A single signed accumulator (i128) that adds buy volume and subtracts sell volume. Extremely cheap to maintain.

---

### 2.10 Cumulative Volume Delta (CVD)

**Definition**: The running sum of volume delta over time.

**Formula**:
```
CVD(t) = SUM from i=0 to t of Delta(i) = SUM from i=0 to t of (V_buy(i) - V_sell(i))
```

**What it measures / Why it matters**: CVD reveals the long-term accumulation/distribution trend. Rising CVD indicates persistent buying pressure (accumulation). Divergence between CVD and price is a powerful signal: if price makes new highs but CVD does not, distribution is occurring. In DeFi, CVD helps identify whether LPs or traders are dominating flow direction.

**Time complexity**: O(1) per swap -- CVD is simply the cumulative delta accumulator.

**On-chain feasibility**: FULLY FEASIBLE. Identical to volume delta but never reset -- just a running sum. One i128 accumulator. This is perhaps the most cost-effective yet informative volume metric for on-chain implementation.

---

### 2.11 On-Balance Volume (OBV)

**Definition**: A cumulative indicator that adds volume on up-closes and subtracts volume on down-closes.

**Formula**:
```
If C_t > C_(t-1):  OBV_t = OBV_(t-1) + V_t
If C_t < C_(t-1):  OBV_t = OBV_(t-1) - V_t
If C_t = C_(t-1):  OBV_t = OBV_(t-1)
```

**What it measures / Why it matters**: Developed by Joe Granville, OBV attempts to measure buying and selling pressure as a cumulative indicator. The theory is that volume precedes price movement -- smart money accumulates (OBV rises) before price breakout. In DeFi, OBV can signal whether volume is flowing into or out of a pool before price reacts.

**Time complexity**: O(1) per period update. Requires only the previous close price and current close price.

**On-chain feasibility**: FEASIBLE with period-based updates. Requires storing: previous close price, current OBV value. The "close" price in DeFi must be defined -- typically the last trade price before a period boundary (e.g., the last swap price before a new block/slot, or time-based checkpoints). Can be implemented with a crank that triggers period-end calculations.

---

### 2.12 Volume-Price Trend (VPT)

**Definition**: A cumulative indicator that relates volume to the percentage change in price.

**Formula**:
```
VPT_t = VPT_(t-1) + V_t * ((C_t - C_(t-1)) / C_(t-1))
```

**What it measures / Why it matters**: Similar to OBV but more nuanced -- it weights volume by the magnitude of the price change, not just the direction. A 5% price increase with 100 units of volume contributes more than a 1% increase with the same volume. Detects divergences between volume flow and price trend.

**Time complexity**: O(1) per period update.

**On-chain feasibility**: FEASIBLE. Requires previous close price, current close price, current volume, and the running VPT accumulator. Fixed-point percentage calculation is needed. Total storage: ~48 bytes.

---

### 2.13 Money Flow Index (MFI)

**Definition**: A volume-weighted RSI that measures buying and selling pressure using price and volume.

**Formula**:
```
Typical Price: TP_t = (H_t + L_t + C_t) / 3
Raw Money Flow: MF_t = TP_t * V_t
Positive MF = SUM(MF_t) for all periods where TP_t > TP_(t-1) over n periods
Negative MF = SUM(MF_t) for all periods where TP_t < TP_(t-1) over n periods
Money Ratio = Positive MF / Negative MF
MFI = 100 - (100 / (1 + Money Ratio))
```
Standard period: n = 14.

**What it measures / Why it matters**: MFI oscillates between 0 and 100. Values above 80 indicate overbought conditions (heavy buying volume at high prices); below 20 indicates oversold. Unlike RSI, MFI incorporates volume, making it more reliable for detecting genuine pressure vs price movement on thin volume.

**Time complexity**: O(n) for initial computation; O(1) for incremental updates with a sliding window tracking positive and negative money flow sums.

**On-chain feasibility**: DIFFICULT. Requires maintaining n periods of typical price history to compute the sliding window sums. For n=14 daily periods, that is 14 stored values plus rolling sums. Feasible but storage-expensive. An EMA-based approximation (like Wilder's smoothing used in RSI) reduces storage to constant space.

---

### 2.14 Chaikin Money Flow (CMF)

**Definition**: Measures the amount of money flow volume over a specific period.

**Formula**:
```
Money Flow Multiplier: MFM_t = ((C_t - L_t) - (H_t - C_t)) / (H_t - L_t)
                              = (2*C_t - L_t - H_t) / (H_t - L_t)
Money Flow Volume: MFV_t = MFM_t * V_t
CMF(n) = SUM(MFV_t, t=1..n) / SUM(V_t, t=1..n)
```
Standard period: n = 20 or 21.

**What it measures / Why it matters**: CMF oscillates between -1 and +1. Positive values indicate buying pressure (closes near the high); negative values indicate selling pressure (closes near the low). In DeFi, CMF can assess whether volume is occurring at favorable prices for buyers or sellers within a period.

**Time complexity**: O(n) for n periods in the window. Incremental updates with sliding window sums: O(1) per period.

**On-chain feasibility**: DIFFICULT. Requires H, L, C for each of the last n periods, plus sliding window sums. Requires defining "candle" equivalents for AMM data. Can approximate using EMA-smoothed versions. Better suited for off-chain computation.

---

### 2.15 Accumulation/Distribution Line (A/D Line)

**Definition**: A cumulative indicator that uses volume and price to assess whether an asset is being accumulated or distributed.

**Formula**:
```
Money Flow Multiplier: MFM_t = ((C_t - L_t) - (H_t - C_t)) / (H_t - L_t)
A/D_t = A/D_(t-1) + MFM_t * V_t
```

**What it measures / Why it matters**: Similar to OBV but uses the close's position within the high-low range rather than simple up/down close direction. Divergence between A/D and price suggests the trend may reverse. If A/D is rising while price is falling, accumulation is occurring (bullish). In DeFi, this can detect smart money accumulating tokens through a pool.

**Time complexity**: O(1) per period update given H, L, C, V.

**On-chain feasibility**: PARTIALLY FEASIBLE. Requires tracking period high, low, close prices and volume, which demands candle-like infrastructure. The cumulative A/D value itself is just one stored number. The bottleneck is computing H, L, C per period -- requires either per-trade max/min tracking with periodic resets, or off-chain candle construction.

---

### 2.16 Klinger Volume Oscillator (KVO)

**Definition**: A volume-based oscillator that uses volume force to identify long-term money flow trends.

**Formula**:
```
Trend_t = +1 if (H_t + L_t + C_t) > (H_(t-1) + L_(t-1) + C_(t-1)), else -1
dm_t = H_t - L_t
cm_t = cm_(t-1) + dm_t  (if Trend unchanged), or dm_(t-1) + dm_t (if Trend changed)
Volume Force: VF_t = V_t * |2*(dm_t/cm_t) - 1| * Trend_t * 100
KVO_t = EMA(VF, 34) - EMA(VF, 55)
Signal_t = EMA(KVO, 13)
```

**What it measures / Why it matters**: Captures the relationship between volume and price movement by accounting for high-low range and trend direction. Crossovers between KVO and signal line generate buy/sell signals. The oscillator excels at identifying divergences where volume flow disagrees with price direction.

**Time complexity**: O(1) per period update (three EMA updates).

**On-chain feasibility**: PARTIALLY FEASIBLE. Requires H, L, C candle data per period (same challenge as CMF and A/D). The oscillator itself is just three EMAs (6 stored values). If candle infrastructure exists, the KVO computation is cheap.

---

### 2.17 Ease of Movement (EMV)

**Definition**: Relates price change to volume, measuring how easily price moves on a given volume level.

**Formula**:
```
Distance Moved: DM_t = ((H_t + L_t)/2) - ((H_(t-1) + L_(t-1))/2)
Box Ratio: BR_t = (V_t / scale_factor) / (H_t - L_t)
EMV_t = DM_t / BR_t
EMV_SMA = SMA(EMV, 14)
```
Scale factor is used to normalize volume (e.g., divide by 1,000,000).

**What it measures / Why it matters**: High EMV values indicate price moving up easily on low volume (bullish). Low (negative) EMV values indicate price moving down easily. Near-zero values indicate price is struggling to move despite volume -- congestion. In DeFi, helps identify whether price movements are genuine (high EMV) or forced (low EMV with high volume).

**Time complexity**: O(1) per period; O(n) for the SMA smoothing.

**On-chain feasibility**: DIFFICULT. Same candle data dependency plus division operations and SMA storage. Off-chain computation recommended.

---

### 2.18 Force Index

**Definition**: Measures the force (power) behind a price movement using price change and volume.

**Formula**:
```
FI_t = (C_t - C_(t-1)) * V_t
FI_smoothed = EMA(FI, 13)  [short-term] or EMA(FI, 100) [long-term]
```

**What it measures / Why it matters**: Developed by Alexander Elder. Positive Force Index means bulls are in control; negative means bears dominate. The magnitude reflects conviction. Large volume with large price change = high force. In DeFi, Force Index can quantify the "power" behind a swap-induced price movement -- useful for distinguishing organic moves from wash trading (high volume, low force).

**Time complexity**: O(1) per period update.

**On-chain feasibility**: FEASIBLE. Requires only previous close price, current close price, current volume, and one EMA value. Total storage: ~48 bytes. One of the simpler derived indicators for on-chain implementation.

---

### 2.19 Negative Volume Index (NVI) and Positive Volume Index (PVI)

**Definition**: NVI tracks price changes on days when volume decreases; PVI tracks price changes on days when volume increases.

**Formula**:
```
NVI:
  If V_t < V_(t-1): NVI_t = NVI_(t-1) + ((C_t - C_(t-1)) / C_(t-1)) * NVI_(t-1)
  If V_t >= V_(t-1): NVI_t = NVI_(t-1)

PVI:
  If V_t > V_(t-1): PVI_t = PVI_(t-1) + ((C_t - C_(t-1)) / C_(t-1)) * PVI_(t-1)
  If V_t <= V_(t-1): PVI_t = PVI_(t-1)
```
Both start at a base value of 1000.

**What it measures / Why it matters**: The theory: smart money trades on low-volume days (captured by NVI), while the crowd trades on high-volume days (captured by PVI). In DeFi, this maps to: informed traders (arbitrageurs, MEV bots) may trade during low-activity periods, while retail traders cluster around high-activity events (token launches, news). NVI rising suggests informed accumulation.

**Time complexity**: O(1) per period update. Requires previous volume and previous close.

**On-chain feasibility**: FEASIBLE. Requires storing: previous volume, previous close, NVI value, PVI value. Total: ~64 bytes. Very practical for on-chain computation.

---

## 3. DeFi-Specific Volume Metrics

These metrics are unique to or significantly modified for decentralized finance environments.

### 3.1 Volume Per Liquidity (Volume/TVL Ratio)

**Definition**: The ratio of trading volume to total value locked in a pool, typically measured over 24 hours.

**Formula**:
```
V/TVL(T) = V(T) / TVL
```
where TVL is the total value locked in the pool at the time of measurement.

**What it measures / Why it matters**: Capital efficiency -- how much trading activity each dollar of liquidity supports. Higher V/TVL means liquidity is being utilized efficiently. Uniswap v3 concentrated liquidity achieves V/TVL ratios 10-100x higher than v2. This metric directly correlates with LP fee APR: `Fee_APR = (V * fee_rate * 365) / TVL`. Critical for LP decision-making and protocol comparison.

**Time complexity**: O(1) -- both V and TVL are readily available.

**On-chain feasibility**: FULLY FEASIBLE. TVL is inherently on-chain (token balances in the pool). Volume accumulators are cheap. The ratio is a single division.

---

### 3.2 Fee Volume (Volume Generating Fees)

**Definition**: The portion of total volume that generates trading fees for liquidity providers.

**Formula**:
```
V_fee(T) = V_total(T) * fee_rate
```
Or more precisely, for pools with multiple fee tiers:
```
V_fee(T) = SUM over pools p of (V_p(T) * fee_rate_p)
```

**What it measures / Why it matters**: Not all volume generates equal fees. In protocols with dynamic fees (e.g., Uniswap v4 hooks, Meteora dynamic fees), the effective fee rate varies per trade. Fee volume directly determines LP income and protocol revenue.

**Time complexity**: O(1) per swap if fee is applied at execution time.

**On-chain feasibility**: FULLY FEASIBLE. Fee collection is already an on-chain operation. Cumulative fees collected is a natural accumulator in all AMM implementations.

---

### 3.3 Volume Concentration by Tick Range

**Definition**: In concentrated liquidity AMMs, the distribution of trading volume across different tick (price) ranges.

**Formula**:
```
VC(tick_range, T) = V(tick_range, T) / V_total(T)
```
where `V(tick_range, T)` is the volume executed within a specific tick range.

**What it measures / Why it matters**: Reveals where active trading occurs relative to where liquidity is positioned. High volume concentration in a narrow tick range with wide liquidity deployment means most LP capital is idle. Helps LPs optimize position ranges. Indicates whether the pool's liquidity distribution matches actual trading patterns.

**Time complexity**: O(1) per swap (increment the volume counter for the current tick range). O(k) for reading across k tick ranges.

**On-chain feasibility**: PARTIALLY FEASIBLE. Each tick in a concentrated liquidity pool could maintain a volume counter, but the number of initialized ticks can be very large (thousands). A practical approach: track volume in "bins" (groups of ticks) rather than individual ticks. Orca Whirlpools and CLMM programs already track tick crossings; adding volume per tick range is a modest extension.

---

### 3.4 Flash Loan Volume

**Definition**: The total volume of assets borrowed and returned within a single transaction (flash loans).

**Formula**:
```
V_flash(T) = SUM of flashloan_amount_i for all flash loan transactions i in period T
```

**What it measures / Why it matters**: Flash loans enable capital-free arbitrage, liquidations, and collateral swaps. High flash loan volume relative to total volume may indicate: (a) significant arbitrage opportunities, (b) oracle manipulation attacks, (c) efficient market-making. Flash loan volume is "synthetic" in that it does not represent genuine capital commitment.

**Time complexity**: O(n) for n flash loan events.

**On-chain feasibility**: FULLY FEASIBLE. Flash loan events are inherently on-chain operations. Programs like Solend, MarginFi, and Aave emit events that can be tracked.

---

### 3.5 Arbitrage Volume

**Definition**: Volume attributed to arbitrage trades -- trades that exploit price discrepancies between the AMM and external venues or between multiple pools.

**Formula**:
```
V_arb(T) = SUM of q_i for trades i in T that are classified as arbitrage

Classification heuristic:
  Trade i is arbitrage if:
    |P_amm(i) - P_reference(i)| / P_reference(i) > threshold
    AND trade direction moves P_amm toward P_reference
```

**What it measures / Why it matters**: Arbitrage volume represents the "cost of price discovery" for AMM LPs. It is directly related to LVR (loss-versus-rebalancing). High arbitrage volume fraction means LPs are losing more to informed traders. Typical DEXes see 40-70% of volume attributed to arbitrage/MEV bots.

**Time complexity**: O(n) with access to a reference price feed. Classification requires per-trade analysis.

**On-chain feasibility**: DIFFICULT. Identifying whether a trade is arbitrage requires: (a) a reference price oracle, (b) analyzing the transaction context (multi-hop swaps, atomic bundles). On-chain heuristics are possible but imprecise. Best done off-chain with transaction-level analysis. On-chain approximation: track volume from known bot addresses (requires a registry).

---

### 3.6 MEV-Related Volume

**Definition**: Volume generated by Maximal Extractable Value activities including arbitrage, sandwich attacks, liquidations, and JIT (Just-In-Time) liquidity.

**Formula**:
```
V_mev(T) = V_arb(T) + V_sandwich(T) + V_liquidation(T) + V_jit(T)
```

**What it measures / Why it matters**: Quantifies the total volume that is "extractive" rather than organic. Research shows MEV-related volume can constitute 50-80% of total DEX volume on some chains. Understanding MEV volume is critical for: (a) assessing true organic demand, (b) evaluating LP profitability, (c) designing MEV-resistant protocols.

**Time complexity**: O(n) with transaction-level classification.

**On-chain feasibility**: VERY DIFFICULT. MEV classification requires analyzing transaction ordering, bundle composition, and multi-transaction patterns. This is inherently a post-hoc off-chain analysis. On-chain heuristics (e.g., detecting back-to-back opposing trades in the same block) can approximate sandwich detection but have high false positive rates.

---

### 3.7 Cross-Pool Volume Flow

**Definition**: Volume that flows through multiple pools in a single transaction route (multi-hop swaps).

**Formula**:
```
V_crosspool(A->B->C, T) = SUM of q_i for all multi-hop trades i routing through pools A->B->C in period T
```

**What it measures / Why it matters**: Reveals dependencies between pools. Pool A's volume may be partially driven by it being a routing hop for token pairs that lack direct pools. Understanding cross-pool flow is essential for: fee optimization (intermediate pools might need lower fees to attract routing), liquidity depth analysis, and identifying systemic risk (if a key routing pool loses liquidity).

**Time complexity**: O(n) with transaction-level path analysis.

**On-chain feasibility**: PARTIALLY FEASIBLE. On-chain routers (Jupiter, 1inch) know the full route. Individual pools see only their local swap. To track cross-pool flow, the router program could emit routing metadata, or pools could accept a "route_id" parameter to link related swaps. Without explicit instrumentation, must be reconstructed off-chain from transaction logs.

---

### 3.8 Volume by Trader Type (Retail vs Whale)

**Definition**: Volume decomposed by the size or identity classification of the trading entity.

**Formula**:
```
V_whale(T) = SUM of q_i for trades i in T where q_i > whale_threshold
V_retail(T) = V_total(T) - V_whale(T)

Alternative classification by address:
V_type(T) = SUM of q_i for trades from addresses in classification_type
```

Common whale thresholds: > $100k per trade or > $1M daily volume per address.

**What it measures / Why it matters**: Whale-dominated volume behaves differently from retail volume. Whales tend to be more informed, causing greater adverse selection for LPs. Retail volume is typically "uninformed" and profitable for LPs. This decomposition is critical for: fee tier design, LP profitability analysis, and market structure research.

**Time complexity**: O(n) with per-trade classification.

**On-chain feasibility**: PARTIALLY FEASIBLE. Trade size is known on-chain. A simple threshold-based whale classification is trivially computable per swap. However, address-based classification requires an off-chain registry. On-chain approach: maintain separate accumulators for "large" and "small" trades based on a configurable size threshold.

---

### 3.9 Sandwich Attack Volume

**Definition**: Volume generated specifically by sandwich attacks -- frontrun and backrun trades that bracket a victim trade.

**Formula**:
```
V_sandwich(T) = SUM of (q_frontrun_i + q_backrun_i) for all sandwich attacks i in period T
V_sandwich_victim(T) = SUM of q_victim_i for all sandwich attacks i in period T
Sandwich_ratio = V_sandwich(T) / V_total(T)
```

**What it measures / Why it matters**: Sandwich attacks are the most visible form of MEV extraction and directly harm users. Research indicates over 72,000 sandwich attacks on Ethereum in a 30-day period, extracting ~$1.4M in profit. Measuring sandwich volume helps: quantify user harm, evaluate MEV-protection mechanisms, compare DEX safety across protocols.

**Time complexity**: O(n) with block-level transaction ordering analysis.

**On-chain feasibility**: VERY DIFFICULT. Sandwich detection requires analyzing transaction ordering within a block/slot, identifying trades from the same address bracketing a victim trade, and verifying the price impact pattern. This is a block-builder-level or indexer-level analysis, not feasible within a swap instruction. Off-chain indexing with on-chain verified proofs (e.g., posting merkle roots of classified volumes) is the practical approach.

---

### 3.10 Volume Per LP Position

**Definition**: The trading volume that interacts with a specific LP position in a concentrated liquidity pool.

**Formula**:
```
V_lp_position(pos, T) = SUM of q_i for trades i in T where pos.tick_lower <= current_tick <= pos.tick_upper
```

**What it measures / Why it matters**: Directly determines an LP position's fee income. In concentrated liquidity, only positions whose range includes the current price earn fees. Volume per LP position allows: precise fee attribution, position performance comparison, and optimal range selection analysis.

**Time complexity**: O(1) per swap for updating active positions' volume counters. But the number of active positions can be large (100s-1000s per pool).

**On-chain feasibility**: PARTIALLY FEASIBLE. The AMM already iterates over active tick ranges during swaps. Adding a volume counter per tick range (not per individual position) is cheap. Per-position attribution requires knowing the fraction of liquidity each position contributes at the current tick, which is already computed for fee distribution. Extending this to track volume is a moderate addition to existing logic.

---

### 3.11 Net Volume Flow (In vs Out)

**Definition**: The net flow of value into or out of a specific pool or token, measured by the directional balance of trades.

**Formula**:
```
Net_flow(token_A, T) = V_buy_A(T) - V_sell_A(T)  [in token A terms]
Net_flow_usd(token_A, T) = V_buy_A_usd(T) - V_sell_A_usd(T)
```

Or for cross-pool analysis:
```
Net_flow(token_X) = SUM over all pools containing X of (inflow_X - outflow_X)
```

**What it measures / Why it matters**: Answers "is capital flowing into or out of this token/pool?" Persistent net outflow suggests distribution/selling pressure. Net inflow suggests accumulation. When aggregated across all pools containing a token, reveals the token-level demand picture.

**Time complexity**: O(1) per swap per pool. O(p) for p pools for aggregate token-level flow.

**On-chain feasibility**: FULLY FEASIBLE at the pool level (same as volume delta). Cross-pool aggregation requires either an aggregator contract or off-chain computation.

---

### 3.12 Volume Autocorrelation

**Definition**: The correlation of volume with its own lagged values, measuring whether volume clusters (high volume follows high volume).

**Formula**:
```
rho(k) = COV(V_t, V_(t-k)) / VAR(V_t)

Where:
COV(V_t, V_(t-k)) = (1/n) * SUM from t=k+1 to n of (V_t - V_bar)(V_(t-k) - V_bar)
V_bar = mean volume
```
Standard lags: k = 1, 2, 3, ..., 10.

**What it measures / Why it matters**: High autocorrelation at lag 1 means volume clusters (common in DeFi during events). The autocorrelation structure reveals volume persistence (trending behavior) vs mean-reversion. In DeFi, volume autocorrelation is typically higher than traditional markets due to bot activity patterns and event-driven clustering.

**Time complexity**: O(n) for n periods. Requires storing historical volume series.

**On-chain feasibility**: NOT FEASIBLE on-chain for real-time computation. Requires large historical datasets and statistical computations (means, variances, covariances). Best computed off-chain. On-chain verification possible via periodic posting of computed autocorrelation values with supporting data commitments.

---

### 3.13 Volume Volatility

**Definition**: The standard deviation (or variance) of volume over time, measuring how unpredictable volume levels are.

**Formula**:
```
sigma_V(n) = sqrt((1/(n-1)) * SUM from t=1 to n of (V_t - V_bar)^2)
```
Or using log returns of volume:
```
sigma_V_log(n) = STDEV(ln(V_t / V_(t-1))) over n periods
```

**What it measures / Why it matters**: High volume volatility indicates erratic trading patterns (common during market events, exploits, or protocol changes). Stable volume volatility suggests mature, predictable trading patterns. Useful for risk management and LP strategy -- high volume volatility means fee income is unpredictable.

**Time complexity**: O(n) for n periods. Can be approximated incrementally using Welford's algorithm: O(1) per update.

**On-chain feasibility**: PARTIALLY FEASIBLE using Welford's online algorithm. Store: count, mean, M2 (sum of squared deviations). Update per period with O(1) computation. Variance = M2/count. This gives a running estimate but not a windowed estimate. Windowed computation requires ring buffers.

---

### 3.14 Volume Entropy / Information Metrics

**Definition**: Shannon entropy applied to the volume distribution across time periods, price levels, or trade sizes, measuring the "randomness" or "information content" of volume patterns.

**Formula**:
```
H_V = -SUM over i of p_i * ln(p_i)

Where p_i = V_i / V_total (proportion of volume in bucket i)
```

For time-based entropy (volume across time buckets):
```
p_i = V(bucket_i) / V_total
H_time = -SUM over time_buckets of p_i * ln(p_i)
```

For trade-size entropy (volume distributed across size categories):
```
p_i = V(size_category_i) / V_total
H_size = -SUM over size_categories of p_i * ln(p_i)
```

Maximum entropy: H_max = ln(N) where N is the number of buckets.
Normalized entropy: H_norm = H_V / H_max (ranges from 0 to 1).

**What it measures / Why it matters**: High entropy means volume is evenly distributed (random, diverse participation). Low entropy means volume is concentrated (dominated by few time periods, price levels, or trade sizes). Low entropy suggests: bot domination (concentrated trade sizes), event-driven clustering (concentrated in time), or thin market (concentrated at few price levels). In DeFi, volume entropy is a powerful wash trading detector -- wash trades tend to have very uniform size distributions (low size entropy but specific to a few sizes, creating a multi-modal pattern distinguishable from organic trading).

**Time complexity**: O(k) for k buckets. Bucket volumes must be pre-computed.

**On-chain feasibility**: DIFFICULT. Requires maintaining volume per bucket (time, price, or size), then computing the entropy formula involving logarithms. Fixed-point logarithm computation is expensive on-chain (typically 200-500 compute units on Solana per log operation). Practical approach: maintain bucket volumes on-chain; compute entropy off-chain.

---

### 3.15 Toxic Flow Metrics / Adverse Selection Volume

**Definition**: Volume attributed to informed traders who systematically trade at favorable prices, causing losses for liquidity providers.

#### 3.15.1 VPIN (Volume-Synchronized Probability of Informed Trading)

**Formula**:
```
1. Aggregate trades into volume buckets of fixed size V_bucket.
2. For each bucket tau:
   V_buy(tau) = volume classified as buyer-initiated
   V_sell(tau) = volume classified as seller-initiated
3. VPIN = (1/n) * SUM from tau=1 to n of |V_buy(tau) - V_sell(tau)| / V_bucket
```

Trade classification uses the bulk volume classification (BVC) method:
```
V_buy(bar) = V(bar) * Z((C(bar) - O(bar)) / sigma_bar)
V_sell(bar) = V(bar) - V_buy(bar)
```
where Z is the standard normal CDF.

**What it measures**: VPIN estimates the probability that a trade is driven by informed (private information-bearing) traders. High VPIN means high probability of informed trading, which is toxic for market makers/LPs. Research shows DeFi VPIN is approximately 3.88x higher than CeFi, reflecting the higher adverse selection in AMM environments.

**Time complexity**: O(n) per volume bucket. Volume bucketing is O(1) per trade.

**On-chain feasibility**: DIFFICULT. Requires: (a) volume bucketing with fixed volume size (not time), (b) trade classification (BVC requires price bar data), (c) CDF computation. The volume bucketing itself is feasible on-chain (accumulate trades until bucket is full). The BVC classification and CDF computation are expensive. Practical approach: on-chain volume bucket tracking with off-chain VPIN computation.

#### 3.15.2 LVR (Loss-Versus-Rebalancing)

**Formula**:
```
Instantaneous LVR (per trade):
  LVR_i = a_i * (P_market - P_amm)
  where a_i is quantity traded, P_market is the true market price, P_amm is the AMM execution price.

For constant-product AMMs:
  Instantaneous LVR rate = sigma^2 / 8  (per unit of time, per unit of liquidity)

For AMMs with fees:
  Expected LVR per block = sigma_b^2 / (2 + sqrt(2*pi) * gamma / (|zeta(1/2)| * sigma_b))
  where sigma_b is intra-block volatility, gamma is the fee rate, zeta is the Riemann zeta function.

Cumulative LVR:
  LVR_cumulative(T) = SUM over trades i in T of a_i * (P_market_i - P_amm_i)
```

**What it measures**: LVR quantifies the cost of providing liquidity due to adverse selection (stale price exploitation). It separates the LP's total P&L into: LP P&L = Rebalancing P&L - LVR + Fee Income. LVR is the "price" AMMs pay for price discovery. This is arguably the most important metric for LP profitability analysis.

**Time complexity**: O(1) per trade given access to a market price oracle.

**On-chain feasibility**: PARTIALLY FEASIBLE. Per-trade LVR requires a reference price oracle (Pyth, Switchboard) to compare against the AMM execution price. The computation per swap is trivial (one subtraction, one multiplication). Maintaining a cumulative LVR accumulator adds ~16 bytes. The challenge is oracle latency -- the "true" market price may differ from the oracle price, introducing noise. The sigma^2/8 closed-form approximation can be computed with an on-chain volatility oracle.

#### 3.15.3 Markout / Adverse Selection Per Trade

**Formula**:
```
Markout(t, delta) = direction_t * (P_(t+delta) - P_t)
```
where `direction_t` is +1 for buys, -1 for sells, and delta is the markout horizon (e.g., 5 minutes, 1 block).

Aggregate markout:
```
Avg_Markout(delta) = (1/n) * SUM over trades i of Markout(i, delta)
```

**What it measures**: Markout measures how much the price moves against the market maker (LP) after a trade. Positive markout = the trader was informed (price moved in the trader's favor). Negative markout = the trader was uninformed (price reverted). Average markout is the per-trade adverse selection cost for LPs.

**Time complexity**: O(1) per trade, but requires the future price at t+delta, making it inherently a retrospective metric.

**On-chain feasibility**: NOT FEASIBLE in real-time (requires future prices). Can be computed on-chain retrospectively: when processing a new swap, compute the markout for the swap that occurred delta time ago. Requires storing recent trade prices in a ring buffer.

---

### 3.16 Informed vs Uninformed Flow

**Definition**: Classification of trading volume into informed flow (trades based on private information or superior price knowledge) and uninformed flow (retail/noise trading).

**Formula**:
```
Informed_ratio = V_informed / V_total

Classification criteria (heuristic):
  Informed if:
    - Trade is from a known arbitrage/MEV bot address
    - Trade immediately precedes a large price movement (markout > threshold)
    - Trade size is abnormally large relative to recent average
    - Trade is part of an atomic bundle (sandwich, backrun)

Uninformed_ratio = 1 - Informed_ratio
```

**What it measures / Why it matters**: The informed/uninformed split determines LP profitability. LPs profit from uninformed flow (fees exceed adverse selection) and lose from informed flow (adverse selection exceeds fees). A pool with high informed flow fraction needs higher fees to be profitable for LPs. This metric drives dynamic fee mechanisms (e.g., Uniswap v4 hooks that increase fees when informed flow is detected).

**Time complexity**: O(n) with per-trade classification.

**On-chain feasibility**: DIFFICULT for accurate classification. Simple heuristics are feasible on-chain: (a) flag trades above a size threshold, (b) flag trades from addresses in a known-bot registry. Accurate classification requires off-chain analysis. Dynamic fee hooks on Uniswap v4 use oracle-based heuristics (comparing AMM price to oracle price) as a real-time proxy for informed flow detection.

---

### 3.17 Volume per Liquidity Provider (LP Volume Share)

**Definition**: The fraction of total pool volume that interacted with a specific LP's liquidity position.

**Formula**:
```
V_share(LP, T) = (liquidity_LP / liquidity_active_total) * V(T)
```
In concentrated liquidity:
```
V_share(LP, T) = SUM over ticks t where LP is active of (liquidity_LP(t) / liquidity_total(t)) * V(t, T)
```

**What it measures / Why it matters**: Determines each LP's proportional share of fee income and adverse selection costs. Essential for: LP performance attribution, competitive analysis between LP positions, and automated LP strategy optimization.

**Time complexity**: O(1) for constant-product AMMs (proportional to liquidity share). O(k) for concentrated liquidity where k is the number of active tick ranges.

**On-chain feasibility**: FEASIBLE. This is already computed implicitly in fee distribution logic of concentrated liquidity AMMs. Making it explicitly queryable requires minimal additional accounting.

---

### 3.18 Loss-Versus-Holding (LVH / Impermanent Loss)

**Definition**: The difference in value between holding tokens in a pool versus simply holding them in a wallet.

**Formula**:
```
For constant-product AMM with initial price P_0 and current price P_t:
  price_ratio = P_t / P_0
  IL = 2 * sqrt(price_ratio) / (1 + price_ratio) - 1

In dollar terms:
  LVH = V_hold - V_pool
  where V_hold = value of initial token quantities at current prices
        V_pool = current value of the LP position
```

**What it measures / Why it matters**: The most widely known LP risk metric. IL increases with price divergence and is always non-positive (a loss). However, it is "impermanent" because it reverses if price returns to the initial ratio. In practice, IL + fees determines whether LPing is profitable.

**Time complexity**: O(1) per computation.

**On-chain feasibility**: FULLY FEASIBLE. Requires only the initial and current price ratios. Many DeFi dashboards already compute this. On-chain computation requires storing the initial price when a position is opened.

---

### 3.19 JIT (Just-In-Time) Liquidity Volume

**Definition**: Volume captured by liquidity that is added and removed within a single block, specifically to capture fees from anticipated large trades.

**Formula**:
```
V_jit(T) = SUM of q_i for trades i in T where the active liquidity includes JIT positions
JIT_share = V_jit(T) / V_total(T)
```

JIT detection: A position is JIT if it was minted and burned within the same block (or within 1-2 blocks).

**What it measures / Why it matters**: JIT liquidity competes with passive LPs by sniping fee revenue from large trades. High JIT share means passive LPs earn fewer fees per unit volume. JIT is a form of "informed LP" behavior, analogous to high-frequency market making. On Ethereum, JIT can represent 5-15% of fee capture in major pools.

**Time complexity**: O(n) with block-level position lifecycle tracking.

**On-chain feasibility**: PARTIALLY FEASIBLE. Position mint and burn events are on-chain. A program can flag positions that were created and destroyed within the same slot/block. However, attributing volume to JIT positions requires knowing which liquidity was active during each swap, which is already part of the AMM's fee distribution logic.

---

### 3.20 Wash Trading Volume

**Definition**: Volume where the same entity is effectively trading with itself to inflate volume metrics.

**Formula**:
```
V_wash(T) = SUM of q_i for trades i in T classified as wash trades

Classification heuristics:
  - Same address on both sides (via intermediary)
  - Round-trip: buy followed by equal sell within short time from same address
  - Circular routing: A->B->C->A within a single transaction
  - Statistical: abnormally tight bid-ask patterns, uniform trade sizes
```

Wash trade index:
```
WTI = V_wash / V_total
```

**What it measures / Why it matters**: Inflated volume misleads users, LPs, and protocols. Protocols using volume for incentive distribution (liquidity mining) are particularly vulnerable. Estimates suggest 30-90% of reported DEX volume on some chains is wash trading. Identifying and excluding wash volume is essential for honest protocol metrics.

**Time complexity**: O(n^2) for pairwise address analysis; O(n) for simpler heuristics.

**On-chain feasibility**: VERY DIFFICULT for accurate detection. Simple heuristics (same-block round-trip from same address) can be detected in real-time within the program. Sophisticated detection (Sybil analysis, circular routing) requires graph analysis off-chain. On-chain mitigation: time-weighted volume accumulators that naturally discount concentrated wash activity.

---

## 4. Statistical Volume Metrics

### 4.1 Volume Standard Deviation

**Definition**: The standard deviation of volume across periods, measuring volume variability.

**Formula**:
```
sigma_V = sqrt((1/(n-1)) * SUM from t=1 to n of (V_t - V_bar)^2)

Where V_bar = (1/n) * SUM from t=1 to n of V_t
```

**What it measures / Why it matters**: Quantifies how much volume fluctuates from its average. High sigma_V means unpredictable volume (risky for LPs relying on fee income). Low sigma_V means stable, predictable trading. Used as a denominator in z-scores and as an input to risk models.

**Time complexity**: O(n) for batch; O(1) per update using Welford's online algorithm.

**On-chain feasibility**: PARTIALLY FEASIBLE using Welford's algorithm (see Volume Volatility, section 3.13). Requires 3 stored values: count, running mean, and running M2.

---

### 4.2 Volume Z-Score

**Definition**: The number of standard deviations the current volume is from its historical mean.

**Formula**:
```
Z_V(t) = (V_t - V_bar) / sigma_V
```

**What it measures / Why it matters**: Normalizes volume into a standard scale. Z > 2 indicates unusually high volume (2+ standard deviations above mean); Z < -2 indicates unusually low volume. Critical for anomaly detection: potential exploits, whale activity, or market events. Used as a real-time alert trigger.

**Time complexity**: O(1) given pre-computed mean and standard deviation.

**On-chain feasibility**: FEASIBLE given Welford's accumulators for mean and variance. The z-score computation is a single subtraction and division. Total: O(1) per swap with ~48 bytes of stored state.

---

### 4.3 Volume Percentile Rank

**Definition**: The percentage of historical volume observations that fall below the current volume.

**Formula**:
```
Percentile(V_t) = (count of V_i <= V_t for all i in history) / (total count) * 100
```

For practical purposes, an approximate percentile can be computed using the t-digest or quantile sketch data structure.

**What it measures / Why it matters**: More intuitive than z-scores for non-normal distributions. "Current volume is at the 95th percentile" is immediately understandable. Volume distributions in DeFi are typically heavy-tailed (log-normal or power-law), making percentiles more informative than z-scores.

**Time complexity**: O(n) for exact computation; O(log n) per update for approximate (t-digest).

**On-chain feasibility**: DIFFICULT for exact percentiles. A t-digest or histogram-based approximation is feasible on-chain with fixed storage (e.g., 100 centroids = ~1600 bytes). However, maintaining a t-digest requires sorting and merging operations that consume non-trivial compute units on Solana. Better suited for off-chain computation.

---

### 4.4 Volume Distribution Moments (Skewness, Kurtosis)

**Definition**: Higher-order statistical moments of the volume distribution.

**Formula**:
```
Skewness = (1/n) * SUM((V_t - V_bar) / sigma_V)^3

Kurtosis = (1/n) * SUM((V_t - V_bar) / sigma_V)^4

Excess Kurtosis = Kurtosis - 3
```

**What it measures / Why it matters**:
- Skewness: Positive skewness means volume occasionally spikes much higher than average (right tail). DeFi volume is typically positively skewed due to event-driven surges. Negative skewness would be unusual.
- Kurtosis: Excess kurtosis > 0 (leptokurtic) means fat tails -- extreme volume events are more common than a normal distribution would predict. DeFi volume distributions are heavily leptokurtic.

These metrics characterize the shape of the volume distribution beyond mean and variance, critical for risk modeling and stress testing.

**Time complexity**: O(n) for batch. Can be maintained incrementally using online algorithms for higher moments (extension of Welford's).

**On-chain feasibility**: VERY DIFFICULT. Requires maintaining running sums of (V - mean)^3 and (V - mean)^4, which involves cubing and quartic operations in fixed-point arithmetic. Numerical stability is a concern. Off-chain computation recommended.

---

### 4.5 Volume-Price Correlation

**Definition**: The Pearson correlation coefficient between volume and price (or price returns) over a specified period.

**Formula**:
```
rho(V, P) = COV(V, P) / (sigma_V * sigma_P)

COV(V, P) = (1/n) * SUM((V_t - V_bar)(P_t - P_bar))
```

More commonly, correlation between volume and absolute price returns:
```
rho(V, |r|) where r_t = (P_t - P_(t-1)) / P_(t-1)
```

**What it measures / Why it matters**: Volume-price correlation reveals the relationship between activity and price movement. In DeFi AMMs:
- High positive correlation (V, |r|): Volume increases when price moves -- typical, healthy market behavior.
- Low correlation: Volume is independent of price movement -- may indicate bot-dominated wash trading.
- Correlation between V and signed returns r: Positive means volume increases on up-moves (bullish); negative means volume increases on down-moves (bearish).

**Time complexity**: O(n) for n periods. Can be maintained incrementally with running sums.

**On-chain feasibility**: DIFFICULT. Requires concurrent tracking of volume and price statistics, plus cross-moment computation. The running covariance extension of Welford's algorithm is possible (storing ~6 values) but involves complex fixed-point arithmetic. Practical for off-chain with periodic on-chain posting.

---

### 4.6 Volume Lead/Lag Relationships

**Definition**: The cross-correlation between volume and price (or other metrics) at various time lags, measuring whether volume changes predict future price changes or vice versa.

**Formula**:
```
rho(V_t, P_(t+k)) for lag k = -m, ..., -1, 0, 1, ..., m

Cross-correlation at lag k:
CCF(k) = COV(V_t, P_(t+k)) / (sigma_V * sigma_P)
```

**What it measures / Why it matters**: Tests the hypothesis "volume leads price." If CCF peaks at k=1 (volume today correlates with price tomorrow), volume is a leading indicator. In traditional markets, the volume-leads-price hypothesis is well-established. In DeFi, the relationship is more complex due to:
- Instant arbitrage (price adjusts immediately)
- Bot-driven volume that follows price rather than leads it
- Event-driven volume that coincides with price movements

**Time complexity**: O(n*m) for m lags over n periods.

**On-chain feasibility**: NOT FEASIBLE on-chain. Requires large historical datasets and cross-correlation computation. Purely an off-chain analytics metric.

---

## 5. Time-Series Volume Features

### 5.1 Volume Seasonality Patterns

**Definition**: Recurring patterns in volume at regular intervals -- hourly within a day (intraday seasonality), daily within a week, monthly within a year.

**Formula**:
```
Seasonal component S(t):
V_t = T_t + S_t + R_t  (additive decomposition)
V_t = T_t * S_t * R_t  (multiplicative decomposition)

Where T_t = trend, S_t = seasonal component, R_t = residual

Seasonal factors (for daily seasonality with hourly periods):
SF(h) = AVG(V_h) / AVG(V_all)  for hour h across many days
```

**What it measures / Why it matters**: DeFi volume exhibits strong seasonality patterns:
- Intraday: Volume peaks during US market hours (14:00-21:00 UTC) and Asian market hours (00:00-06:00 UTC)
- Day-of-week: Higher volume on weekdays, especially Tuesday-Thursday
- Monthly: Higher volume around token unlocks, governance votes, protocol launches

Understanding seasonality is critical for: volume prediction, anomaly detection (is this volume spike seasonal or anomalous?), and LP strategy (when to provide liquidity).

**Time complexity**: O(n) for decomposition over n periods.

**On-chain feasibility**: NOT FEASIBLE for real-time decomposition. Seasonal factors can be pre-computed off-chain and stored on-chain as lookup tables (e.g., 24 hourly factors = 192 bytes). These can be used for on-chain relative volume comparison.

---

### 5.2 Volume Trend Decomposition

**Definition**: Separating the volume time series into trend, seasonal, and residual components.

**Formula**:
```
Classical decomposition:
V_t = T_t + S_t + R_t

STL (Seasonal and Trend decomposition using Loess):
  Iterative LOESS smoothing to extract trend and seasonal components.

Simpler approach for on-chain:
  Trend = EMA(V, long_period)  e.g., EMA(V, 50)
  Detrended_V = V_t / EMA(V, 50)
```

**What it measures / Why it matters**: Isolates the underlying volume trend from noise and seasonality. A rising trend indicates growing protocol adoption. A declining trend despite occasional spikes suggests weakening engagement. The residual component captures anomalous events.

**Time complexity**: O(n) for STL; O(1) for EMA-based approximation.

**On-chain feasibility**: The EMA-based trend approximation is FEASIBLE on-chain (one stored EMA value). Full STL decomposition is not feasible on-chain.

---

### 5.3 Volume Regime Detection

**Definition**: Identifying distinct volume "regimes" -- periods where the statistical properties of volume (mean, variance, autocorrelation) are stable, separated by changepoints where properties shift.

**Formula**:
```
Hidden Markov Model approach:
  States: {Low_Volume, Normal_Volume, High_Volume}
  Transition matrix: P(S_t | S_(t-1))
  Emission: P(V_t | S_t) ~ N(mu_state, sigma_state)

Simpler threshold approach:
  Low regime:    V_t < V_bar - k * sigma_V
  Normal regime: V_bar - k * sigma_V <= V_t <= V_bar + k * sigma_V
  High regime:   V_t > V_bar + k * sigma_V
  where k is typically 1 or 1.5.
```

CUSUM (Cumulative Sum) changepoint detection:
```
S_t = max(0, S_(t-1) + V_t - mu_0 - k)
Alarm when S_t > h (threshold)
```

**What it measures / Why it matters**: Volume regimes correspond to different market states: accumulation, distribution, consolidation, breakout. Regime detection enables: adaptive fee models (increase fees in high-volume regimes to capture more LP revenue), risk management (reduce exposure in regime transitions), and market state classification.

**Time complexity**: O(n) for HMM; O(1) per update for CUSUM.

**On-chain feasibility**: CUSUM is FEASIBLE on-chain. Requires storing: cumulative sum S, reference level mu_0, and threshold h. O(1) per update with ~32 bytes of storage. HMM is not feasible on-chain. The threshold-based approach using z-scores (from Welford's accumulators) is also feasible.

---

### 5.4 Volume Breakout Signals

**Definition**: Signals generated when volume exceeds a predefined threshold, indicating potential significant price movements.

**Formula**:
```
Volume Breakout = V_t > k * SMA_V(t, n)  [typically k = 2.0, n = 20]

Or using z-scores:
Volume Breakout = Z_V(t) > z_threshold  [typically z_threshold = 2.0]

Confirmation signal:
Breakout_confirmed = Volume_Breakout AND |Price_Change_t| > price_threshold
```

**What it measures / Why it matters**: Volume breakouts often precede or accompany significant price movements. A price breakout on high volume is more likely to sustain. A price breakout on low volume is more likely to fail. In DeFi, volume breakouts can signal: new token listings gaining traction, arbitrage opportunities from oracle lag, impending liquidation cascades, or coordinated whale activity.

**Time complexity**: O(1) per period given pre-computed SMA or z-score.

**On-chain feasibility**: FEASIBLE. Using the Welford's z-score approach or an EMA-based relative volume comparison, volume breakout detection can be performed on-chain with O(1) computation per swap and ~48 bytes of storage. This is one of the most practical time-series features for on-chain implementation.

---

## 6. On-Chain vs Off-Chain Feasibility Summary

### Tier 1: Fully Feasible On-Chain (minimal compute and storage)

| Metric | Storage Needed | Compute per Swap |
|--------|---------------|------------------|
| Total Volume (token-denominated) | 16 bytes | O(1) addition |
| Buy Volume / Sell Volume | 32 bytes | O(1) conditional add |
| Volume per Pair | 16 bytes (per pool) | O(1) |
| Volume Delta | 16 bytes | O(1) |
| Cumulative Volume Delta (CVD) | 16 bytes | O(1) |
| Volume/TVL Ratio | 0 extra (uses existing) | O(1) division |
| Fee Volume | 16 bytes | O(1) |
| Net Volume Flow | 16 bytes | O(1) |
| Impermanent Loss (LVH) | 16 bytes | O(1) |

### Tier 2: Feasible On-Chain with Modest Overhead

| Metric | Storage Needed | Compute per Swap |
|--------|---------------|------------------|
| VWAP (accumulator approach) | 32 bytes | O(1) |
| Volume EMA | 16 bytes per EMA | O(1) fixed-point multiply |
| Volume Oscillator | 32 bytes | O(1) |
| Force Index | 48 bytes | O(1) |
| NVI / PVI | 64 bytes | O(1) |
| OBV | 32 bytes | O(1) |
| VPT | 48 bytes | O(1) |
| Volume Z-Score (Welford's) | 48 bytes | O(1) |
| Volume Breakout Signal | 48 bytes | O(1) |
| CUSUM Regime Detection | 32 bytes | O(1) |
| LVR (per-trade with oracle) | 16 bytes + oracle call | O(1) |
| Volume EMA Trend | 16 bytes | O(1) |

### Tier 3: Partially Feasible (require checkpoints or cranks)

| Metric | Notes |
|--------|-------|
| Volume per Time Window | Needs checkpoint snapshots |
| Volume SMA | Needs ring buffer of n period volumes |
| VROC / Volume Momentum | Needs historical checkpoints |
| Relative Volume (RVOL) | Feasible with EMA approximation |
| A/D Line | Needs candle (H,L,C) infrastructure |
| KVO | Needs candle infrastructure + 3 EMAs |
| Volume Concentration (tick) | Needs per-tick-range counters |
| Volume per LP Position | Extension of existing fee logic |
| JIT Liquidity Volume | Needs position lifecycle tracking |
| Volume Volatility | Feasible with Welford's but windowed is hard |
| Markout | Needs ring buffer of recent prices |
| Whale/Retail Volume | Feasible with size threshold |

### Tier 4: Off-Chain Only (on-chain verification possible)

| Metric | Reason |
|--------|--------|
| Volume Profile (full histogram) | Too much storage |
| Arbitrage Volume Classification | Requires cross-venue analysis |
| MEV Volume Classification | Requires block-level ordering analysis |
| Sandwich Attack Volume | Requires block-level pattern detection |
| Wash Trading Detection | Requires graph analysis |
| VPIN | Requires CDF computation + volume bucketing |
| Informed vs Uninformed Flow | Requires multi-factor classification |
| Volume Autocorrelation | Large historical dataset needed |
| Volume-Price Correlation | Cross-moment computation |
| Volume Lead/Lag | Cross-correlation at multiple lags |
| Volume Seasonality | Decomposition algorithm |
| Volume Distribution Moments | Higher-order moment arithmetic |
| Volume Percentile Rank | Requires quantile sketch or full history |
| Volume Entropy | Requires logarithm computation |
| CMF / MFI (full) | Needs sliding window of candle data |
| EMV (Ease of Movement) | Needs candle data + SMA |
| Cross-Pool Volume Flow | Needs router-level instrumentation |
| HMM Regime Detection | Machine learning inference |

---

## Appendix A: Recommended On-Chain Implementation Priority

For a Solana-based DEX SDK, the following metrics provide the highest value-to-cost ratio for on-chain implementation:

**Priority 1 (Must-have, near-zero cost)**:
1. Cumulative volume accumulators (total, buy, sell) -- foundation for everything
2. Volume delta and CVD -- single accumulator, extremely informative
3. VWAP accumulators (cumulative price*quantity and cumulative quantity)

**Priority 2 (High value, low cost)**:
4. Volume EMA (short and long period) -- enables oscillator, RVOL, breakout detection
5. Volume z-score via Welford's algorithm -- anomaly detection
6. LVR accumulator with oracle integration -- LP profitability tracking
7. Force Index (simple yet powerful)

**Priority 3 (Moderate value, moderate cost)**:
8. OBV -- requires period-based close price tracking
9. NVI/PVI -- cheap compute, interesting signal
10. CUSUM changepoint detection -- regime detection for dynamic fees
11. Large-trade volume accumulator (whale tracking via size threshold)

**Priority 4 (Optional, higher cost)**:
12. Per-tick-range volume counters -- already partially in concentrated liquidity logic
13. VPT -- requires close price tracking
14. Ring buffer of recent prices for retrospective markout computation

---

## Appendix B: Data Structures for Efficient On-Chain Storage

### Accumulator Pattern (Tier 1-2 metrics)
```
struct VolumeAccumulators {
    cumulative_volume_a: u128,         // Total token A volume
    cumulative_volume_b: u128,         // Total token B volume
    cumulative_buy_volume: u128,       // Buy-side volume
    cumulative_sell_volume: u128,      // Sell-side volume
    cumulative_pq: u128,              // Sum of price * quantity (for VWAP)
    cvd: i128,                        // Cumulative volume delta
    last_update_slot: u64,            // Solana slot of last update
    last_update_timestamp: i64,       // Unix timestamp of last update
}
// Total: 88 bytes
```

### EMA + Welford Pattern (Tier 2 metrics)
```
struct VolumeAnalytics {
    ema_short: u64,                   // Short-period EMA (e.g., 10)
    ema_long: u64,                    // Long-period EMA (e.g., 50)
    welford_count: u64,               // Number of observations
    welford_mean: i64,                // Running mean (fixed-point)
    welford_m2: u128,                 // Running sum of squared deviations
    obv: i128,                        // On-balance volume
    force_index_ema: i64,             // Smoothed force index
    last_close_price: u64,            // Previous period close price
    cusum: u64,                       // CUSUM for regime detection
    cusum_reference: u64,             // CUSUM reference level
}
// Total: 88 bytes
```

### Checkpoint Ring Buffer (Tier 3 metrics)
```
struct VolumeCheckpoints {
    slots: [VolumeSnapshot; 24],       // 24-slot ring buffer (e.g., hourly)
    head: u8,                          // Current write position
}

struct VolumeSnapshot {
    timestamp: i64,
    cumulative_volume: u128,
    close_price: u64,
    high_price: u64,
    low_price: u64,
}
// Per snapshot: 40 bytes
// Total for 24 slots: 961 bytes
```

Combined total for comprehensive on-chain volume analytics: approximately 1,137 bytes (~0.008 SOL rent at current rates). This is well within practical storage budgets for a Solana pool account.

---

## Appendix C: Mathematical Reference for Key Constants

- **EMA smoothing factor**: alpha = 2 / (period + 1)
- **Welford's variance**: variance = M2 / (count - 1)
- **LVR constant-product**: instantaneous_lvr = sigma^2 / 8
- **Maximum Shannon entropy**: H_max = ln(N) for N equiprobable buckets
- **CUSUM typical parameters**: k = 0.5 * sigma (allowance), h = 4 * sigma or 5 * sigma (threshold)
- **Z-score breakout threshold**: typically 2.0 (95th percentile assuming normality)
- **VPIN typical bucket size**: average daily volume / 50 (50 buckets per day)

---

## Appendix D: References and Further Reading

1. Milionis et al., "Automated Market Making and Loss-Versus-Rebalancing" (2022) -- arxiv.org/abs/2208.06046
2. Easley, Lopez de Prado, O'Hara, "Flow Toxicity and Liquidity in a High Frequency World" (2012) -- VPIN methodology
3. Chainlink Education, "TWAP vs. VWAP Price Algorithms" -- chain.link/education-hub/twap-vs-vwap
4. a16z Crypto, "LVR: Quantifying the Cost of Providing Liquidity" -- a16zcrypto.com
5. Uniswap v3 TWAP Oracle documentation -- blog.uniswap.org
6. Granville, "New Key to Stock Market Profits" (1963) -- OBV methodology
7. Chaikin, "Money Flow" -- CMF methodology
8. Welford, "Note on a method for calculating corrected sums of squares" (1962) -- online variance algorithm
9. Elder, "Trading for a Living" (1993) -- Force Index methodology
10. Shannon, "A Mathematical Theory of Communication" (1948) -- entropy foundations
