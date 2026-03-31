# Food Loop

A Flutter-based peer-to-peer campus food sharing marketplace, inspired by the product requirements in `food-loop-prd.md`.

## Project Overview

Food Loop connects university students to share, buy, and sell surplus food while reducing campus food waste and improving food security.

Core goals:

- Enable verified campus-only accounts (.ac.ug or institution email domain).
- Enable paid and free food listing flows with expiry and pickup management.
- Provide in-app chat, transactions, ratings, and reputation.
- Leverage Firebase for auth, Firestore, storage, functions, and FCM.

## MVP Scope (Phase 1)

1. User signup + university email and phone verification
2. Create/edit/delete food listings (active, sold, expired states)
3. Home feed with deals, categories, search, and infinite scroll
4. In-app messaging with transactional tracking
5. Mobile Money payments (MTN/Airtel via API) and cash option
6. Ratings & reviews, profiles, and trust badges

## Tech Stack

- Flutter (Dart)
- Firebase Auth, Firestore, Storage, Cloud Functions, FCM
- Google Maps SDK (location/pickup support)
- MTN MoMo and Airtel Money integration
- Crashlytics + analytics (user behavior and performance)

## Key Features

- Food listing details: photos, category, quantity, price/free, expiry, pickup time/location
- Validation: expiry in future, price multiples, max listing count, region geo-fence
- Real-time feed updates, pull-to-refresh, and 20 item paging
- Chat with listing cards, read receipt status, and deep links
- Push notifications: transactions, messages, expiry reminders
- Review system: food quality, reliability, anonymous option
- Moderation: reporting, profanity checks, co-account safeguards

## Project Structure

- `lib/` - Flutter app code, feature modules, core utilities
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` - platform folders
- `functions/` - Node.js Firebase Cloud Functions (API and backend rules)
- `test/` - widget and unit tests

## Setup

1. Install Flutter SDK (stable channel), Android SDK, Xcode (iOS), and required platform toolchains.
2. Run `flutter pub get`.
3. Configure Firebase (replace `google-services.json` / `GoogleService-Info.plist`).
4. `firebase emulators:start` (optional local backend testing).
5. `flutter run` to launch.

## Contributing

- Open issues for bugs or feature requests.
- Follow building conventions in `analysis_options.yaml` and `pubspec.yaml`.
- Add tests in `test/` and validate with `flutter test`.

## Roadmap

See `food-loop-prd.md` for detailed phases, features, and success metrics:

- Phase 1: Android MVP, core marketplace flows, payments, chat
- Phase 2: iOS, wallet, advanced filters, map view, localization
- Phase 3: scale, multi-campus, receipts, gamification

---

> Food Loop is built for MUST students to save money, reduce waste, and build food-sharing community trust.
