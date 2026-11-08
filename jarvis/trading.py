"""Stock research, pattern mining, backtesting and paper trading for Jarvis.

Everything here is local and lightweight (pandas + numpy + yfinance). Price
history is cached on disk so repeated analysis doesn't re-download.

IMPORTANT: this module only does *paper* trading. No real money moves.
"""

from __future__ import annotations

import json
import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd

DATA_DIR = Path(__file__).parent / "data"
CACHE_DIR = DATA_DIR / "prices"
ACCOUNT_FILE = DATA_DIR / "paper_account.json"
PRACTICE_FILE = DATA_DIR / "practice_log.json"

COST_PER_SIDE = 0.001  # 0.1% commission + slippage, per buy and per sell
TARGET_WIN_RATE = 0.70
MIN_PRACTICE_TRADES = 100
MIN_PAPER_TRADES = 30


# --------------------------------------------------------------------------
# Data
# --------------------------------------------------------------------------

def load_history(ticker: str, years: int = 15, max_age_hours: float = 12) -> pd.DataFrame:
    """Daily OHLCV for `ticker`, cached on disk, split/dividend adjusted."""
    ticker = ticker.upper().strip()
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / f"{ticker}_{years}y.csv"
    if path.exists() and (time.time() - path.stat().st_mtime) < max_age_hours * 3600:
        df = pd.read_csv(path, index_col=0, parse_dates=True)
    else:
        import yfinance as yf

        df = yf.Ticker(ticker).history(period=f"{years}y", interval="1d", auto_adjust=True)
        if df.empty:
            raise ValueError(f"No price data found for {ticker}")
        df = df[["Open", "High", "Low", "Close", "Volume"]]
        df.index = pd.to_datetime(df.index).tz_localize(None)
        df.to_csv(path)
    return df.dropna()


def latest_price(ticker: str) -> float:
    import yfinance as yf

    hist = yf.Ticker(ticker.upper()).history(period="5d", interval="1d")
    if hist.empty:
        raise ValueError(f"No quote for {ticker}")
    return float(hist["Close"].iloc[-1])


# --------------------------------------------------------------------------
# Indicators and patterns
# --------------------------------------------------------------------------

def add_indicators(df: pd.DataFrame) -> pd.DataFrame:
    d = df.copy()
    c = d["Close"]
    d["ret1"] = c.pct_change()
    for n in (20, 50, 200):
        d[f"sma{n}"] = c.rolling(n).mean()
    delta = c.diff()
    gain = delta.clip(lower=0).ewm(alpha=1 / 14, adjust=False).mean()
    loss = (-delta.clip(upper=0)).ewm(alpha=1 / 14, adjust=False).mean()
    d["rsi14"] = 100 - 100 / (1 + gain / loss.replace(0, np.nan))
    ema12 = c.ewm(span=12, adjust=False).mean()
    ema26 = c.ewm(span=26, adjust=False).mean()
    macd = ema12 - ema26
    d["macd_hist"] = macd - macd.ewm(span=9, adjust=False).mean()
    d["vol20"] = d["ret1"].rolling(20).std() * np.sqrt(252)
    d["volume_ratio"] = d["Volume"] / d["Volume"].rolling(20).mean()
    d["high252"] = c.rolling(252).max()
    d["low252"] = c.rolling(252).min()
    return d


def _cross_up(a: pd.Series, b: pd.Series) -> pd.Series:
    return (a > b) & (a.shift(1) <= b.shift(1))


