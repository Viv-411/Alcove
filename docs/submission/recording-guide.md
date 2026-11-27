# Recording guide: voiceover and demo clips

## Voiceover

Read at a relaxed, conversational pace (about 150 words a minute). The times assume that pace; going a little faster or slower is fine, because each scene is timed to your recording.

| File | Target | Say this |
|---|---|---|
| `s01` | ~12 s | *(the hook, whenever you're ready)* |
| `s02` | ~20 s | Food lives in the pantry, the cabinets, the fridge, the freezer, and the garage. Nobody can keep all of that in their head, so we guess. We buy things we already have, run out of things we thought we had, and find food that expired at the back of the shelf. |
| `s03` | ~10 s | So I built Alcove: an iPhone app that keeps a running count of the food in your home, without anyone writing lists or counting shelves. |
| `s04` | ~12 s | When groceries come home, scan the barcode. New products fill themselves in from a free, public food database. Choose where it's going, and save. Next time, a scan just adds one. |
| `s05` | ~6 s | When something's finished, switch to Scan out. Alcove takes from the oldest stock first. |
| `s06` | ~8 s | Each storage spot keeps its own count, so you know where everything is, not just how much you have. |
| `s07` | ~10 s | At the store and not sure if you need more? Search, or scan the item on the shelf, and see what's already at home. |
| `s08` | ~16 s | After a big trip, skip the barcodes and snap the receipt. Receipts print shorthand like this. Alcove's on-device AI turns it into names you recognise, and matches items you already track. You check the list, then add everything at once. |
| `s09` | ~15 s | Alcove learns how fast your family uses each item. It tells you what to buy now, what to buy this week, and how many. That part is simple math on your history, so there's no AI guessing. |
| `s10` | ~20 s | And when it's time for dinner, tap "What can I cook?" Alcove suggests three meals from what's already at home, using up food that's about to expire first. It shows what you have, what you'd need to buy, and the steps. Want something quick, vegetarian, or spicy? Just ask. |
| `s11` | ~28 s | Almost everything runs on the phone. The camera feeds Apple's barcode and text recognition, and your inventory stays on the device. Only product lookups and sign-in go online. The AI is Apple Intelligence's on-device model: free, offline, and private. But small models make confident mistakes. So my rule is: the model suggests, the app checks. The app decides what you actually have, and only keeps a receipt name that fits what's printed. |
| `s12` | ~11 s | I measured this with an evaluation tool. When the app trusted the model directly, about one in ten receipt names were wrong. With the app checking, none were. |
| `s13` | ~7 s | Next up: one shared inventory for the whole family. Alcove. Know what's at home, before you buy. |

Total: about 2:55, plus short gaps between scenes.

**How to record**
- Use Voice Memos in a quiet room with soft furnishings (a closet full of clothes works well). Hold the phone about 20 cm from your mouth, slightly to the side.
- Record one file per scene and rename it `s02`, `s03`, and so on.
- Leave about 1 second of silence at the start and end of each file.
- If you stumble, re-record the whole file. They're short.
- Slow down on "the model suggests, the app checks". It's the line judges should remember.

## Setting up the sample data (on your iPhone)

The sample data fills the app with a realistic home called "Sharma Home". It has 16 items across the pantry, fridge, freezer, cabinets and garage, and 50 days of usage history so the shopping plan has something to learn from. Paneer expires in 2 days, Greek yogurt is already expired, and peanut butter is out.

1. Check the phone has **iOS 26** and **Apple Intelligence on** (Settings → Apple Intelligence & Siri). Wait until the model has finished downloading.
2. Connect the iPhone to the Mac and open `Alcove.xcodeproj`. Choose your iPhone as the run destination at the top of the window.
3. Go to **Product → Scheme → Edit Scheme… → Run → Arguments**. Under **Arguments Passed On Launch**, press **+** twice and add:
   - `-uiTesting`
   - `-sampleData`

   Make sure `-noAI` and `-aiFixture` are **not** listed (or are unchecked). Otherwise the cooking screen shows canned recipes or nothing.
4. Press **⌘R**. The app opens straight into Sharma Home, already signed in as a guest, with no tour or sign-in screen.
5. Keep in mind that this data **lives only in memory**:
   - Every relaunch from Xcode starts from fresh sample data, which is handy for retakes.
   - Anything you scan disappears when the app restarts, so record scenes 4 and 5 in the same session without quitting the app.
6. When you're finished, go back to Edit Scheme and **uncheck both arguments** so the app goes back to your real data.

## Before you record

- Turn on Do Not Disturb, charge the phone, and turn the brightness up. Use light mode the whole way through so the clips match.
- Add Screen Recording to Control Center (Settings → Control Center). Long-press the button to make sure the **microphone is off**; the voiceover is recorded separately.
- Do one practice "What can I cook?" run before recording. The first AI request after launch is the slowest.
- **Move slowly.** Pause about 1 second after each tap and on each result. I can speed clips up, but slowed-down clips look bad.
- Record one clip per scene. Start recording, wait 1 second, do the steps, wait 1 second, then stop.

## Demo steps, scene by scene

**Scene 4: Scan in (~12 s of use, record 20–30 s)**
1. Have a packaged food from a common brand ready that **isn't** in the sample data (a box of cereal or pasta works well). Try it once first to check it's in the food database.
2. Open the **Scan** tab and make sure **Scan in** is selected.
3. Tap **Putting away in** and choose **Garage** (or Pantry).
4. Point the camera at the barcode. You'll see "Looking up…", then the **New item** form filled in with the name, brand and size.
5. Pause on the filled-in form, set an expiry date if it asks, and tap **Save**.
6. Scan the **same product again**. It now just adds one, which shows "next time, a scan just adds one".
7. *(Optional camera shot:)* someone films you from the side doing step 4 at the shelf.

**Scene 5: Scan out (record ~10 s)**
1. Still on the Scan tab, switch to **Scan out**.
2. Scan the same product. The count drops by one.

**Scene 6: Every storage spot (record ~15 s)**
1. Open the **Inventory** tab and pause on the full list.
2. Tap the location chips one at a time: **Garage**, **Fridge**, **Freezer**.
3. Tap **Sona Masoori Rice** to show it's split between the Garage and the Pantry, then go back.

**Scene 7: "Do I have this?" (record ~15 s)**
1. Open the **Search** tab and type `rice` slowly. Pause on the results, which show counts and where each item is.
2. Clear the search, type `ketchup`, and pause on "Not in your inventory".
3. *(Optional:)* tap the scan button on that screen and scan an item to show the store-shelf check.

**Scene 8: Receipt (record ~30 s)**
1. Use a real grocery receipt. Flatten it and put it on a table in good light.
2. **Scan** tab → **Receipt** → **Scan receipt**, then capture and save the scan.
3. On the review screen, wait while "Tidying names" runs. **Don't scroll during this.** Then pause on the list with the ✨ icons.
4. Scroll slowly through the items, then tap **Add (number)**.
5. Tell me which receipt line looks best as the zoomed-in example (shorthand to clean name). I'll build the callout from your footage.

**Scene 9: Shopping plan and alerts (record ~15 s)**
1. Open the **Search** tab with the search box **empty**. Pause on **Buy now** (peanut butter is "Out") and **Buy this week**, then scroll slowly.
2. Open the **Home** tab and pause on the paneer and yogurt expiry alerts and the running-low list.

**Scene 10: What can I cook? (record two clips)**
- Clip A:
  1. **Home** → tap the **What can I cook?** card.
  2. Pause on **Use these first** (paneer).
  3. Tap **Suggest meals** and let the three meals appear without touching anything.
  4. Tap the first meal and pause on **From home**, **To buy** and **Steps**. Go back.
- Clip B: turn on **Vegetarian** (or **Under 20 min**), type `something spicy` in the craving box, then press **Go** or **Suggest meals**.

**Extra clip (useful for transitions):** the Home tab, scrolled slowly from top to bottom.

## Getting the files to me

AirDrop everything to the Mac and put it here:
- Voiceover → `~/Developer/AlcoveVideo/public/vo/` (`s02.m4a` …)
- iPhone screen recordings → `~/Developer/AlcoveVideo/public/screen/`. Name them by scene if you can (`s04.mov`, `s10a.mov` …); if not, I'll sort them out.
- Camera shots → `~/Developer/AlcoveVideo/public/camera/`
