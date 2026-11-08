# Jarvis

A voice assistant powered by Claude. Say **"Jarvis, …"** and it acts: it controls your laptop, researches anything on the web, and studies the stock market with paper money.

## What it can do

- **Voice in, voice out, low resource use.** Speech recognition runs offline with Vosk's small model (about 50 MB, a few percent of one CPU core). Speech output uses your OS's built-in voice through pyttsx3. Only sentences that start with "Jarvis" are sent to Claude.
- **Control the laptop.** Runs shell commands (bash, or PowerShell on Windows), opens apps, URLs and files, and reads and writes files. It doesn't ask for confirmation. Every action is logged to `data/actions.log`.
- **Research.** Uses Claude's web search and web fetch for news, earnings and trends.
- **Stock analysis over 15 years:**
  - `analyze_stock`: CAGR, volatility, max drawdown, yearly returns, momentum.
  - `find_patterns`: tests 16 technical patterns (RSI, MACD, golden and death crosses, 52-week breakouts, gaps, volume spikes and more). For each one it measures how often the price was higher N days later. It checks the first 10 years against the last 5 so you can see whether an edge held up or was luck.
  - `backtest`: entry pattern plus stop loss, take profit and hold time, with trading costs included.
- **Practice until 70%.** `practice` paper-trades a strategy across many stocks over recent years and logs each session. `paper_trade` trades a $100k fake-money account at live prices. `readiness` reports whether Jarvis has reached at least a 70% win rate with positive profit, in both:
  1. historical practice (at least 100 trades), and
  2. real-time paper trading (at least 30 closed trades).
- **Memory.** Jarvis saves lessons and preferences to `data/notes.md` and reloads them each session.

## Setup

```bash
cd jarvis
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python download_model.py
export ANTHROPIC_API_KEY=sk-ant-...                  # Windows: setx ANTHROPIC_API_KEY sk-ant-...
python jarvis.py            # voice
python jarvis.py --text     # keyboard
```

Linux also needs `sudo apt install espeak-ng libportaudio2` for speech output and the microphone.

## Example commands

- "Jarvis, open Spotify."
- "Jarvis, what's using all my CPU?"
- "Jarvis, analyze Nvidia over the last 15 years."
- "Jarvis, find patterns in Apple and tell me which ones actually held up."
- "Jarvis, think hard and research whether Tesla is likely to drop this month." Phrases like "think hard" switch Claude to deeper reasoning.
- "Jarvis, practice trading pullbacks on the 20 biggest S&P stocks and tune it toward 70 percent."
- "Jarvis, how close are you to the 70 percent goal?"
- "Jarvis, new conversation." / "Jarvis, goodbye."

## Settings (environment variables)

| Variable | Default | Purpose |
|---|---|---|
| `JARVIS_MODEL` | `claude-opus-5-5` | Claude model. `claude-haiku-5-5` is much cheaper. |
| `JARVIS_EFFORT` | `low` | Reasoning depth: `low`, `medium`, `high`, `xhigh` or `max`. |
| `JARVIS_VOICE` | system default | Part of a voice name, e.g. `daniel` for a British voice on macOS. |
| `JARVIS_SPEECH_RATE` | `185` | Words per minute. |
| `JARVIS_MAX_STEPS` | `40` | Maximum tool calls per command. |

## Things you should know

- **It runs commands without asking, and speech recognition mishears things.** Only a short list of disk-wiping commands is blocked (`rm -rf /`, `mkfs`, `dd` to a disk, `format C:`). Anything else it hears, it does. Check `data/actions.log` if something odd happens.
- **Paper money only.** No broker is connected. If you later want real-time paper trading through a broker, Alpaca has a free paper-trading API. Connecting real money to an automated AI trader is a decision to make deliberately, not by voice.
- **70% win rate is a hard and partly misleading target.** A strategy can win 70% of trades and still lose money if the losses are bigger than the wins, so Jarvis also requires positive average profit. Tuning rules until a backtest says 70% usually overfits, which is why the goal requires forward paper trading too. Most professional strategies win 50 to 60% of trades. If Jarvis never reaches 70%, that's an honest result, not a bug.
- **Nothing here is financial advice.** Past patterns don't guarantee future prices.
- **Cost.** Each command is one or more Claude API calls. Short commands at `low` effort cost very little. Long research sessions with web search cost more.
