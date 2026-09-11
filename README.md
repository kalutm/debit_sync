# Debit Sync

![Debit Sync Logo](https://img.shields.io/badge/Debit-Sync-blue)

**Debit Sync** is a synchronized, serverless Flutter application designed to elegantly solve a common social problem: keeping track of who owes whom money. 

## 💡 The Problem
We've all been there—you cover lunch for a friend, someone borrows cash for a taxi, or you split a grocery bill. Over time, keeping track of these small debts becomes awkward and confusing. Text messages get lost, memory fades, and asking for your money back can feel uncomfortable. 

Debit Sync eliminates this friction by providing a **shared, synchronized ledger** between you and your friends. It uses a "Zero-Trust" model where every transaction (borrowing or paying back) must be explicitly accepted by the counterparty before it is permanently recorded in the ledger. This ensures that both parties are always on the same page, preserving friendships and financial clarity.

## ✨ Features
- **Synchronized Ledger:** View real-time balances with your friends. Know exactly how much you owe or are owed at a glance.
- **Zero-Trust Requests:** Create "Debit" requests when borrowing money, and "Payback" requests when settling up. Counterparties receive notifications and must accept the request for it to clear.
- **Smart Inbox & History:** Easily filter through pending requests in your Inbox and review settled transactions in your History.
- **Net Balances:** Automatically calculates mutual net balances so you can issue a single settlement to wipe the slate clean.
- **Push Notifications:** Stay updated with FCM-powered alerts for new requests and acceptances.

## 📱 Download the App
Want to try it out without building from source? You can download the latest Android APK directly from Google Drive:
[**Download Debit Sync for Android**](https://drive.google.com/file/d/1j2teCO78deMuhqjiLiCe95yzSzx9K1U4/view?usp=drive_link)

---

## 🛠️ Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
- Dart SDK (comes with Flutter)
- A connected device or emulator (Android/iOS)
- Firebase CLI (for backend services configuration if you plan to fork the project)

### Installation & Build Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/debit_sync.git
   cd debit_sync
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

*(Note: If you are forking this repository, you will need to configure your own Firebase project and replace the `google-services.json` and `GoogleService-Info.plist` files.)*

## 🔒 Security Architecture
Debit Sync is 100% serverless, leveraging Firebase Authentication and Cloud Firestore. It enforces strict Firestore Security Rules to guarantee that users can only read their own data and that transactions are only visible to the involved participants.

## 📄 License
This project is licensed under the MIT License.
