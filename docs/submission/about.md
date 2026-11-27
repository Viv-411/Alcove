## Inspiration

Most families keep food in more places than they can keep track of: the pantry, the kitchen cabinets, the fridge, the freezer, and the garage shelves where the bulk bags go. Buying in bulk makes it harder. When dal, rice, atta and snacks come home several bags at a time, nobody knows how many are left. So people buy things they already have, run out of things they thought they had, and find expired food at the back of the shelf. Checking the whole house before every grocery trip isn't realistic, so most people guess.

We wanted a home inventory that keeps itself up to date: scan food when it goes in, scan it when it's finished, and check from the store whether you already have something.

## What it does

Alcove is an iPhone app that keeps a running count of the packaged food in your home.

- **Scan in, scan out**: point the camera at a barcode when you put food away or finish it. New barcodes are looked up on Open Food Facts for the name, brand and size.
- **Every storage spot**: the pantry, fridge, freezer, cabinets, garage, or any spot you add.
- **"Do I have this?"**: search by name, or scan a barcode in the store.
- **Receipt scanning**: after a big trip, photograph the receipt instead of scanning every bag. You review the items before anything is added.
- **Shopping plan**: "Buy now" and "Buy this week", with how many to buy, worked out from how fast your household actually uses each item.
- **Alerts**: running low, expiring soon, and restock reminders.
- **Home setup**: sign in with Google, name your home, choose its spaces, and see who's in it (sharing with family is next).

### The AI features

Both run entirely on the phone with **Apple Intelligence** (Apple's Foundation Models framework): free to use, private, and working offline.

1. **What can I cook?** Three meal ideas built around what's at home, using food that's about to expire first. Each idea shows which ingredients you have (expiring ones highlighted), which you'd need to buy, the cooking time and the steps. You can ask for quick or vegetarian meals, or type a craving.
2. **Receipt names.** Receipts print codes like `GRN BNS 2LB` or `CHKN THGH BNLS`. Alcove expands them into names people recognise ("Green Beans 2lb", "Chicken Thigh Boneless") before you add them.

## How we built it

- **App:** SwiftUI and SwiftData (iOS 18+). The data model follows CloudKit's rules so syncing a shared household can be added later without a migration.
- **Scanning:** VisionKit's live barcode scanner; the document camera and Vision text recognition for receipts; a hand-written parser that skips totals, tax and payment lines and handles "2 @ 3.49" quantity lines.
- **Product lookup:** the Open Food Facts API.
- **Usage forecasts:** each item's usage rate $r$ comes from the "used" scans of the last 120 days. The shopping plan suggests buying

$$\text{buy} = \max\big(1,\ \lceil 14r \rceil - q\big)$$

where $q$ is how many are at home, so a purchase lasts about two weeks. An item goes on "Buy this week" when $q / r \le 7$ days.
- **AI:** Apple's on-device model through the Foundation Models framework, with guided generation (Swift types the model must fill in) so the app always gets structured results it can check.
- **Sign-in:** Google Sign-In.

Our main design rule for the AI was **the model suggests, the app checks**:

- **Recipes:** the model lists ingredients, and the app's own code decides which ones are at home by matching them against the real inventory. A dish can never claim you have something you don't. Expired food and snacks are left out of what the model sees, and the app drops any dish that breaks the household's request (meat when vegetarian, over 20 minutes when quick).
- **Receipts:** the parser, not the model, decides which lines are items, so the model can't invent an item. A suggested name is kept only if every abbreviation on the line fits a word in it and it adds no new words. "Pnr" can become "Paneer" but never "Butter". Anything that fails keeps the receipt's own text.

We built an evaluation tool (`Evaluation/AIEval`) that runs the app's real AI code against the model: 30 hand-labelled receipt lines, a real receipt photo, and six different pantries, with the meal-idea scenarios run repeatedly. It writes its results to `Evaluation/results.md`.

**AI used during development:** the code was written with Claude Code (Claude Opus 5.5), with us directing the work. We tested the app on an iPhone 16 Pro and in the iOS Simulator, and backed it with 31 unit tests and 9 automated screen tests (3 of those run only on request or on a real iPhone). Details of what we checked and changed are in the AI disclosure section.

## Challenges we ran into

- **The Simulator can't run Apple's model.** It reports the model as available, then fails every request. We found this by probing the model directly. We then built the evaluation tool to run the same prompts on a Mac, and hid the AI features in the Simulator rather than show a broken screen.
- **The model refused receipts as "not English".** Bare codes like `GRN BNS 2LB` tripped Apple's language check, so every request failed. Quoting the lines and framing them as text copied from a receipt fixed it.
- **Confident wrong guesses.** Trusted blindly, the model got 4 of 30 receipt names wrong ("PNT BTR CRMY" became "Plain Butter Cream"; "Amul Pnr" became "Amul butter"). A wrong name is worse than an abbreviation, because it creates the wrong item in your inventory. This is why we added the faithfulness check.
- **Our own check had a bug.** Running the whole pipeline on a real receipt photo showed "Parle G 800g" becoming "Parle Granola": a single letter counted as an abbreviation of any word. We fixed it and added a test for it.
- **A small model and odd recipes.** The first version wrapped paneer in Parle-G biscuits and cooked with expired yogurt. Telling the model "snacks are not ingredients" made no measurable difference (25 of 60 dishes still used one), because it doesn't know Aloo Bhujia is a snack. Leaving obvious snacks out of the prompt did: 0 of 60.
- **Small context window.** In an 81-item pantry, the model used the one expiring item in only 2 of 5 runs. Listing urgent food first and naming it again in the request brought that to 5 of 5.

## Accomplishments that we're proud of

Measured with the app's real code on Apple's on-device model, running on a Mac because the Simulator can't run it (full results in `Evaluation/results.md`):

| Check | Result |
|---|---|
| Receipt names shown correctly (30 hand-labelled lines) | 83% with Alcove's check, up from 13% for the receipt text alone |
| Wrong receipt names shown | 0%, versus 13% if the model were trusted directly |
| Same receipt result on a second run | 30 of 30 |
| Meal-idea runs that used the food about to expire | 40 of 40 runs, including the 81-item pantry |
| Expired food shown as "from home" | 0, versus 8 of 60 dishes in our first design |
| Snacks used as cooking ingredients | 0 of 60 dishes, versus 15 of 60 in our first design |
| "From home" items that aren't actually at home | 0 by design, versus 7 of 144 in our first design |
| Time for three meal ideas | about 4–6 seconds |

We're also proud that it all runs on the phone: no server, no API key, no per-use cost, and the household's food data never leaves the device.

## What we learned

- A small on-device model is fast, free and private, but it shouldn't have the final say. The biggest quality gains came from moving decisions out of the model and into code we can test, not from rewording prompts.
- Measure, don't eyeball. Several prompt changes that looked better in a few tries made no difference over 60 dishes, and the evaluation caught a bug in our own safety check.
- A wrong answer can cost more than no answer. For receipts, the right behaviour when the model isn't sure is to leave the text alone and let the person fix it.
- Not every feature needs AI. The shopping plan is plain arithmetic on scan history; without real store-price data, an AI could only guess about sales.

## What's next for Alcove

- **Shared household:** invite family members so everyone sees the same inventory. This needs a small sync backend that accepts the same Google sign-in.
- **Physical scanners:** small Bluetooth/USB barcode scanners where food goes in and empty packages go out, eventually sold in packs.
- **More real-world testing:** more AI testing on iPhones and more real receipts from different stores.
- **Sales-aware shopping:** using local store prices, once we have a reliable source for them.
- **Android:** the backend and Google sign-in are chosen so an Android app can follow.
