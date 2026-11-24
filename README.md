KS-Wave [Kinetic Structural Wave]
📌 Overview

KS-Wave (Kinetic Structural Wave) is an adaptive trend-following and dynamic volatility trailing engine designed to solve the three most critical flaws of traditional trailing stop and trend-following indicators (such as classic SuperTrend, Chandelier Exit, and moving average bands):

Eliminating EMA lag during explosive breakouts.
Preventing false whipsaws in consolidation zones.
Protecting against single-candle wick stop-hunts.

Instead of applying a static multiplier to a symmetric ATR over a lagging moving average, KS-Wave combines synthetic Heikin-Body energy, fractal market efficiency (KER), asymmetric directional volatility, and structural swing pivots into a single, cohesive trailing wave.

- Core Mathematical Architecture
1. Heikin-Body Energy Center
Traditional indicators rely strictly on Close or the raw median (High+Low)/2, leaving them vulnerable to outlier wicks. KS-Wave synthesizes a smoothed Heikin-Ashi open-close anchor combined with the real candlestick body:
This creates a stable, noise-reduced centroid of price action without adding artificial delay.

2. Kinetic Efficiency Ratio (KER) & Adaptive Centerline (ACL)

Market conditions constantly rotate between clean directional momentum and chaotic chop. KS-Wave measures this using an internal efficiency ratio:
High KER (≈1.0) Indicates an efficient, one-way trending market. The adaptive smoothing factor accelerates to track price momentum instantaneously.
Low KER (≈0.0): Indicates noisy consolidation. The smoothing factor flattens out, preventing premature trend flips.

3. Asymmetric Directional Volatility (Semi-ATR)
Bull and bear runs exhibit distinct volatility signatures. In an uptrend, risk is defined by sudden selling pressure (Vdown): in a downtrend, risk comes from aggressive short squeezes (Vup)
Down(Vdown): max (high-low, |close[1] - low|)
Up(Vup): max(high-low, |high-close[1]|)

4. Dynamic Multiplier (𝑘dyn)

Instead of a fixed multiplier (e.g.,2.0 or 3.0), the band offset expands and contracts adaptively:
𝑘dyn=𝑘base⋅(1.6−0.8⋅𝐾𝐸𝑅)
When momentum is strong (𝐾𝐸𝑅→1) 𝑘dyn, tightens to lock in profits.
When the market is chopping (𝐾𝐸𝑅→0) 𝑘dyn,​ widens to give the trade breathing room and avoid wickouts.

5. Structural Pivot Floor & Ceiling Anchors

To guarantee protection against sudden fakeouts, the trailing line is bound by local Swing Pivots (Lowest Low and Highest High over N bars). The wave line will never flip prematurely unless the actual structural price floor or ceiling is broken.

Built-In Preset Profiles
KS-Wave features an instant Preset Profile selector designed to match specific trading horizons:
snapshot
Non-Repainting & Confirmed Bar-Close Signals

All labels, wave state transitions, and alert conditions are evaluated strictly on confirmed bar closes (barstate.isconfirmed).

No vanishing signals: Signals will never appear and subsequently disappear mid-candle.
Signal Confirmation: Once a bar closes and locks in a trend flip, the signal and stop-loss levels remain static permanently.

Alert Configuration

The script includes unified, MT5-compatible alert payloads formatted for webhook integrations, Telegram bots, or mobile push notifications:

{{ticker}} PERIOD_{{interval}} | BUY: entry {{close}} --stoploss [WaveLine]

(Example: XAUUSDm PERIOD_M1 | BUY: entry 3622.653 --stoploss 3615.830)

Real-Time Dashboard (Info Box)

The top-right info panel provides live diagnostic metrics:

Preset Profile: Displays current active operational profile.
Wave State: Bullish (Green) or Bearish (Red).
Kinetic Efficiency (KER): Live percentage showing directional efficiency (Strong trend vs.Sideway/Chop).
Dynamic Multiplier (kdyn): Real-time expansion coefficient of the trailing band.

Settings Guide
Profile (Preset Profile): Choose between pre-tuned presets (Scalp, Day Trade, Swing, Position) or manual Custom mode.
Length (c_len): Baseline lookback period for momentum and asymmetric ATR smoothing.
Base Multiplier (c_kBase): Core distance factor between price and the trailing wave.
Pivot Lookback (c_pivLen): Minimum bar span required to establish structural support/resistance floors.
Cloud Highlight: Toggles the translucent background trend cloud.
Show Bar-Close Labels: Displays clean Buy/Sell markers only after a candle has closed.
Show Dashboard: Toggles the HUD statistics box in the top-right corner.
