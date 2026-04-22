# Last Paid

`Last Paid` is a SwiftUI-first iPhone app for one job: scan a product barcode, save the price and place, and recall that history quickly later.

## Developer Onboarding

1. Generate the Xcode project with `xcodegen generate`.
2. Open `HowMuch.xcodeproj`.
3. Run the `HowMuch` scheme on an iPhone simulator or device.
4. On simulator builds, use manual barcode entry because the barcode camera flow needs a real iPhone camera.

The core product loop is:

- scan or type a barcode
- save the price you paid and where you bought it
- rescan later to see the latest price and the cheapest places you recorded

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

## Tests

- The test target is non-hosted and compiles the core data, catalog services, and view models directly so persistence and flow tests can run without launching the app UI.
- `CatalogServiceTests` covers product creation, barcode lookup, multi-entry history, latest-price retrieval, store-name search, and edit/delete flows.
- `CheapestPlacesCalculatorTests` covers place aggregation, tie-breaking, unnamed-entry omission, and mixed-currency exclusion.
- `CatalogScanFlowTests` covers known-versus-new scan routing plus quick-add save follow-up behavior.
- `KnownProductQuickAddViewModelTests` covers the repeat-scan compare-and-save flow, including refreshed latest price, cheapest-place recalculation, and recent-store updates.
- `PriceHistoryCalculatorTests` covers latest/previous price comparison behavior.

Run tests with:

```bash
xcodebuild -project HowMuch.xcodeproj -scheme HowMuch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Release assets

- `appstore/screenshots/en-US/iphone65`: generated App Store screenshot set for the 6.5-inch iPhone class.
- `appstore/app-info/en-US.json`: canonical English app-info metadata for app name, subtitle, and privacy policy URL.
- `appstore/version/1.0/en-US.json`: canonical English version metadata for description, keywords, and support URL.
- `appstore/privacy/no-data-collected.json`: App Privacy declaration used for the current release flow.
- `appstore/review-notes.txt`: reviewer notes for barcode scanning, manual entry, and optional location tagging.
- `tools/generate_app_store_screenshots.py`: deterministic generator for the committed screenshot assets.
- `docs/`: GitHub Pages support site used for the App Store support URL.

## ASC Metadata Workflow

`appstore/` is the source of truth for App Store listing data used by `asc metadata`.

- `appstore/app-info/en-US.json` owns the app-level name, subtitle, and privacy policy URL.
- `appstore/version/1.0/en-US.json` owns the version-level description, keywords, and support URL.
- `docs/index.html` is the published support page used by the version metadata.
- Default the privacy policy URL to `https://daliso.com/privacy` unless an explicit override is requested.

Validate metadata locally with:

```bash
asc metadata validate --dir appstore --output json --pretty
```

Preview live ASC changes with:

```bash
asc metadata push --app 6762534654 --version 1.0 --platform IOS --dir appstore --dry-run --output json --pretty
```

Keep live App Store review work separate from repo changes. Read the latest App Review message first, then make the minimum ASC change needed.

## Next steps

- Add per-unit normalization only if the product model starts capturing reliable comparable quantity units.
- Add product photos, CSV export, or backup/import flows on top of the existing data model.
- Add CloudKit options to the `NSPersistentCloudKitContainer` configuration when sync becomes a v2 requirement.
