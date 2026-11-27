#!/bin/sh
# Evaluates Alcove's Apple Intelligence features against the on-device model.
# Needs a Mac with Apple Intelligence turned on (macOS 26+). Usage:
#   Evaluation/AIEval/run.sh            # everything, writes Evaluation/results.md
#   Evaluation/AIEval/run.sh receipts   # one part
set -e
cd "$(dirname "$0")"
APP=../../Alcove/Services
OUT=$(mktemp -d)
swiftc -O -o "$OUT/aieval" Stubs.swift Cases.swift main.swift \
  "$APP/KitchenAI.swift" "$APP/RecipeIdeas.swift" "$APP/ReceiptAI.swift" "$APP/ReceiptReader.swift"
if [ -z "$1" ]; then
  "$OUT/aieval" all ../../AlcoveTests/Fixtures/receipt.png | tee ../results.md
else
  "$OUT/aieval" "$@" ../../AlcoveTests/Fixtures/receipt.png
fi
