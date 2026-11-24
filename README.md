# Alcove

A running count of the packaged food in your home: scan things in when you put them away, scan them out when you finish them, and check from anywhere whether you already have something.

iOS app: SwiftUI + SwiftData, iOS 18+, no third-party dependencies.

## Running it

1. Open `Alcove.xcodeproj` in Xcode.
2. Select the **Alcove** target → *Signing & Capabilities* → pick your Team. Change the bundle ID (`app.alcove.Alcove`) if Xcode says it's taken.
3. Plug in your iPhone and press Run.

Barcode and receipt scanning need a real iPhone camera. In the Simulator, use **Scan → ⋯ → Enter barcode**, and use **Choose a photo** for receipts.

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

- **Shared household**: needs sync. The plan is CloudKit sharing (free, no server), and it needs a paid Apple Developer account.
- **Meal ideas**: an LLM call over what's in stock and expiring soon.
- **External Bluetooth/USB barcode scanners**: these act as keyboards, so the plan is a hidden text field on the Scan screen that captures their input.
