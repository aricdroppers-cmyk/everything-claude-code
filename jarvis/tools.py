"""Tools Jarvis can use: control the laptop, remember things, research and
paper-trade stocks. Every action is appended to data/actions.log."""

from __future__ import annotations

import json
import os
import platform
import re
import subprocess
import webbrowser
from datetime import datetime
from pathlib import Path

import trading

DATA_DIR = Path(__file__).parent / "data"
NOTES_FILE = DATA_DIR / "notes.md"
ACTION_LOG = DATA_DIR / "actions.log"

# Jarvis runs commands without asking. The only exception is this short list
# of commands that would wreck the machine. Speech recognition mishears
# things, so a one-word slip should never be able to wipe the disk.
BLOCKED = [
    r"\brm\s+-[a-z]*r[a-z]*f?\s+(/|~|\$HOME|/\*)(\s|$)",
    r"\bmkfs(\.|\s)",
    r"\bdd\s+.*of=/dev/",
    r":\(\)\s*\{\s*:\|:&\s*\};:",
    r"\bformat\s+[a-z]:",
    r"\b(rd|rmdir|del)\s+/s\s+/q\s+[a-z]:\\\s*$",
    r"Remove-Item\s+.*-Recurse.*\s[A-Za-z]:\\\s*$",
]


def _log(entry: dict) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    entry["time"] = datetime.now().isoformat(timespec="seconds")
    with ACTION_LOG.open("a") as f:
        f.write(json.dumps(entry) + "\n")


