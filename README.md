# Last Paid

`Last Paid` is a SwiftUI-first iPhone app for one job: scan a product barcode, save the price you paid, and recall that price quickly later.

## Architecture

- `HowMuch/Models`: Core Data managed object models for `Product` and `PriceEntry`.
- `HowMuch/Persistence`: programmatic `NSPersistentCloudKitContainer` setup with in-memory support for tests and a local SQLite store for the app.
- `HowMuch/Repositories`: repository abstraction plus `CoreDataCatalogRepository` for local persistence.
- `HowMuch/Services/Catalog`: app use-cases for scan resolution, save/update/delete flows, and history calculation.
- `HowMuch/Services/Scanner`: AVFoundation barcode scanning, duplicate suppression, and camera permission handling.
- `HowMuch/ViewModels`: small observable screen state objects for list, scanner, and product detail flows.
- `HowMuch/Views`: lightweight SwiftUI surfaces that exercise the core flows and give a frontend pass stable integration points.

## Core behavior

- Scans EAN-13, EAN-8, UPC-A, UPC-E, Code 128, Code 39, and QR payloads with AVFoundation.
- Stores product metadata and a full history of price entries in Core Data.
- Supports manual barcode fallback, search by product name or barcode, and store-name matching from price history.
- Tracks latest and previous prices with a simple difference calculation.
- Uses `Decimal` for money and defaults currency handling to `ZAR`.

## Project setup

1. Generate the Xcode project with `xcodegen generate`.
2. Open `HowMuch.xcodeproj`.
3. Run the `HowMuch` scheme on an iPhone simulator or device.

Note: barcode scanning requires a real iPhone camera. On the iOS simulator,
use the manual barcode entry flow instead.

## Tests

- The test target is non-hosted and compiles the core data/service layers directly so persistence tests can run without launching the app UI.
- `CatalogServiceTests` covers product creation, barcode lookup, multi-entry history, latest-price retrieval, store-name search, and edit/delete flows.
- `PriceHistoryCalculatorTests` covers latest/previous price comparison behavior.

Run tests with:

```bash
xcodebuild -project HowMuch.xcodeproj -scheme HowMuch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Release assets

- `appstore/screenshots/en-US/iphone65`: generated App Store screenshot set for the 6.5-inch iPhone class.
- `appstore/metadata/en-US.json`: canonical English App Store marketing copy for subtitle, description, and keywords.
- `appstore/privacy/no-data-collected.json`: App Privacy declaration used for the current release flow.
- `appstore/review-notes.txt`: reviewer notes for barcode scanning, manual entry, and optional location tagging.
- `tools/generate_app_store_screenshots.py`: deterministic generator for the committed screenshot assets.
- `docs/`: GitHub Pages support site and privacy policy used for the App Store support and privacy URLs.

## Next steps

- Replace the temporary SwiftUI shell with a more polished frontend without changing the repository or service contracts.
- Add product photos, CSV export, or backup/import flows on top of the existing data model.
- Add CloudKit options to the `NSPersistentCloudKitContainer` configuration when sync becomes a v2 requirement.
