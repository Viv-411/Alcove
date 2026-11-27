WHAT DID YOUR TEAM BUILD OR IMPROVE DURING THIS HACKATHON?

Alcove is an entirely new project, built from scratch during the hackathon (first commit November 23, 2026). Before the event it existed only as a written idea: a one-page outline of the problem and a feature wish list. No code existed.

Everything in the submission was built during the event, in this order (the GitHub commit history shows each step):

1. The core app: barcode scan in/scan out with the phone camera, storage spots (pantry, fridge, freezer, cabinets, garage), "Do I have this?" search, receipt scanning with on-device text recognition, running-low and expiry alerts, and restock reminders based on usage.
2. A polish pass after testing on my iPhone 16 Pro and in the iOS Simulator, plus unit tests and automated screen tests.
3. An intro tour, Google sign-in, and a home setup flow (name your home, choose its spaces, see its members).
4. On-device AI: "What can I cook?" meal ideas and AI receipt-name reading, plus a shopping plan that says what to buy this week and how many.
5. An evaluation tool for the AI features, and the fixes it led to.

Not built yet: sharing a home with family members (the home and its members exist on the phone, but syncing them needs a backend), and support for physical barcode scanners.


HOW DID YOUR TEAM USE AI?

AI IN THE FINISHED APP

Model: Apple Intelligence's on-device language model, used through Apple's Foundation Models framework (iOS 26+). It runs entirely on the phone.

Why this model: Alcove handles a family's everyday data, and these features run many times a week. An on-device model is free per use, works offline (for example, in a store with bad signal), and keeps the household's data on the phone. I considered a cloud model (Claude through a small server) and decided against it because of the per-request cost and the need to run a server. The trade-off is a much smaller model, which I measured and designed around (below).

Where it's used:
1. "What can I cook?": the model suggests three dishes from what's at home, using food that expires soon first. It fills in a structured form (title, time, ingredients, steps) rather than free text.
2. Receipt reading: the model turns receipt shorthand ("GRN BNS 2LB") into readable names ("Green Beans 2lb") and spots items the household already tracks.

Key design choice: the model suggests, the app checks.
- Recipes: the model only lists ingredients. The app's own code decides which ones are at home by matching them against the real inventory, so a dish can never claim you have something you don't. Expired food and obvious snacks are left out of what the model sees. Dishes that break the user's request (meat when "vegetarian" is on, over 20 minutes when "quick" is on) are dropped.
- Receipts: the app's parser decides which lines are items, so the model can't add items. A suggested name is kept only if every abbreviation on the line fits a word in it and it adds no new words ("Pnr" may become "Paneer", never "Butter"). Otherwise the receipt's own text is kept for the user to fix.

How I checked it: I built an evaluation tool (Evaluation/AIEval in the repo) that runs the app's actual AI code against Apple's model on a Mac, because the iOS Simulator can't run the model. Results are in Evaluation/results.md.
- Receipts: 30 receipt lines labelled with the correct words. Trusting the model directly, 87% of names were right but 13% were confidently wrong (e.g. "PNT BTR CRMY" became "Plain Butter Cream"). With the app's check, 0% wrong names are shown and 83% are clear and correct; the rest stay as the receipt printed them. A second run gave identical results for all 30 lines.
- Meal ideas: 43 runs across six pantries, including a small one, an 81-item one, a vegetarian request and a quick-meal request. Every run that had expiring food used it, and no dish treated expired food as something you have.
- Example of a fix: the first design let the model decide what was "at home" and showed it expired food. Over 20 runs it used expired yogurt in 8 of 60 dishes and cooked with snacks (Aloo Bhujia, Parle-G biscuits) in 15 of 60. Telling the model "snacks aren't ingredients" didn't help, because it doesn't know Aloo Bhujia is a snack. Removing snacks and expired food from what the model sees brought both to 0 of 60.