def run_shell(command: str, timeout: int = 120) -> str:
    for pat in BLOCKED:
        if re.search(pat, command, re.IGNORECASE):
            _log({"tool": "run_shell", "command": command, "blocked": True})
            return "BLOCKED: this command could destroy the system. Run it yourself if you really mean it."
    _log({"tool": "run_shell", "command": command})
    shell = ["powershell", "-NoProfile", "-Command", command] if platform.system() == "Windows" else None
    try:
        p = subprocess.run(shell or command, shell=shell is None, capture_output=True,
                           text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return f"Timed out after {timeout}s"
    out = (p.stdout + ("\n[stderr]\n" + p.stderr if p.stderr else "")).strip()
    return f"exit code {p.returncode}\n{out[-8000:]}"


def open_target(target: str) -> str:
    """Open a URL, file, folder or application with the OS default handler."""
    _log({"tool": "open_target", "target": target})
    if re.match(r"^https?://", target):
        webbrowser.open(target)
        return f"Opened {target}"
    system = platform.system()
    try:
        if system == "Windows":
            os.startfile(target)  # type: ignore[attr-defined]
        elif system == "Darwin":
            subprocess.Popen(["open", "-a", target] if not Path(target).exists() else ["open", target])
        else:
            subprocess.Popen(["xdg-open", target] if Path(target).exists() else [target],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        return f"Could not open {target}: {e}"
    return f"Opened {target}"


def read_file(path: str) -> str:
    p = Path(path).expanduser()
    text = p.read_text(errors="replace")
    return text if len(text) < 20000 else text[:20000] + "\n...[truncated]"


def write_file(path: str, content: str) -> str:
    p = Path(path).expanduser()
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content)
    _log({"tool": "write_file", "path": str(p), "bytes": len(content)})
    return f"Wrote {len(content)} characters to {p}"


def save_note(note: str) -> str:
    """Long-term memory: lessons learned, user preferences, trading insights."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with NOTES_FILE.open("a") as f:
        f.write(f"- [{datetime.now():%Y-%m-%d}] {note}\n")
    return "Saved."


def load_notes(max_chars: int = 6000) -> str:
    try:
        text = NOTES_FILE.read_text()
    except FileNotFoundError:
        return ""
    return text[-max_chars:]


# --------------------------------------------------------------------------
# Tool schemas for Claude
# --------------------------------------------------------------------------

def _tool(name, description, props, required):
    return {"name": name, "description": description,
            "input_schema": {"type": "object", "properties": props, "required": required}}


S = {"type": "string"}
N = {"type": "number"}
I = {"type": "integer"}
PATTERN = {"type": "string", "enum": list(trading.PATTERNS)}

TOOLS = [
    # Anthropic-hosted research tools (run on Anthropic's servers, no local cost)
    {"type": "web_search_20260209", "name": "web_search", "max_uses": 5},
    {"type": "web_fetch_20260209", "name": "web_fetch", "max_uses": 5},
    _tool("run_shell", "Run a shell command on the user's laptop (bash on Mac/Linux, PowerShell on Windows) and get its output. Use this for anything on the computer: files, apps, settings, installing software, scripts.",
          {"command": S, "timeout": I}, ["command"]),
    _tool("open_target", "Open a URL in the browser, or a file, folder or app by name/path.",
          {"target": S}, ["target"]),
    _tool("read_file", "Read a text file.", {"path": S}, ["path"]),
    _tool("write_file", "Create or overwrite a text file.", {"path": S, "content": S}, ["path", "content"]),
    _tool("save_note", "Save something to long-term memory (persists across sessions): user preferences, lessons from trading practice, strategies that worked or failed.",
          {"note": S}, ["note"]),
    _tool("analyze_stock", "Summary of a stock's price history (default 15 years): CAGR, volatility, drawdown, yearly returns, recent momentum.",
          {"ticker": S, "years": I}, ["ticker"]),
    _tool("find_patterns", "Test 16 technical patterns on a stock's 15-year history. For each: how often price was higher N days later, in-sample vs out-of-sample, and whether the edge held up. Also lists patterns active today.",
          {"ticker": S, "horizon_days": I}, ["ticker"]),
    _tool("backtest", "Backtest a long-only rule on one stock: enter when a pattern fires, exit on stop loss, take profit, or after hold_days. Includes trading costs.",
          {"ticker": S, "entry_pattern": PATTERN, "hold_days": I, "stop_loss_pct": N,
           "take_profit_pct": N, "last_years": N}, ["ticker", "entry_pattern"]),
    _tool("practice", "Practice paper-trading a strategy over the most recent years of several stocks (data the pattern search treats as out-of-sample). Logged so progress toward the 70% win-rate goal is tracked.",
          {"tickers": {"type": "array", "items": S}, "entry_pattern": PATTERN, "hold_days": I,
           "stop_loss_pct": N, "take_profit_pct": N, "last_years": N}, ["tickers", "entry_pattern"]),
    _tool("practice_history", "Best practice sessions so far, ranked by win rate.", {"limit": I}, []),
    _tool("get_quote", "Latest price of a stock.", {"ticker": S}, ["ticker"]),
    _tool("paper_trade", "Buy or sell shares in the PAPER (fake money, $100k start) account at the current market price. Always give a reason; it is recorded for later review.",
          {"action": {"type": "string", "enum": ["buy", "sell"]}, "ticker": S, "quantity": N, "reason": S},
          ["action", "ticker", "quantity"]),
    _tool("paper_status", "Paper account: cash, open positions, closed trades, win rate, P/L.", {}, []),
    _tool("readiness", "Check progress toward the goal: >=70% win rate with positive profit in both historical practice and real-time paper trading.", {}, []),
]

HANDLERS = {
    "run_shell": run_shell,
    "open_target": open_target,
    "read_file": read_file,
    "write_file": write_file,
    "save_note": save_note,
    "analyze_stock": trading.analyze,
    "find_patterns": trading.find_patterns,
    "backtest": trading.backtest,
    "practice": trading.practice,
    "practice_history": trading.practice_history,
    "get_quote": lambda ticker: {"ticker": ticker.upper(), "price": round(trading.latest_price(ticker), 2)},
    "paper_trade": trading.paper_trade,
    "paper_status": trading.paper_status,
    "readiness": trading.readiness,
}


def run_tool(name: str, args: dict) -> tuple[str, bool]:
    """Returns (result_text, is_error)."""
    fn = HANDLERS.get(name)
    if fn is None:
        return f"Unknown tool {name}", True
    try:
        result = fn(**args)
    except Exception as e:
        return f"{type(e).__name__}: {e}", True
    if not isinstance(result, str):
        result = json.dumps(result, default=str)
    return result, False
