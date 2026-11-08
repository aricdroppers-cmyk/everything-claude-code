"""Jarvis: say "Jarvis, <command>".

Low-resource voice loop:
  - Speech-to-text: Vosk small English model (offline, ~50 MB, runs on CPU).
  - Text-to-speech: pyttsx3 (uses the voice built into your OS, offline).
  - Only finished sentences that start with the wake word are sent to Claude,
    so nothing goes over the network while you're just talking in the room.

Run:  python jarvis.py           (voice)
      python jarvis.py --text    (type instead of talk)
"""

from __future__ import annotations

import json
import os
import queue
import re
import sys
import threading
from pathlib import Path

from brain import Brain

HERE = Path(__file__).parent
WAKE_WORDS = ("jarvis", "jervis", "jarvas", "travis")  # common mishearings
MODEL_DIR = Path(os.environ.get("JARVIS_VOSK_MODEL", HERE / "models" / "vosk-model-small-en-us-0.15"))
SAMPLE_RATE = 16000


class Voice:
    def __init__(self) -> None:
        import pyttsx3

        self.engine = pyttsx3.init()
        self.engine.setProperty("rate", int(os.environ.get("JARVIS_SPEECH_RATE", "185")))
        voice_hint = os.environ.get("JARVIS_VOICE", "").lower()
        if voice_hint:
            for v in self.engine.getProperty("voices"):
                if voice_hint in v.name.lower():
                    self.engine.setProperty("voice", v.id)
                    break
        self.speaking = threading.Event()

    def say(self, text: str) -> None:
        print(f"Jarvis: {text}")
        self.speaking.set()
        try:
            self.engine.say(text)
            self.engine.runAndWait()
        finally:
            self.speaking.clear()


def strip_wake(text: str) -> str | None:
    """Return the command after the wake word, '' if only the wake word, None if absent."""
    words = text.lower().split()
    for i, w in enumerate(words[:3]):  # wake word must be near the start
        if w in WAKE_WORDS:
            return " ".join(words[i + 1:]).strip()
    return None


def handle(brain: Brain, command: str, speak) -> bool:
    """Run one command. Returns False when Jarvis should exit."""
    c = command.lower().strip(" .!?")
    if c in ("goodbye", "shut down", "exit", "quit", "go to sleep"):
        speak("Goodbye, sir.")
        return False
    if c in ("reset", "new conversation", "start over", "forget this conversation"):
        brain.reset()
        speak("Fresh start.")
        return True
    reply = brain.ask(command, on_tool=lambda n, a: print(f"  [{n}] {json.dumps(a)[:160]}"))
    speak(reply)
    return True


def text_mode() -> None:
    brain = Brain()
    print("Jarvis (text mode). Type a command, or 'quit'.")
    while True:
        try:
            line = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if line and not handle(brain, line, lambda t: print(f"Jarvis: {t}")):
            break


def voice_mode() -> None:
    import sounddevice as sd
    from vosk import KaldiRecognizer, Model, SetLogLevel

    if not MODEL_DIR.exists():
        sys.exit(f"Speech model not found at {MODEL_DIR}. Run: python download_model.py")

    SetLogLevel(-1)
    rec = KaldiRecognizer(Model(str(MODEL_DIR)), SAMPLE_RATE)
    voice = Voice()
    brain = Brain()
    audio: queue.Queue[bytes] = queue.Queue()

    def callback(indata, frames, time_info, status):
        if not voice.speaking.is_set():  # don't listen to ourselves
            audio.put(bytes(indata))

    awaiting_command = False
    with sd.RawInputStream(samplerate=SAMPLE_RATE, blocksize=8000, dtype="int16",
                           channels=1, callback=callback):
        voice.say("Jarvis online.")
        while True:
            data = audio.get()
            if not rec.AcceptWaveform(data):
                continue
            heard = json.loads(rec.Result()).get("text", "").strip()
            if not heard:
                continue

            if awaiting_command:
                command, awaiting_command = heard, False
            else:
                command = strip_wake(heard)
                if command is None:
                    continue
                if command == "":
                    awaiting_command = True
                    voice.say("Yes, sir?")
                    continue

            print(f"You: {command}")
            if not handle(brain, command, voice.say):
                break
            # Drop anything captured while Jarvis was thinking/speaking.
            while not audio.empty():
                audio.get_nowait()
            rec.Reset()


if __name__ == "__main__":
    if not os.environ.get("ANTHROPIC_API_KEY") and not os.environ.get("ANTHROPIC_AUTH_TOKEN"):
        print("Note: ANTHROPIC_API_KEY is not set; Jarvis needs it to think.")
    text_mode() if "--text" in sys.argv else voice_mode()
