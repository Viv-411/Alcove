# Alcove

A running count of the packaged food in your home: scan things in when you put them away, scan them out when you finish them, and check from anywhere whether you already have something.

iOS app: SwiftUI + SwiftData, iOS 18+, no third-party dependencies.

## Running it

1. Open `Alcove.xcodeproj` in Xcode.
2. Select the **Alcove** target → *Signing & Capabilities* → pick your Team. Change the bundle ID (`app.alcove.Alcove`) if Xcode says it's taken.
3. Plug in your iPhone and press Run.

### Google sign-in

The first launch shows an intro tour, then a sign-in screen, then home setup. To make **Sign in with Google** work:

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create a project (or pick one).
2. **Google Auth Platform → Branding**: fill in the app name (Alcove) and support email.
3. **Audience**: leave it in *Testing* and add your Google account as a test user.
4. **Clients → Create client → iOS**, with bundle ID `app.alcove.Alcove`.
5. Open `Config/Google.xcconfig` and paste in the **Client ID** and the **iOS URL scheme** Google shows you.

Until then, debug builds show a **Continue without an account** button so you can keep using the app. It isn't included in release builds.

Barcode and receipt scanning need a real iPhone camera. In the Simulator, use **Scan → ⋯ → Enter barcode**, and use **Choose a photo** for receipts.

## Testing

```sh
xcodebuild test -project Alcove.xcodeproj -scheme Alcove \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

- **AlcoveTests**: inventory logic (lot merging, soonest-expiry-first, undo), usage forecasts, receipt parsing and real on-device OCR of `AlcoveTests/Fixtures/receipt.png`.
- **AlcoveUITests**: walks every screen like a person would (scanning by typed barcode, adding a new product through Open Food Facts, importing a receipt). Set `TEST_RUNNER_SCREENSHOT_DIR=/some/folder` to save a screenshot of each step.

Debug-only launch arguments (compiled out of release builds):
- `-freshInstall` (with `-uiTesting`): start from the intro tour, as a brand-new install
- `-uiTesting`: fresh in-memory database, no notification prompt
- `-sampleData`: fills the house with realistic groceries and usage history
- `-receiptFixture <path>`: loads that image straight into the receipt importer

## What's in v0.1

| Feature | Where |
|---|---|
| Scan in / scan out with the phone camera (VisionKit) | Scan tab |
| Unknown barcodes are looked up on Open Food Facts (name, brand, size, photo) | `ProductLookup` |
| Storage spots: Pantry, Kitchen cabinets, Fridge, Freezer, Garage (editable) | Inventory tab, Settings |
| "Do I have this?": search by name, or scan a barcode in the store | Search tab |
| Receipt scanning: on-device OCR, review screen, learns receipt abbreviations | Scan → Receipt |
| Running-low alerts (per-item threshold) | `NotificationScheduler` |
| Expiry tracking + reminders (optional "ask for expiry" while scanning) | Product screen, Scan menu |
| Smart restock reminders from your actual usage rate | `UsageAnalyzer` |

## How the data works

- **Product**: a thing you buy (barcode, name, low-stock threshold, learned receipt aliases).
- **StockLot**: how many of a product are in one storage spot, with an optional expiry date. Scan out takes from the soonest-expiring lot first.
- **InventoryEvent**: append-only log of adds, uses and corrections. `.used` events drive the usage forecasts, so manual corrections are logged separately and don't distort them.

All stock changes go through `InventoryService`. The schema follows CloudKit's rules (defaults everywhere, optional relationships, no unique constraints) so sync can be added without a migration.

## Not built yet

- **Shared household**: homes, spaces and members exist locally now (owner = the signed-in Google account). Inviting family needs sync: a small backend (for example Firebase or Supabase) that accepts the same Google sign-in, so it can later work on Android too.
- **Meal ideas**: an LLM call over what's in stock and expiring soon.
- **External Bluetooth/USB barcode scanners**: these act as keyboards, so the plan is a hidden text field on the Scan screen that captures their input.