Limits (when the AI can and can't be relied on):
- It needs iOS 26 or later on an iPhone 15 Pro or newer with Apple Intelligence turned on. On other phones the AI features are hidden and the rest of the app works normally.
- The measurements were taken on a Mac running Apple's model, not on an iPhone, because the Simulator can't run it. The iPhone uses the same framework, but speed and exact output may differ.
- Recipe ideas are suggestions from a small model. They are usually sensible everyday dishes, but whether a dish is good is a judgment call and isn't scored automatically. The full dish list is in results.md.
- The snack filter uses a word list (biscuits, chips, bhujia, cookies and similar), so a snack with an unusual name can still reach the model.
- Receipt reading is cautious by design: about 1 in 6 abbreviations is left for the user to fix rather than risk a wrong name.

AI USED DURING DEVELOPMENT

Tool: Claude Code (Claude Opus 5.5).

Contribution: Claude Code wrote most of the code, the automated tests, and the evaluation tool. I decided what to build, set the requirements, tested the results, and made the product decisions.

How I reviewed its work, with examples:
- Device testing: I installed each version on my iPhone 16 Pro. The barcode scanner worked well, so I kept it as built. Much of the rest felt unfinished (small details and visual issues), so I asked for a polish pass. Claude Code then tested every screen in the iOS Simulator with screenshots and fixed what was found.
- Bottom tab bar: on my phone the spacing of the tab bar looked wrong. The cause was a long tab label ("Do I have this?"). It was renamed "Search", and the full question stays as that screen's title.
- Google sign-in button: the first version used Google's standard button, which I rejected as dated-looking. It was replaced with a modern rounded button that still follows Google's branding rules.
- Choice of AI: Claude Code first offered Claude through a server or Apple's on-device model. I rejected the paid option, and we went with on-device.
- No AI for show: I asked that no feature be built just to look like AI. As a result, the shopping plan uses plain arithmetic on usage history, because without real store-price data, AI "sales advice" would only be guessing.
- AI-built tests checking AI-built code: the evaluation tool found a bug in Claude Code's own receipt check ("Parle G 800g" was being renamed "Parle Granola"). It was fixed and a permanent test was added. All 31 unit tests and the automated screen tests pass on the submitted version.


HOW CAN JUDGES RUN OR EVALUATE YOUR PROJECT?

Code: https://github.com/Viv-411/Alcove (the README has full details).

The quickest way to evaluate is the demo video and Evaluation/results.md, which has the AI test results. To run it yourself:

Requirements
- A Mac with Xcode 26 or later (built and tested with Xcode 27.2).
- To try everything except the AI features: the iOS Simulator is fine.
- To try the AI features: an iPhone 15 Pro or newer on iOS 26+ with Apple Intelligence turned on (Settings > Apple Intelligence & Siri). The Simulator can't run Apple's model.

Running the app
1. Clone the repo and open Alcove.xcodeproj in Xcode. Xcode downloads the one package dependency (Google Sign-In) automatically.
2. Select the Alcove target > Signing & Capabilities and choose your own team. Change the bundle ID if Xcode says it's taken.
3. Run on a simulator or a connected iPhone.
4. On the sign-in screen, tap "Continue without an account". This guest option appears in Debug builds, which is what Xcode runs by default. Google sign-in only works for accounts I've added as testers, because the Google sign-in setup hasn't been through Google's public review yet.

Sample data: to see a fully stocked home without scanning anything, add these launch arguments in Xcode (Product > Scheme > Edit Scheme > Run > Arguments): -uiTesting -sampleData. To preview the cooking screens in the Simulator with ready-made recipes (not real AI output), add -aiFixture.

Running the tests
- Unit and screen tests: xcodebuild test -project Alcove.xcodeproj -scheme Alcove -destination 'platform=iOS Simulator,name=iPhone 16 Pro'. For the receipt screen test, set TEST_RUNNER_RECEIPT_FIXTURE to the path of AlcoveTests/Fixtures/receipt.png.
- AI evaluation (Mac with Apple Intelligence on, macOS 26+): Evaluation/AIEval/run.sh. It writes Evaluation/results.md.

Test cases worth trying
- Scan a packaged food barcode on the Scan tab. A known product adds +1; a new one opens a form pre-filled from Open Food Facts.
- Switch to "Scan out" and scan it again: the count drops, taking the soonest-expiring stock first.
- Search tab: type an item you have and one you don't. The "Buy now" and "Buy this week" lists appear when the search is empty.
- Scan > Receipt: photograph a grocery receipt and review the items found.
- On an Apple Intelligence iPhone: Home > "What can I cook?", then try "Vegetarian" or a craving such as "something spicy".

External services
- Open Food Facts (free, public, no key): product lookup for new barcodes. Without internet, new items can still be added by hand.
- Google Sign-In: account sign-in. The client ID in Config/Google.xcconfig is an identifier, not a secret.
- Nothing else. There is no server, and all data, including AI processing, stays on the phone.

Known limitations
- The AI features need an Apple Intelligence iPhone, and the Simulator can't run them.
- AI results were measured on a Mac running Apple's model, not on an iPhone.
- Sharing a home with family isn't built yet. The inventory lives on one phone.
- Open Food Facts doesn't know every product, especially some regional brands, so these need their name typed once.
- Receipt reading works best on flat, well-lit receipts, and every item is reviewed before it's added.
- iPhone only: no iPad layout or Android version yet.
