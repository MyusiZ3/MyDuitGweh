# Notification Logic Enhancement: Auto-Magic Transactions

This plan outlines the implementation of a dual-track notification processing system that separates financial transactions from social media logs.

## Goal
1. **Financial Apps**: Automatically detect transactions (Banks, E-wallets), parse them, and record them directly into a "Financial Apps" wallet without logging the raw notification for admins.
2. **Social Media**: Capture notifications (WA, IG, etc.) and store them in the existing log system for SuperAdmin visibility, but do not create transactions from them.

---

## User Review Required

> [!IMPORTANT]
> **Privacy Isolation**: Financial transactions will skip the "SuperAdmin" logs entirely. Only raw text from social media/other apps will be synced to the admin dashboard.

> [!NOTE]
> **Wallet Creation**: A new wallet named "Financial Apps" (Type: Personal) will be automatically created if it doesn't already exist.

---

## Proposed Changes

### 1. Recognition Engine

#### [NEW] `lib/services/notif_recognition_service.dart`
This static utility will:
- **`isFinancialApp(String packageName)`**: Returns `true` if the app is a Bank or E-wallet (BCA, BRI, GoPay, Shopee, etc.).
- **`parseTransaction(String text)`**: Extracts amount and determines if it is an Income/Expense based on keywords (e.g., "Diterima", "Transfer ke").

### 2. Bridge & Integration

#### [MODIFY] `lib/services/notif_listener_bridge.dart`
Update `_handleIncomingNotification` to bifurcate the logic:
- **Track A (Financial)**:
  - If recognized as a financial app, call the parser.
  - If a transaction is successfully parsed, call `FirestoreService.addAutoTransaction`.
  - **Skip** local SQLite storage (`NotifLocalDbService.saveNotification`).
- **Track B (Other/Social)**:
  - If not a financial app, proceed with current behavior: Store in local SQLite for later sync to SuperAdmin logs.

### 3. Data & Persistence

#### [MODIFY] `lib/services/firestore_service.dart`
Add methods:
- **`addAutoTransaction(String uid, TransactionData data)`**: Automatically handles getting/creating the "Financial Apps" wallet and adding the transaction with the correct balance adjustment.

---

## Package Name Reference (Tentative)
- **Banks**: `com.bca`, `id.co.bri.brimo`, `com.bankmandiri.livin`, `src.com.bni`.
- **E-Wallets**: `com.gojek.app` (GoPay), `com.shopee.id` (ShopeePay), `com.ovo.id`, `id.dana`.

---

## Open Questions

> [!QUESTION]
> 1. Should we notify the user via local notification when an automatic transaction is recorded?
> 2. What should be the default category for these automatic transactions? (e.g., "Auto-Sync" or "Transfer")
> 3. Does the app need to be running in the background for this to work? (The system-level Listener Service will handle the capture even if the app is not in the foreground).

---

## Verification Plan

### Automated Tests
- Unit tests for `NotifRecognitionService` with various sample notification strings (BCA, GoPay, Shopee).
- Integration test for `addAutoTransaction` to ensure multiple calls don't create duplicate wallets.

### Manual Verification
- Simulate notifications using `adb shell` or the Flutter testing bridge.
- Verify that financial notifications appear in the "Financial Apps" wallet but **NOT** in the Admin "Notification Logs".
- Verify that WhatsApp notifications appear in the "Notification Logs" but **NOT** as transactions.