PATTERNS = {
    "golden_cross": lambda d: _cross_up(d["sma50"], d["sma200"]),
    "death_cross": lambda d: _cross_up(d["sma200"], d["sma50"]),
    "rsi_oversold": lambda d: d["rsi14"] < 30,
    "rsi_overbought": lambda d: d["rsi14"] > 70,
    "macd_bull_cross": lambda d: _cross_up(d["macd_hist"], pd.Series(0.0, index=d.index)),
    "macd_bear_cross": lambda d: _cross_up(pd.Series(0.0, index=d.index), d["macd_hist"]),
    "breakout_52w_high": lambda d: d["Close"] >= d["high252"],
    "near_52w_low": lambda d: d["Close"] <= d["low252"] * 1.03,
    "pullback_in_uptrend": lambda d: (d["Close"] > d["sma200"]) & (d["rsi14"] < 40),
    "downtrend_bounce": lambda d: (d["Close"] < d["sma200"]) & (d["rsi14"] < 30),
    "big_gap_down": lambda d: d["ret1"] < -0.04,
    "big_gap_up": lambda d: d["ret1"] > 0.04,
    "volume_spike_up": lambda d: (d["volume_ratio"] > 2) & (d["ret1"] > 0),
    "volume_spike_down": lambda d: (d["volume_ratio"] > 2) & (d["ret1"] < 0),
    "above_sma200": lambda d: d["Close"] > d["sma200"],
    "below_sma200": lambda d: d["Close"] < d["sma200"],
}


def _stats(fwd: pd.Series) -> dict:
    fwd = fwd.dropna()
    if len(fwd) == 0:
        return {"n": 0}
    return {
        "n": int(len(fwd)),
        "up_rate": round(float((fwd > 0).mean()), 3),
        "avg_return_pct": round(float(fwd.mean() * 100), 2),
    }


def find_patterns(ticker: str, horizon_days: int = 20, years: int = 15) -> dict:
    """Test every known pattern on `ticker`: how often was price higher
    `horizon_days` later? Compares the first 2/3 of history (in-sample) with
    the last 1/3 (out-of-sample) so you can see whether an edge actually held
    up or was just luck.
    """
    d = add_indicators(load_history(ticker, years))
    d["fwd"] = d["Close"].shift(-horizon_days) / d["Close"] - 1
    d = d.dropna(subset=["sma200"])
    split = d.index[int(len(d) * 2 / 3)]
    ins, oos = d[d.index < split], d[d.index >= split]

    base_in, base_oos = _stats(ins["fwd"]), _stats(oos["fwd"])
    rows = []
    for name, fn in PATTERNS.items():
        sig = fn(d).fillna(False)
        s_in = _stats(ins.loc[sig[ins.index], "fwd"])
        s_oos = _stats(oos.loc[sig[oos.index], "fwd"])
        if s_in.get("n", 0) < 5 or s_oos.get("n", 0) < 5:
            verdict = "too few signals"
        else:
            edge_in = s_in["avg_return_pct"] - base_in["avg_return_pct"]
            edge_oos = s_oos["avg_return_pct"] - base_oos["avg_return_pct"]
            if edge_in > 0 and edge_oos > 0:
                verdict = "better than an average day in BOTH periods (edge held up)"
            elif edge_in < 0 and edge_oos < 0:
                verdict = "worse than an average day in BOTH periods (weak signal)"
            else:
                verdict = "inconsistent between periods (likely noise)"
        rows.append({"pattern": name, "in_sample": s_in, "out_of_sample": s_oos, "verdict": verdict})

    today = d.iloc[-1]
    active = [name for name, fn in PATTERNS.items() if bool(fn(d).fillna(False).iloc[-1])]
    return {
        "ticker": ticker.upper(),
        "period": f"{d.index[0].date()} to {d.index[-1].date()}",
        "horizon_days": horizon_days,
        "split_date": str(split.date()),
        "baseline_in_sample": base_in,
        "baseline_out_of_sample": base_oos,
        "patterns": rows,
        "active_today": active,
        "today": {
            "close": round(float(today["Close"]), 2),
            "rsi14": round(float(today["rsi14"]), 1),
            "vs_sma200_pct": round(float((today["Close"] / today["sma200"] - 1) * 100), 1),
            "volatility_annual_pct": round(float(today["vol20"] * 100), 1),
        },
    }


