# TARUMT KL Campus Lost Item Tracker

A Flutter mobile application for reporting and tracking lost and found items on campus. Built for Tunku Abdul Rahman University of Management and Technology (TARUMT) KL Campus, this app helps students and staff report lost items, browse found items, and claim their belongings through an intuitive interface backed by Firebase.

---

## Features

### Regular Users

- **Report Lost Items** — Submit detailed lost item reports with photos, category, description, location (map picker), and date/time
- **Report Found Items** — Report items you've found with similar details and handover location
- **Draft Reports** — Save in-progress reports and complete them later
- **Search & Filter** — Find items by category, keywords, date range, and location
- **Campus Map** — Interactive map showing lost/found item locations (powered by FlutterMap)
- **Claim Lost Items** — Claim a found item that matches your lost report (with proof verification)
- **Report History** — View all your lost, found, and claim reports in one place
- **Smart Matching** — Automatic matching of lost and found reports based on category, name, description, location, and time (70%+ match triggers notifications)
- **QR Code & Barcode** — Generate your user QR code for quick identification; scan QR codes to view user or report details
- **Rewards & Vouchers** — Earn reward points for successful claims; redeem vouchers
- **Analytical Report** — Personal analytics: reports over time, category breakdown, success rate, reward points, location map, claim outcomes; export as PDF or share
- **Notifications** — In-app notifications for matches, claim updates, and activity
- **Help & Feedback** — Submit feedback and get help

### Admins

- **Item Management** — View, manage, and moderate lost and found reports
- **Claim Verification** — Verify and approve/reject claim submissions
- **Category Management** — Manage item categories used in reports
- **Location Management** — Manage campus locations for reporting
- **Reward Management** — Configure rewards and voucher rules
- **Reports & Analytics** — System-wide analytics and dashboards
- **Export Report** — Export data (e.g. CSV) for external use

---

## Tech Stack

| Area | Technology |
|------|------------|
| **Framework** | Flutter (SDK ^3.7.2) |
| **Backend** | Firebase (Auth, Cloud Firestore) |
| **Maps** | flutter_map, latlong2 |
| **Charts & Analytics** | fl_chart |
| **QR / Barcode** | qr_flutter, mobile_scanner, google_mlkit_barcode_scanning |
| **PDF & Print** | pdf, printing |
| **Other** | geolocator, image_picker, share_plus, url_launcher, intl |

---

## Prerequisites

- **Flutter SDK** 3.7.2 or higher  
  [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Firebase project** with:
    - Authentication (Email/Password)
    - Cloud Firestore
- **FlutterFire CLI** (for Firebase config generation)

---

## Setup

### 1. Clone the repository

```bash
git clone <repository-url>
cd lost_item_tracker
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Firebase configuration

The app uses `lib/firebase_options.dart` for Firebase configuration. To set up or update it:

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Log in to Firebase and select your project:
   ```bash
   firebase login
   flutterfire configure
   ```

3. For **Android**, ensure `google-services.json` is present at `android/app/google-services.json`. FlutterFire typically places it there; otherwise, download it from the [Firebase Console](https://console.firebase.google.com) and add it manually.

4. For **iOS**, ensure the `GoogleService-Info.plist` is added to your Xcode project (usually via FlutterFire or manual addition).

### 4. Firestore rules and indexes

Configure Firestore security rules and indexes as required by the app. Refer to your Firebase project setup for production rules.

---

## Running the app

```bash
flutter run
```

Choose your target device (Android, iOS, web, Windows, macOS) when prompted. For Android emulator or device:

```bash
flutter run -d android
```

---

## Project structure

```
lib/
├── main.dart                 # App entry point, Firebase init
├── firebase_options.dart     # Generated Firebase config (do not commit secrets)
├── role_selection_page.dart  # User vs Admin role selection
├── user/
│   ├── user_home_page.dart           # User dashboard & feed
│   ├── user_login_page.dart
│   ├── user_registration_page.dart
│   ├── user_profile_page.dart
│   ├── report_type_selection_page.dart
│   ├── lost_item_reporting_page.dart
│   ├── found_item_reporting_page.dart
│   ├── draft_report_listing_page.dart
│   ├── lost_item_report.dart         # Lost item detail & claim CTA
│   ├── found_item_report.dart        # Found item detail
│   ├── lost_item_claim.dart          # Claim flow
│   ├── lost_item_claiming_page.dart
│   ├── search_and_filter_page.dart
│   ├── campus_map_page.dart
│   ├── report_history_page.dart
│   ├── user_notification_page.dart
│   ├── user_reward_page.dart
│   ├── user_voucher_page.dart
│   ├── user_analytical_report_page.dart
│   ├── qr_code_page.dart
│   ├── help_and_feedback_page.dart
│   ├── item_matching_service.dart    # Lost–found matching logic
│   └── analytics/
│       ├── user_analytics_model.dart
│       └── user_analytics_service.dart
└── admin/
    ├── admin_home_page.dart
    ├── admin_login_page.dart
    ├── admin_item_management_page.dart
    ├── admin_claim_verification_page.dart
    ├── admin_category_management_page.dart
    ├── admin_location_management_page.dart
    ├── admin_reward_management_page.dart
    ├── admin_reports_analytics_page.dart
    ├── admin_report_export_page.dart
    └── admin_profile_page.dart
```

---

## Supported platforms

- **Android** (minSdk 23)
- **iOS**
- **Web**
- **Windows**
- **macOS**  
  Linux is not supported by the default Firebase configuration.

---

## Configuration notes

- **Matching thresholds** — Lost–found matching is configured in `lib/user/item_matching_service.dart` (e.g. 70% for notifications, 50% minimum).
- **Firebase project** — The app is configured for project `finalyearproject-7b5bb`. Use `flutterfire configure` to switch or create a new project.

---

## License

This project is for educational use. Check with your institution for licensing terms.
