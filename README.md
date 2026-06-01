# Duitku — Expense Tracker

[![Live demo](https://img.shields.io/badge/Live%20demo-Open-2BB673?style=for-the-badge)](https://sultanzhalifa.github.io/Duitku/)
[![Deploy web demo](https://github.com/SultanZhalifa/Duitku/actions/workflows/deploy-web.yml/badge.svg)](https://github.com/SultanZhalifa/Duitku/actions/workflows/deploy-web.yml)

**Live demo:** https://sultanzhalifa.github.io/Duitku/

> The web demo runs the same code as the mobile app. Native-only features
> (biometric lock and local notifications) are automatically hidden in the
> browser, where they aren't supported.

A clean, **offline-first** personal finance app built with **Flutter** and
**Material 3**. Track income, expenses, and transfers across multiple wallets
and currencies; set budgets; automate recurring transactions; understand your
spending with charts and insights; and keep everything private and backed up —
all on-device, with no account or internet required.

> Built as a portfolio project to demonstrate end-to-end Flutter app
> development: multi-provider state management, a non-trivial domain model
> (wallets, currencies, transfers, recurring rules), local persistence, data
> visualisation, native platform integration (notifications and biometrics),
> two-way backup, and automated tests.

Every figure in the app is computed from real, user-entered data. There is no
seeded, demo, or placeholder content — the app opens to a clean empty state and
fills in as you use it. Native-only features detect platform support at runtime
and are hidden where unavailable, rather than faking behaviour.

---

## Features

### Transactions and wallets
- Add, **edit**, and delete income or expense transactions, with search and
  category/type filters.
- **Multiple wallets** (cash, bank, e-wallet) each in their own **currency**,
  with user-defined exchange rates to a configurable base currency.
- **Transfers between wallets**, recorded as two linked legs so balances stay
  correct and transfers are excluded from spending totals.
- Wallet balances are always **derived from transactions**, so they can never
  drift out of sync.

### Recurring transactions
- Define rules (salary, subscriptions, bills) with a daily / weekly / monthly
  cadence.
- On launch the app **catches up** any occurrences that came due while away,
  generating real, editable transactions — never duplicating one.
- Pause or delete rules at any time.

### Insights, statistics and budgets
- Monthly balance, income, and expense summary on a gradient hero card.
- **Smart insights** drawn only from real data (top category, month-over-month
  change, average daily spend).
- Interactive **donut chart** of spending by category and a 6-month **trend
  line chart**, plus busiest day and highest single expense.
- Optional **monthly budget per category** with progress bars and over-budget
  warnings.

### Privacy, backup and reminders
- Optional **biometric / device-passcode app lock** (native; `local_auth`).
- **Recurring reminders** via local notifications (native;
  `flutter_local_notifications`).
- Full **JSON backup and restore** (versioned schema, validated on import) plus
  read-only **CSV export**, both shared via the system share sheet.
- Animated **first-run onboarding**.

### Design
- A **warm, eye-friendly** colour palette (terracotta, amber, olive, warm sand)
  designed to reduce glare and read comfortably in light and dark themes.
- Material 3 throughout, with rounded surfaces and subtle tab transitions.

---

## Tech and architecture

| Concern             | Choice                                                                 |
| ------------------- | ---------------------------------------------------------------------- |
| Framework           | Flutter (Material 3, `useMaterial3`)                                   |
| State management    | [`provider`](https://pub.dev/packages/provider) + `ChangeNotifier`     |
| Local persistence   | [`shared_preferences`](https://pub.dev/packages/shared_preferences)    |
| Charts              | [`fl_chart`](https://pub.dev/packages/fl_chart)                        |
| Notifications       | [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) + [`timezone`](https://pub.dev/packages/timezone) |
| Biometrics          | [`local_auth`](https://pub.dev/packages/local_auth)                    |
| Export / backup     | [`share_plus`](https://pub.dev/packages/share_plus) + [`path_provider`](https://pub.dev/packages/path_provider) |
| Formatting / IDs    | [`intl`](https://pub.dev/packages/intl), [`uuid`](https://pub.dev/packages/uuid) |

The code is organised by responsibility:

```
lib/
├── main.dart                 # Root: providers + startup orchestration (boot, gating)
├── models/                   # Transaction, Category, Wallet, Currency, RecurringRule, Insight
├── providers/                # Expense, Wallet, Budget, Recurring, Settings (state + persistence)
├── services/                 # Notification, Auth, Backup, Export (platform/IO boundaries)
├── screens/                  # Shell, Home, Stats, Wallets, Budgets, More, Recurring,
│                             #   Settings, Onboarding, LockGate, Add/Transfer sheets
├── widgets/                  # Reusable UI: balance card, charts, tiles, filters, insights
├── theme/                    # Centralised warm Material 3 light/dark theme
└── utils/                    # Formatters (currency, dates)
```

### Design notes

- **Providers are the single source of truth.** The UI reads derived values and
  never mutates state directly, which keeps data flow predictable and the
  providers fully unit-testable.
- **No fabricated data.** Insights appear only when the data supports them; a
  month-over-month comparison is omitted when there's no previous-month data.
- **Money model.** `Transaction` is immutable with `copyWith`/`toJson`. Amounts
  are stored positive; the sign comes from the type. A transfer is two linked
  legs sharing a `transferId`, so all existing totals/charts stay correct and
  deleting either leg removes both.
- **Recurring engine.** `RecurringProvider.catchUp` walks each rule's schedule
  forward from `nextDue` to today, materialising one real transaction per missed
  occurrence and advancing `nextDue`, so nothing is generated twice.
- **Platform boundaries are honest.** `NotificationService` and `AuthService`
  expose real capability checks (`isSupported` / `canCheck`); on the web they
  are genuine no-ops and the UI hides the toggles.
- **Backups are versioned.** The JSON document carries a `schemaVersion`;
  restore validates the document and rejects unknown/corrupt input with a clear
  message instead of corrupting state. Services raise typed exceptions
  (`BackupException`, `ExportException`).

---

## Getting started

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run on a connected device, emulator, or browser
flutter run                 # Android device/emulator (full feature set)
flutter run -d chrome       # Web (notifications/biometrics auto-hidden)
```

Requires the Flutter SDK (Dart 3.12+). Android: `minSdk 23`, `compileSdk 36`.

## Quality

```bash
flutter analyze     # 0 issues
flutter test        # 17 tests: provider logic, transfers, recurring, backup round-trip, widgets
flutter build apk   # verifies the full native Android build
flutter build web   # verifies the web build
```

The test suite covers transaction maths, transfers (linked legs and paired
deletion), wallet balances and currency conversion, recurring catch-up
(including idempotency), backup export/restore round-trips and corrupt-input
rejection, and widget tests for onboarding and the home shell.

---

## Possible next steps

- Sync backups to cloud storage.
- Per-wallet and per-budget analytics over time.
- Live exchange-rate fetching (currently user-entered, fully offline).
- Migrate persistence to `sqflite` / `drift` for richer querying.

---

*Built with Flutter. Designed to be small, readable, and genuinely useful.*
