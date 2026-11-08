#!/bin/bash
# Runs the whole game (server + client) inside a fake Roblox and checks ~160 things.
# Needs the `luau` command line tool: https://github.com/luau-lang/luau/releases
# Usage:  ./tests/run.sh            (or LUAU=/path/to/luau ./tests/run.sh)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$(dirname "$HERE")"
LUAU="${LUAU:-luau}"
OUT="$(mktemp -d)/run.luau"
python3 - "$HERE" "$GAME" "$OUT" <<'PY'
import sys
here, game, out = sys.argv[1:4]
read = lambda p: open(p).read()
code = (read(here + "/fake_roblox.luau")
    + "\nlocal typeof = typeof or type\nlocal Config = (function()\n" + read(game + "/SalvageConfig.lua") + "\nend)()\n"
    + "local Models = (function()\n" + read(game + "/SalvageModels.lua") + "\nend)()\n"
    + "local require = function(m) if rawget(m, '__name') == 'SalvageModels' then return Models end return Config end\n"
    + "local function SERVER()\n" + read(game + "/SalvageServer.server.lua") + "\nend\n"
    + "local function CLIENT()\n" + read(game + "/SalvageClient.client.lua") + "\nend\n"
    + read(here + "/game_tests.luau"))
open(out, "w").write(code)
PY
"$LUAU" "$OUT" | tail -15
