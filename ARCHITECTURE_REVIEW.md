# Centre architecture review and cleanup

Reviewed: 24 November 2026  
Audience: CUHK students in Hong Kong

## Changes in this pass

- Moved `CentreDataStore.swift` from `App` to `Persistence` to make the local storage responsibility visible in the project structure.
- Renamed `CampusMerchantAliases..swift` to `Location/CampusMerchantAliases.swift`.
- Removed unused imports from `MonthlyBudgetEditor.swift` and `ExpenseEditor.swift`.
- Kept existing features and persistence behavior intact. No remote database, sync framework, or new dependency was added.

## Current state

The app is already self-contained for core use. `CentreDataStore` creates a local SwiftData container for expenses, payment import events, and payment-source settings. No remote database is required. The monthly budget is stored locally with `@AppStorage`. This is local persistence, not an abstraction for swapping storage implementations.

There are useful beginnings of a backend boundary: payment notification parsers return values, and `CentrePlaceMatcher` computes candidate places without rendering UI. The place matcher and catalog are therefore useful logic to keep separate as the app evolves.

## Where the current approach is lacking

### UI and persistence are coupled

Overview, transaction, payment setup, and admin screens use SwiftData queries or model contexts directly. Editors mutate SwiftData models, while `PaymentImportService` creates its own model context from the global container. That makes local storage easy today, but makes it harder to test business rules independently or add a sync-backed implementation later.

`ContentView` also combines dashboard rendering with expense aggregation, persistence writes, location capture, test-purchase creation, notification scheduling, and notification navigation. These responsibilities should move behind small application services as those flows are actively changed.

### Payment import has too many responsibilities in one place

`PaymentImportService` coordinates parsing, source settings, duplicate detection, import-event state, expense creation, persistence, and outcome messages. Keep parsers pure and make import policy explicit. A small coordinator plus a persistence adapter is enough; there is no need for a large framework.

The import models store event status, source, and parser identifiers as free-form strings. Central typed values or enums with stable stored raw values would reduce accidental state drift. Also confirm that raw notification text is actually removed: an expiry timestamp alone does not delete data. The generic card parser should be tested against verified formats because its broad HK$ pattern can accept unrelated notifications.

### CUHK coverage and location guesses are preliminary

The place catalog is a hard-coded sample, not a complete CUHK directory. Several college groups are declared but have no place records. The catalog itself documents that its coordinates and 40 m default radius are initial testing values. Nearby venues can overlap, so location matches should remain suggestions requiring user confirmation.

Expenses store coordinates and accuracy but not a confirmed place ID, college, match provenance, or confidence. Merchant aliases currently contain one substring rule (`FOTD` → Morningside). The catalog and alias rules are separate sources of campus knowledge, and some service shortcuts are also embedded in the expense editor.

### Budget and transaction semantics are intentionally simple

The monthly budget is one value reused for every month. Editing it changes the limit shown for past months too; there is no budget history or category-level budget. Expense amounts are integer minor units, which is a good base for HKD, but currency is implicit on the expense and positive-only spend cannot represent refunds or income distinctly.

Month grouping uses the device's current calendar/time zone. For a Hong Kong-targeted app, decide and document whether month boundaries follow the user's device or Hong Kong time. Categories and payment methods are free-form strings, so future renames/localization can fragment aggregates.

### Local data recovery is not addressed

If local container initialization fails, `CentreDataStore` calls `fatalError`. There is no visible export/import or recovery path in the current structure. Local-only storage meets the offline requirement, but users should eventually have a way to back up or export their records.

## Suggested simple architecture

Keep the existing SwiftUI feature views as rendering and input. Add only the boundaries needed to keep those views from owning business rules and storage details:

- **Domain**: plain Swift value types and deterministic rules (money parsing, budget totals, import state transitions, location candidates). No SwiftUI, SwiftData, or CoreLocation dependencies in the values intended to cross the boundary.
- **Persistence**: local SwiftData models and adapters/repositories. Inject the local implementation from the app composition root. UI and import flows should use these interfaces rather than creating contexts globally.
- **Features**: SwiftUI views bind to view state/value models and call small actions. Avoid passing SwiftData model objects into future C++ code.
- **Integrations**: Wallet/App Intents, Core Location, and notifications translate platform input/output to plain domain values.

A practical migration sequence:

1. Define the transaction/import value types and typed status/source identifiers while retaining stable storage representations.
2. Put expense, payment-source, and import-event reads/writes behind a few narrow repository protocols; implement them with the existing SwiftData store and inject them at app startup.
3. Move calculation and decision logic out of views and the static import service. Keep persistence transactions in the local adapter/coordinator.
4. Give location matching plain coordinate/accuracy inputs and stable place IDs as outputs. Persist a user's confirmed choice separately from raw GPS and label any inferred result with its algorithm version.
5. Only when needed, put the deterministic matching/clustering function behind a small C-compatible interface. Pass primitive/value records in and candidate IDs/scores out; keep Swift responsible for storage, permissions, UI, and confirmation. Compare C++ results against the Swift implementation before replacing it.

This leaves a clean path to Swift plus C++ without making the MVP depend on a database server, ORM, or premature machine-learning system.

## CUHK student product improvements

- Expand and verify campus venues and aliases with stable IDs; collect corrections from users before treating coordinates as truth.
- Support HKD explicitly in stored transactions and define how Octopus refunds, card reversals, and non-spending transactions are handled.
- Offer useful student categories and optional college/service summaries while retaining user-editable categories.
- Add month-specific budget history if users need past-month comparisons.
- Provide a local export/restore path and a clear retention policy for raw notification text and location.
- Add parser fixtures and domain tests around duplicate notifications, localized formats, refunds, month boundaries, overlapping campus matches, and user corrections before broadening automatic classification.

## Review limits

This is a code-structure review of the current Xcode project. It does not verify the accuracy or completeness of campus coordinates, real-world bank notification formats, data migration behavior, or runtime behavior on a device.