def analyze(ticker: str, years: int = 15) -> dict:
    """Big-picture summary of a stock's last `years` years."""
    df = load_history(ticker, years)
    c = df["Close"]
    r = c.pct_change().dropna()
    yearly = c.resample("YE").last().pct_change().dropna()
    dd = c / c.cummax() - 1
    n_years = (c.index[-1] - c.index[0]).days / 365.25
    return {
        "ticker": ticker.upper(),
        "period": f"{c.index[0].date()} to {c.index[-1].date()}",
        "last_close": round(float(c.iloc[-1]), 2),
        "total_return_pct": round(float((c.iloc[-1] / c.iloc[0] - 1) * 100), 1),
        "cagr_pct": round(float(((c.iloc[-1] / c.iloc[0]) ** (1 / n_years) - 1) * 100), 2),
        "annual_volatility_pct": round(float(r.std() * np.sqrt(252) * 100), 1),
        "max_drawdown_pct": round(float(dd.min() * 100), 1),
        "pct_up_days": round(float((r > 0).mean() * 100), 1),
        "yearly_returns_pct": {str(k.year): round(float(v * 100), 1) for k, v in yearly.items()},
        "return_1m_pct": round(float((c.iloc[-1] / c.iloc[-22] - 1) * 100), 1),
        "return_6m_pct": round(float((c.iloc[-1] / c.iloc[-126] - 1) * 100), 1),
        "return_1y_pct": round(float((c.iloc[-1] / c.iloc[-252] - 1) * 100), 1),
    }


# --------------------------------------------------------------------------
# Backtesting / practice
# --------------------------------------------------------------------------

def _simulate(ticker, pattern, hold_days, stop_loss_pct, take_profit_pct, last_years, years=15):
    """Run the trade rules over history and return (frame, every trade)."""
    if pattern not in PATTERNS:
        raise ValueError(f"Unknown pattern. Choose from: {', '.join(PATTERNS)}")
    d = add_indicators(load_history(ticker, years)).dropna(subset=["sma200"])
    if last_years:
        d = d[d.index >= d.index[-1] - pd.Timedelta(days=int(last_years * 365))]
    sig = PATTERNS[pattern](d).fillna(False).to_numpy()
    close = d["Close"].to_numpy()
    trades, i = [], 0
    while i < len(d) - 1:
        if not sig[i]:
            i += 1
            continue
        last = min(i + hold_days, len(d) - 1)
        exit_idx, reason = last, "time"
        for j in range(i + 1, last + 1):
            chg = close[j] / close[i] - 1
            if chg <= -stop_loss_pct / 100:
                exit_idx, reason = j, "stop"
                break
            if chg >= take_profit_pct / 100:
                exit_idx, reason = j, "target"
                break
        r = close[exit_idx] * (1 - COST_PER_SIDE) / (close[i] * (1 + COST_PER_SIDE)) - 1
        trades.append({
            "entry_date": str(d.index[i].date()),
            "exit_date": str(d.index[exit_idx].date()),
            "return_pct": round(r * 100, 2),
            "exit_reason": reason,
        })
        i = exit_idx + 1
    return d, trades


def backtest(
    ticker: str,
    entry_pattern: str,
    hold_days: int = 20,
    stop_loss_pct: float = 8.0,
    take_profit_pct: float = 10.0,
    last_years: float | None = None,
    years: int = 15,
) -> dict:
    """Simulate long trades: buy at close when `entry_pattern` fires, sell when
    the stop, the target, or `hold_days` is hit. One position at a time.
    Costs of 0.1% per side are included. `last_years` limits the test to the
    most recent N years (use it for out-of-sample practice)."""
    d, trades = _simulate(ticker, entry_pattern, hold_days, stop_loss_pct, take_profit_pct, last_years, years)
    close = d["Close"].to_numpy()
    rets = np.array([t["return_pct"] for t in trades]) / 100
    equity = np.cumprod(1 + rets) if len(rets) else np.array([1.0])
    peak = np.maximum.accumulate(equity)
    wins, losses = rets[rets > 0], rets[rets <= 0]
    return {
        "ticker": ticker.upper(),
        "pattern": entry_pattern,
        "period": f"{d.index[0].date()} to {d.index[-1].date()}",
        "rules": {"hold_days": hold_days, "stop_loss_pct": stop_loss_pct, "take_profit_pct": take_profit_pct},
        "trades": len(trades),
        "win_rate": round(float((rets > 0).mean()), 3) if len(rets) else None,
        "avg_win_pct": round(float(wins.mean() * 100), 2) if len(wins) else 0,
        "avg_loss_pct": round(float(losses.mean() * 100), 2) if len(losses) else 0,
        "expectancy_pct_per_trade": round(float(rets.mean() * 100), 2) if len(rets) else 0,
        "strategy_total_return_pct": round(float((equity[-1] - 1) * 100), 1),
        "buy_and_hold_return_pct": round(float((close[-1] / close[0] - 1) * 100), 1),
        "max_drawdown_pct": round(float((equity / peak - 1).min() * 100), 1),
        "last_trades": trades[-5:],
    }


