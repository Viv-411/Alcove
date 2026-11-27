# Alcove demo video: scene-by-scene script

Target: 3:00, 1920×1080, 30 fps. About 400 words of voiceover (≈150 words a minute, with pauses).

Who makes what:
- **ME** = animated graphics I build in Remotion (titles, diagrams, callouts, number cards, device frame).
- **YOU** = footage you record (iPhone 16 Pro screen recordings, real-world camera shots, voiceover).

Structure (from common hackathon pitch advice): hook → problem → solution → demo (about half the video) → how it works → proof → what's next.

| # | Time | Scene | Source |
|---|---|---|---|
| 1 | 0:00–0:12 | Hook | YOU camera + ME text |
| 2 | 0:12–0:30 | The problem | ME graphic |
| 3 | 0:30–0:40 | Meet Alcove | ME logo |
| 4 | 0:40–0:55 | Scan in | YOU screen + camera |
| 5 | 0:55–1:03 | Scan out | YOU screen |
| 6 | 1:03–1:12 | Every storage spot | YOU screen |
| 7 | 1:12–1:22 | "Do I have this?" | YOU screen (+ store shot) |
| 8 | 1:22–1:40 | Receipt + AI names | YOU screen + ME callout |
| 9 | 1:40–1:52 | Shopping plan | YOU screen |
| 10 | 1:52–2:12 | What can I cook? | YOU screen |
| 11 | 2:12–2:40 | How it works | ME diagram |
| 12 | 2:40–2:52 | Proof | ME number cards |
| 13 | 2:52–3:00 | What's next + close | ME end card |

---

## 1. Hook (0:00–0:12)

**Visual:** Slow pan across the garage shelves of bulk bags, then a hand pulling a second, unopened bag of the same item from the pantry. Text fades in over the last shot: *"Wait… we already had this?"*

**VO:** "This is our garage. Rice, dal, atta, snacks: we buy in bulk, and it ends up everywhere. Last month I bought more dal… and found two bags already on the shelf."

> Replace the dal line with a true example from your house. A real story is the strongest hook.

## 2. The problem (0:12–0:30)

**Visual (ME):** A simple house outline. Five spots light up one by one: Pantry, Cabinets, Fridge, Freezer, Garage, each with a "?" count. Then three cards slide in:
- 🛒 Buy what you already have
- 🫙 Run out of what you need
- 🗓️ Find it expired

**VO:** "Food lives in the pantry, the cabinets, the fridge, the freezer and the garage. Nobody can keep all of that in their head, so we guess. We buy things we already have, run out of things we thought we had, and find food that expired at the back of the shelf."

## 3. Meet Alcove (0:30–0:40)

**Visual (ME):** The "?" counts turn into real numbers and the house shrinks into the Alcove logo. Tagline: *"Your home's food, counted for you."*

**VO:** "So I built Alcove: an iPhone app that keeps a running count of the food in your home, without anyone writing lists or counting shelves."

## 4. Scan in (0:40–0:55)

**Visual:** Split screen. Left: camera shot of you scanning a bag on the garage shelf. Right (ME device frame): your screen recording. A known product shows "+1", then a new product opens a form already filled in.

**VO:** "When groceries come home, scan the barcode. Alcove recognises the product, adds one, and remembers where it's stored. New products fill themselves in from a free, public food database."

## 5. Scan out (0:55–1:03)

**Visual:** Screen recording: switch to "Scan out", scan, and the count drops.

**VO:** "When something's finished, switch to scan out. Alcove takes from the oldest stock first."

## 6. Every storage spot (1:03–1:12)

**Visual:** Screen recording: the Inventory tab, scrolling through Pantry, Fridge and Garage with counts.

**VO:** "Each storage spot keeps its own count, so you know where everything is, not just how much you have."

## 7. "Do I have this?" (1:12–1:22)

**Visual:** Optional camera shot of a store aisle. Then a screen recording: the Search tab, typing "rice", which shows "2 at home · Garage".

**VO:** "At the store and not sure if you need more? Search, or scan the item on the shelf, and see what's already at home."

## 8. Receipt + AI names (1:22–1:40)

**Visual:** Screen recording: Scan → Receipt, photograph a receipt, "Tidying names", then the reviewed list with ✨ icons.
**ME callout:** freeze on one row and zoom in: `GRN BNS 2LB` → **Green Beans 2lb**, with a small "on-device AI" tag.

