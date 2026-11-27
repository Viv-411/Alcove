# AI evaluation

`AIEval/run.sh` checks Alcove's Apple Intelligence features against Apple's on-device model and writes [`results.md`](results.md). It compiles the app's real AI files (`KitchenAI.swift`, `RecipeIdeas.swift`, `ReceiptAI.swift`, `ReceiptReader.swift`), so it tests the same prompts, settings and checks the app ships. Only the SwiftData model types are stubbed.

Run it on a Mac with Apple Intelligence turned on (macOS 26 or later). The iOS Simulator can't run the model.

```sh
Evaluation/AIEval/run.sh
```

## What it checks

| Part | Reference | Pass rule |
|---|---|---|
| Receipt names | 30 receipt lines, hand-labelled with the words a correct name must contain (`Cases.swift`) | The name a person would see contains every labelled word. A wrong name shown counts as a failure; an abbreviation left as is does not count as correct either. |
| Receipt names, repeated | Same 30 lines, run again | Same result both times (the request uses temperature 0) |
| Whole receipt | `AlcoveTests/Fixtures/receipt.png`: photo → Vision text → `ReceiptParser` → `ReceiptAI` | Items found, totals and payments skipped, no wrong renames |
| Meal ideas | Six pantries: the app's sample family, a different household, a vegetarian request with chicken at home, an "under 20 minutes" request, an 81-item pantry, a 3-item pantry | Expiring food used; expired food never shown as "from home"; no snacks as ingredients; no meat when vegetarian; nothing over 20 minutes when quick |
| First design vs. shipped | 20 runs each on the sample pantry | Same checks, plus how often the model's "from home" list named food that isn't at home |

Meal ideas vary from run to run, so each scenario is run several times and the counts are totals. Whether a dish is a sensible thing to cook isn't scored automatically; every dish, with the ingredients the model listed, is in `results.md` for a person to read.

## Changes the evaluation led to

| Finding | Change | Before → after |
|---|---|---|
| The raw model renamed 4 of 30 receipt lines wrongly ("PNT BTR CRMY" → "Plain Butter Cream") | Faithfulness check in `ReceiptAI.apply` | Wrong names shown: 13% → 0% |
| On the real receipt photo, "Parle G 800g" became "Parle Granola": a lone letter counted as an abbreviation of any word | A one-letter code now only matches itself | Fixed; unit test added |
| Some tidied names came back in capitals, unchanged ("MAGGI NOODLES 12 PK") | All-caps names are re-cased; names that only change case or spacing are ignored | Fixed; unit test added |
| The model cooked with snacks ("Paneer Bhurji" with Aloo Bhujia, a curry with Parle-G). An instruction saying "snacks aren't ingredients" didn't help (25 of 60 dishes). | Obvious snacks are left out of the prompt (`RecipeGeneratorPrompt.isSnack`) | 25 of 60 dishes → 0 of 60 |
| In the 81-item pantry, the expiring cauliflower was used in only 2 of 5 runs | Expiring food is named again in the request | 2/5 → 5/5 |
| A vegetarian request still produced meat dishes in some runs (1 of 15, 2 of 15 in a later run) | Dishes with meat are dropped when vegetarian is on | Meat shown: 0 |
| "Under 20 minutes" still produced 2–3 slower dishes out of 15 | Dishes over 20 minutes are dropped when quick is on | Slower dishes shown: 0 |
