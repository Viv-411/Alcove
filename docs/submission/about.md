## Inspiration

Most families keep food in more places than they can keep track of: the pantry, the kitchen cabinets, the fridge, the freezer, and the garage shelves where the bulk bags go. Buying in bulk makes it harder. When dal, rice, atta and snacks come home several bags at a time, nobody knows how many are left. So people buy things they already have, run out of things they thought they had, and find expired food at the back of the shelf. Checking the whole house before every grocery trip isn't realistic, so most people just guess.

I wanted a home inventory that keeps itself up to date, without anyone writing lists or counting shelves.

## What it does

Alcove is an iPhone app that keeps a running count of the food in your home.

- **Scan in, scan out:** scan a barcode with the phone's camera when food goes in and again when it's finished. Unknown barcodes are looked up automatically for the product's name, brand and size.
- **Every storage spot:** separate counts for the pantry, fridge, freezer, garage, or any spot you add, so you know where things are, not just how many.
- **"Do I have this?":** search or scan a barcode from the grocery store to see what's already at home.
- **Receipt scanning:** after a big trip, snap the receipt instead of scanning every bag, then check the items before they're added.
- **Alerts and a shopping plan:** Alcove warns you when you're running low or food is about to expire. It also learns how fast your family uses each item, so it can tell you what to buy this week and how many.
- **Your home:** sign in with Google, name your home and set up its spaces.

Two features use AI that runs entirely on the phone:

- **What can I cook?** suggests three meals built from what's already at home, using up food that's about to expire first. It shows which ingredients you have, what you'd need to buy, and the steps. You can ask for something quick or vegetarian, or type a craving.
- **Receipt reading:** receipts print shorthand like `GRN BNS 2LB` or `CHKN THGH BNLS`. Alcove turns these into names people recognise, like "Green Beans 2lb" and "Chicken Thigh Boneless", and matches them to items you already track.

## How I built it

Alcove is a native iOS app built with SwiftUI and SwiftData. Barcode scanning and receipt reading use Apple's VisionKit and Vision frameworks, product details come from the Open Food Facts database, and sign-in uses Google Sign-In.

For the AI features, I chose Apple Intelligence's on-device model, accessed through the Foundation Models framework. It's free to use, works offline, and a family's food data never leaves their phone, which matters for something as personal as what's in your kitchen. The model returns structured answers, which lets the app check every result before showing it.

My main design rule was **the model suggests, the app checks**. For recipes, the model lists the ingredients, but the app decides which ones you actually have by matching them against your real inventory. For receipts, the app's own parser decides which lines are items, so the model can only rename them, and a new name is kept only if it really fits the abbreviation on the receipt.

I built the app with the help of Claude Code, testing it on my iPhone 16 Pro and with automated tests. I also built an evaluation tool that runs the app's real AI code against the model across dozens of receipt lines and pantry setups. I used it to measure every change instead of judging from a few tries.

## Challenges I ran into

The biggest challenge was getting reliable results from a small on-device model. It was fast and private, but it made confident mistakes. Early on it suggested wrapping paneer in Parle-G biscuits and cooking with expired yogurt. When a receipt said "Amul Pnr" (paneer), it guessed "Amul butter". Rewording the instructions helped less than I expected. What worked was having the app's own code check the model's answers and keep only what it could verify, and keeping things like expired food and snacks out of what the model sees in the first place.

There were practical surprises too. The iPhone Simulator can't run Apple's model at all, so I built a separate way to test the AI on my Mac. And the model initially refused to read receipts at all because it decided the shorthand wasn't English.

## Accomplishments that I'm proud of

- A complete, polished app that covers scanning, storage spaces, search, receipts, alerts and shopping plans, with a guided intro tour and home setup.
- AI that runs fully on the phone: no server, no API key, no per-use cost.
- AI quality that I measured rather than guessed. On my receipt test set, the app shows no wrong names, where trusting the model directly got about 1 in 8 wrong. In testing, meal ideas consistently used the food that was about to expire and never treated expired food as something you have.

## What I learned

A small on-device model is a great fit for private, everyday features, but it shouldn't have the final say. The biggest improvements came from moving decisions out of the model and into code I could test, and from measuring over many runs; a change that looked better in three tries often made no difference over sixty. I also learned that not every feature needs AI: the shopping plan is simple arithmetic on how fast a family uses things, and it's more trustworthy that way.

## What's next for Alcove

- **Shared household:** invite family members so everyone sees the same inventory.
- **Physical scanners:** small barcode scanners where food goes in and empty packages go out, eventually sold in packs.
- **Testing with more families** and more real receipts from different stores.
- **Sales-aware shopping** once there's a reliable source of local store prices.
- **Android.**
