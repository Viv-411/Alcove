## Inspiration

Most families keep food in more places than they can keep track of: the pantry, the kitchen cabinets, the fridge, the freezer, and the garage shelves where the bulk bags go. Buying in bulk makes it harder. When dal, rice, atta and snacks come home several bags at a time, nobody knows how many are left. So people buy things they already have, run out of things they thought they had, and find expired food at the back of the shelf. Checking the whole house before every grocery trip isn't realistic, so most people just guess.

We wanted a home inventory that keeps itself up to date, without anyone writing lists or counting shelves.

## What it does

Alcove is an iPhone app that keeps a running count of the food in your home. You scan a barcode when food goes in and again when it's finished, and Alcove keeps the count for every storage spot: pantry, fridge, freezer, garage, or anywhere else. From the grocery store you can check "Do I have this?" by searching or scanning. After a big shopping trip you can snap the receipt instead of scanning every bag. Alcove also warns you when you're running low or food is about to expire, and learns how fast your family uses things so it can tell you what to buy and when.

Two features use AI that runs entirely on the phone:

- **What can I cook?** suggests meals from what's already at home, using up food that's about to expire first.
- **Receipt reading** turns receipt shorthand like `GRN BNS 2LB` into names people recognise, like "Green Beans 2lb".

## How we built it

Alcove is a native iOS app built with SwiftUI and SwiftData. Barcode scanning and receipt reading use Apple's VisionKit and Vision frameworks, and product details come from Open Food Facts. The AI features use Apple Intelligence's on-device model through the Foundation Models framework, so they're free to use, work offline, and keep a family's data on their phone.

Our main design rule for the AI was **the model suggests, the app checks**. For example, the model lists a recipe's ingredients, but the app decides which ones you actually have by matching them against your real inventory. So a suggestion can never claim you have something you don't.

We built the app with the help of Claude Code, and tested it on an iPhone and with automated tests. We also built an evaluation tool that runs the app's real AI code against the model over dozens of test cases.

## Challenges we ran into

The biggest challenge was getting reliable results from a small on-device model. It was fast and private, but it made confident mistakes. Early on it suggested wrapping paneer in Parle-G biscuits, and when a receipt said "Amul Pnr" (paneer) it guessed "Amul butter". Rewording the instructions helped less than we expected. What worked was having the app's own code check the model's answers and keep only the ones it could verify. We also found that the iPhone Simulator can't run Apple's model at all, so we built a separate way to test the AI on a Mac.

## Accomplishments that we're proud of

- A complete, polished app that covers scanning, storage spaces, search, receipts, alerts and shopping plans.
- AI that runs fully on the phone: no server, no API key, no per-use cost.
- Measured, not guessed, AI quality. On our receipt test set, the app shows no wrong names, where trusting the model directly got about 1 in 8 wrong. Meal ideas consistently use the food that's about to expire.

## What we learned

A small on-device model is a great fit for private, everyday features, but it shouldn't have the final say. We got the biggest improvements by moving decisions out of the model and into code we could test, and by measuring results over many runs instead of judging from a few tries. We also learned that not every feature needs AI: the shopping plan is simple arithmetic on how fast a family uses things, and it works better that way.

## What's next for Alcove

- **Shared household:** the whole family sees the same inventory.
- **Physical scanners:** small barcode scanners by the pantry and the bin, eventually sold in packs.
- **Testing with more families** and more real receipts.
- **Sales-aware shopping** once we have a reliable source of local prices.
- **Android.**