**VO:** "After a big trip, skip the barcodes and snap the receipt. Receipts print shorthand like this. Alcove's on-device AI turns it into names you recognise and matches items you already track. You check the list, then add everything at once."

## 9. Shopping plan (1:40–1:52)

**Visual:** Screen recording: the Search tab with an empty search shows "Buy now" and "Buy this week" (for example "Runs out Mon · buy 3"). Also show the Home tab's running-low and expiry alerts.

**VO:** "Alcove learns how fast your family uses each item. It tells you what to buy now, what to buy this week, and how many. That part is simple math on your history, so there's no AI guessing."

## 10. What can I cook? (1:52–2:12)

**Visual:** Screen recording: Home → "What can I cook?" Show the "Use first" chips, the three meals streaming in, then tap one to see what you have, what you need, and the steps. Next, turn on "Vegetarian" or type "something spicy".
If the AI takes a few seconds, I'll speed that part up and show a small "2× speed" label so it stays honest.

**VO:** "And when it's time for dinner, tap What can I cook? Alcove suggests three meals from what's already at home, using up food that's about to expire first. It shows what you have, what you'd need to buy, and the steps. Want something quick, vegetarian, or spicy? Just ask."

## 11. How it works (2:12–2:40)

**Visual (ME):** The diagram builds up in time with the VO.

```
 ┌──────────────────────── iPhone ─────────────────────────┐
 │  Camera ──▶ Apple Vision (barcodes, receipt text)       │
 │                    │                                    │
 │                    ▼                                    │
 │  Alcove app logic ◀──▶ Inventory (stored on the phone)  │
 │       │      ▲                                          │
 │ prompt│      │structured answer                         │
 │       ▼      │                                          │
 │  Apple Intelligence on-device model                     │
 │       ──▶ [ App checks ✓ ] ──▶ what you see             │
 └─────────────────────────────────────────────────────────┘
        ▲ product lookup only        ▲ sign-in only
   Open Food Facts                Google Sign-In
```

At the end the phone border glows, with the label *"Your food data stays on your phone."*

**VO:** "Here's how it fits together. Almost everything runs on the phone. The camera feeds Apple's barcode and text recognition, and your inventory is stored on the device. The only things that go online are product lookups and sign-in. The AI is Apple Intelligence's on-device model: free, offline and private. But it's small, and small models make confident mistakes. So my rule is: the model suggests, the app checks. The app decides what you actually have, and only keeps a receipt name if it really fits what's printed."

## 12. Proof (2:40–2:52)

**Visual (ME):** Three number cards count up:
- **Wrong receipt names shown: 10% → 0%**
- **43 meal-idea test runs, 6 different pantries**
- **Expired food treated as "at home": 0**

**VO:** "I measured this with an evaluation tool. When the app trusted the model directly, about one in ten receipt names were wrong. With the app checking, none were."

## 13. What's next + close (2:52–3:00)

**Visual (ME):** Logo, the line *"Next: shared households · physical scanners"*, and the GitHub link.

**VO:** "Next up: one shared inventory for the whole family. Alcove: know what's at home before you buy."

---

## What I need from you

**Screen recordings (iPhone 16 Pro):** Control Center → Screen Recording. Turn on Do Not Disturb first, and keep each clip short, one per scene.
- Run the app from Xcode with the `-sampleData` launch argument so the home is fully stocked (but **not** `-aiFixture`, so the AI is real). Apple Intelligence must be on.
- Clips: scene 4 (scan a known item, then a new item), 5, 6, 7, 8 (a real grocery receipt), 9 (Search, plus Home alerts), 10 (one normal run plus one with Vegetarian or a craving).
- Tap slowly and pause about 1 second on each result. I can speed clips up, but I can't slow them down nicely.

**Camera shots (any phone, landscape, 4K or 1080p):** garage shelves (scene 1), pulling a duplicate bag from the pantry (scene 1), scanning a bag on the shelf, filmed from the side (scene 4), and optionally a store aisle (scene 7).

**Voiceover:** One file per scene (`s01.m4a` … `s13.m4a`). Voice Memos is fine; use a quiet, soft-furnished room with the phone about 20 cm from your mouth. I'll time every scene to the length of its voiceover, so you don't need to hit the times exactly.

**Optional:** a background music track (for example from the YouTube Audio Library, no attribution needed). I'll keep it low under the voice.