def practice(
    tickers: list[str],
    entry_pattern: str,
    hold_days: int = 20,
    stop_loss_pct: float = 8.0,
    take_profit_pct: float = 10.0,
    last_years: float = 5,
) -> dict:
    """Paper-trade a strategy across several stocks over the most recent
    `last_years` of history and log the result. This is Jarvis's practice
    ground: tweak rules, practice again, compare."""
    per, all_rets = [], []
    for t in tickers:
        try:
            _, trades = _simulate(t, entry_pattern, hold_days, stop_loss_pct, take_profit_pct, last_years)
        except Exception as e:  # keep going on bad tickers
            per.append({"ticker": t.upper(), "error": str(e)})
            continue
        rets = [x["return_pct"] for x in trades]
        all_rets += rets
        per.append({
            "ticker": t.upper(),
            "trades": len(rets),
            "win_rate": round(sum(r > 0 for r in rets) / len(rets), 3) if rets else None,
        })
    arr = np.array(all_rets)
    session = {
        "time": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "strategy": {"pattern": entry_pattern, "hold_days": hold_days,
                     "stop_loss_pct": stop_loss_pct, "take_profit_pct": take_profit_pct,
                     "last_years": last_years},
        "tickers": [t.upper() for t in tickers],
        "trades": int(len(arr)),
        "win_rate": round(float((arr > 0).mean()), 3) if len(arr) else None,
        "expectancy_pct_per_trade": round(float(arr.mean()), 2) if len(arr) else None,
        "per_ticker": per,
    }
    log = _read_json(PRACTICE_FILE, [])
    log.append(session)
    _write_json(PRACTICE_FILE, log)
    session["meets_70pct_goal"] = bool(
        session["trades"] >= MIN_PRACTICE_TRADES
        and (session["win_rate"] or 0) >= TARGET_WIN_RATE
        and (session["expectancy_pct_per_trade"] or 0) > 0
    )
    return session


def practice_history(limit: int = 10) -> list:
    """Best recent practice sessions, sorted by win rate."""
    log = [s for s in _read_json(PRACTICE_FILE, []) if s.get("trades", 0) >= 10]
    log.sort(key=lambda s: (s.get("win_rate") or 0, s.get("expectancy_pct_per_trade") or 0), reverse=True)
    return log[:limit]


# --------------------------------------------------------------------------
# Paper account (real-time prices, fake money)
# --------------------------------------------------------------------------

def _read_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def _write_json(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2))


def _account() -> dict:
    return _read_json(ACCOUNT_FILE, {"cash": 100_000.0, "positions": {}, "closed": []})


