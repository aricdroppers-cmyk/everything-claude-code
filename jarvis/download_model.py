"""Download the small offline Vosk English speech model (~40 MB)."""

import urllib.request
import zipfile
from pathlib import Path

URL = "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"
DEST = Path(__file__).parent / "models"

DEST.mkdir(exist_ok=True)
zip_path = DEST / "model.zip"
print(f"Downloading {URL} ...")
urllib.request.urlretrieve(URL, zip_path)
with zipfile.ZipFile(zip_path) as z:
    z.extractall(DEST)
zip_path.unlink()
print(f"Done. Model is in {DEST / 'vosk-model-small-en-us-0.15'}")
