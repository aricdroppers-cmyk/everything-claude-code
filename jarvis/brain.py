"""Jarvis's brain: a Claude tool-use loop."""

from __future__ import annotations

import os
import platform
from datetime import date

import anthropic

from tools import TOOLS, load_notes, run_tool

MODEL = os.environ.get("JARVIS_MODEL", "claude-opus-5-5")
# low = fast and cheap for everyday commands. Say "think hard" to Jarvis, or
# set JARVIS_EFFORT=high, for deeper stock research.
EFFORT = os.environ.get("JARVIS_EFFORT", "low")
MAX_STEPS = int(os.environ.get("JARVIS_MAX_STEPS", "40"))

SYSTEM = f"""You are Jarvis, a voice assistant running on the user's {platform.system()} laptop.
Today is {date.today():%A %B %d, %Y}.

How you talk:
- Your replies are read aloud. Keep them to one to three short sentences unless asked for detail.
- No markdown, bullet points, tables, URLs or emoji in replies. Say numbers the way a person would.
- Address the user as "sir" occasionally, dry wit welcome, never at the expense of clarity.

How you act:
- Carry out what the user asks directly. You have full control of the laptop through run_shell,
  open_target, read_file and write_file. Don't ask for permission; just do it and report briefly.
- Commands come from speech recognition and may be misheard. If a command is ambiguous AND
  acting on the wrong reading would delete or overwrite the user's data, say what you heard and
  ask once. Otherwise pick the most sensible reading and go.
- Use web_search and web_fetch freely to research anything.
- Save durable lessons and preferences with save_note.

Stock trading:
- You trade with PAPER money only. There is no real brokerage connection.
- Your goal is a strategy that wins at least 70% of trades with positive average profit, proven
  first in historical practice (at least 100 trades, recent years) and then in real-time paper
  trading (at least 30 closed trades). Check progress with the readiness tool.
- Method: use analyze_stock and find_patterns on 15 years of data, research news and trends on the
  web, backtest ideas, practice across many tickers, then refine stop loss, target and hold time.
  Prefer patterns whose edge held up out-of-sample. Be wary of overfitting: a rule tuned until it
  scores 70% on the same data usually fails on new data. Win rate alone can hide big losses, so
  always report expectancy too.
- Be honest about results. If something isn't working, say so plainly.

Long-term memory (notes you saved earlier):
{load_notes() or "(none yet)"}
"""


class Brain:
    def __init__(self) -> None:
        self.client = anthropic.Anthropic()
        self.messages: list = []

    def reset(self) -> None:
        self.messages = []

    def ask(self, text: str, on_tool=None) -> str:
        effort = EFFORT
        if any(p in text.lower() for p in ("think hard", "think carefully", "deep dive", "in depth")):
            effort = "high"
        self.messages.append({"role": "user", "content": text})

        for _ in range(MAX_STEPS):
            try:
                resp = self.client.beta.messages.create(
                    model=MODEL,
                    max_tokens=16000,
                    system=[{"type": "text", "text": SYSTEM, "cache_control": {"type": "ephemeral"}}],
                    tools=TOOLS,
                    messages=self.messages,
                    output_config={"effort": effort},
                    cache_control={"type": "ephemeral"},
                    # If a safety classifier declines, retry on another model instead of failing.
                    betas=["server-side-fallback-2026-07-01"],
                    fallbacks="default",
                )
            except anthropic.AuthenticationError:
                self.messages.pop()
                return "My Anthropic API key is missing or invalid. Set ANTHROPIC_API_KEY and restart me."
            except anthropic.RateLimitError:
                self.messages.pop()
                return "I'm being rate limited. Give me a moment and ask again."
            except anthropic.APIConnectionError:
                self.messages.pop()
                return "I can't reach the Claude servers. Check the internet connection."

            self.messages.append({"role": "assistant", "content": resp.content})

            if resp.stop_reason == "refusal":
                return "I can't help with that one."
            if resp.stop_reason == "pause_turn":
                continue

            tool_uses = [b for b in resp.content if b.type == "tool_use"]
            if not tool_uses:
                return " ".join(b.text for b in resp.content if b.type == "text").strip() or "Done."

            results = []
            for tu in tool_uses:
                if on_tool:
                    on_tool(tu.name, tu.input)
                out, is_err = run_tool(tu.name, tu.input)
                results.append({"type": "tool_result", "tool_use_id": tu.id,
                                "content": out, "is_error": is_err})
            self.messages.append({"role": "user", "content": results})

        return "That took more steps than I allow myself. Tell me to continue if you want me to keep going."