def paper_trade(action: str, ticker: str, quantity: float, reason: str = "") -> dict:
    """Buy or sell in the paper account at the latest market price."""
    action, ticker = action.lower(), ticker.upper()
    acct = _account()
    price = latest_price(ticker)
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    pos = acct["positions"].get(ticker)

    if action == "buy":
        cost = price * quantity * (1 + COST_PER_SIDE)
        if cost > acct["cash"]:
            return {"error": f"Not enough paper cash: need {cost:.2f}, have {acct['cash']:.2f}"}
        acct["cash"] -= cost
        if pos:
            total = pos["qty"] + quantity
            pos["avg_price"] = (pos["avg_price"] * pos["qty"] + price * quantity) / total
            pos["qty"] = total
        else:
            acct["positions"][ticker] = {"qty": quantity, "avg_price": price, "opened": now, "reason": reason}
    elif action == "sell":
        if not pos or pos["qty"] < quantity:
            return {"error": f"Not holding {quantity} shares of {ticker}"}
        proceeds = price * quantity * (1 - COST_PER_SIDE)
        acct["cash"] += proceeds
        entry_cost = pos["avg_price"] * quantity * (1 + COST_PER_SIDE)
        pnl = proceeds - entry_cost
        acct["closed"].append({
            "ticker": ticker, "qty": quantity, "entry": round(pos["avg_price"], 4),
            "exit": round(price, 4), "pnl": round(pnl, 2),
            "return_pct": round(pnl / entry_cost * 100, 2),
            "opened": pos["opened"], "closed": now,
            "entry_reason": pos.get("reason", ""), "exit_reason": reason,
        })
        pos["qty"] -= quantity
        if pos["qty"] <= 1e-9:
            del acct["positions"][ticker]
    else:
        return {"error": "action must be 'buy' or 'sell'"}

    _write_json(ACCOUNT_FILE, acct)
    return {"ok": True, "action": action, "ticker": ticker, "qty": quantity,
            "price": round(price, 2), "cash_left": round(acct["cash"], 2)}


def paper_status() -> dict:
    acct = _account()
    positions, value = [], acct["cash"]
    for t, p in acct["positions"].items():
        try:
            px = latest_price(t)
        except Exception:
            px = p["avg_price"]
        mv = px * p["qty"]
        value += mv
        positions.append({"ticker": t, "qty": p["qty"], "avg_price": round(p["avg_price"], 2),
                          "price": round(px, 2), "unrealized_pnl": round(mv - p["avg_price"] * p["qty"], 2)})
    closed = acct["closed"]
    wins = [c for c in closed if c["pnl"] > 0]
    return {
        "cash": round(acct["cash"], 2),
        "account_value": round(value, 2),
        "total_return_pct": round((value / 100_000 - 1) * 100, 2),
        "open_positions": positions,
        "closed_trades": len(closed),
        "win_rate": round(len(wins) / len(closed), 3) if closed else None,
        "realized_pnl": round(sum(c["pnl"] for c in closed), 2),
        "recent_closed": closed[-5:],
    }


def readiness() -> dict:
    """Has Jarvis earned the 70% goal? Requires BOTH enough historical practice
    trades AND enough forward (real-time) paper trades, each at >=70% wins
    with positive average profit. Backtests alone are too easy to overfit."""
    best = practice_history(1)
    best = best[0] if best else None
    status = paper_status()
    practice_ok = bool(best and best["trades"] >= MIN_PRACTICE_TRADES
                       and best["win_rate"] >= TARGET_WIN_RATE
                       and best["expectancy_pct_per_trade"] > 0)
    paper_ok = bool(status["closed_trades"] >= MIN_PAPER_TRADES
                    and (status["win_rate"] or 0) >= TARGET_WIN_RATE
                    and status["realized_pnl"] > 0)
    return {
        "goal": f">= {TARGET_WIN_RATE:.0%} win rate with positive profit",
        "best_practice_session": best and {k: best[k] for k in ("strategy", "trades", "win_rate", "expectancy_pct_per_trade")},
        "practice_goal_met": practice_ok,
        "paper_trades_closed": status["closed_trades"],
        "paper_win_rate": status["win_rate"],
        "paper_realized_pnl": status["realized_pnl"],
        "paper_goal_met": paper_ok,
        "ready": practice_ok and paper_ok,
        "note": "Real-money trading is not wired up. Even when 'ready' is true, past results do not guarantee future results.",
    }
