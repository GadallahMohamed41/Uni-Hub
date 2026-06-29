<div align="center">

<img src="lib/assets/images/logo-removebg.png" width="120" alt="NATU-Students Logo"/>

# NATU-Students — Uni-Hub

### 🎓 The Smart Social-Academic Platform for University Students

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-Framework-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-Language-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Supabase](https://img.shields.io/badge/Supabase-Storage-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-A855F7?style=for-the-badge)](LICENSE)

<br/>

> **NATU-Students** is a full-featured, cross-platform mobile application built with **Flutter & Firebase**.  
> It unifies real-time messaging, academic networking, AI assistance, student communities, and admin tools  
> into one sleek, beautiful experience — for the modern university student.

</div>

---

## 📸 App Screenshots

<div align="center">

### 🔐 Authentication — Sign In · Register · Reset Password
<img src="assets/Photo github/1.jpeg" width="90%" alt="Auth Screens — Sign In, Register, Forgot Password"/>

<br/><br/>

### 🏠 Home Feed · 👥 Community · 🤖 TechBot AI · 💬 Messages
<img src="assets/Photo github/2.jpeg" width="90%" alt="Home, Community, AI Assistant, Chats"/>

<br/><br/>

### 📄 Certificates · 📋 CV · 🛡️ Admin Dashboard · 🔒 Privacy & Security
<img src="assets/Photo github/3.jpeg" width="90%" alt="Certificates, CV, Admin Panel, Privacy"/>

<br/><br/>

### 👤 Profile · ☰ Menu · 🤝 My Network
<img src="assets/Photo github/4.jpeg" width="90%" alt="Profile, Side Menu, Network Connections"/>

</div>

---

## ✨ Key Features

<table>
<tr>
<td width="50%" valign="top">

### 💬 Advanced Messaging
- Real-time **1-to-1** and **Group** chats via Firestore Streams
- **Reply**, **Forward**, and **Delete** messages (for everyone within 10 min)
- **Emoji Reactions** on any message
- **Voice Messages** — record, upload, playback with waveform UI
- **@Mentions** with live suggestion overlay & high-priority FCM alerts
- **Mute / Archive** conversations at server + client level
- **Pin** chats to the top for quick access

</td>
<td width="50%" valign="top">

### 🏘️ Student Communities
- Topic-based community groups with **Admin Approval** for posts
- **Threaded multi-level comments** using `parentCommentId`
- **Soft-delete** comments preserving reply structure
- **QR Code** invitations and **Deep Link** navigation
- Collapsible community cards with **Sticky Header** layout
- Pending join requests visible to admins even without description

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🤝 Academic Networking
- **LinkedIn-style** Connections — send, accept, ignore requests
- **Follow / Unfollow** system with live counters
- **"People You May Know"** suggestions
- Connection state reflected on every profile card in real time
- Sub-collections: `followers`, `following`, `connections`

</td>
<td width="50%" valign="top">

### 🤖 AI Academic Assistant (TechBot)
- Integrated **LLM Backend** for academic Q&A
- Floating action button + **Peek overlay slider**
- Suggested questions with one-tap shortcuts
- Fully RTL-compatible Arabic interface

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🔒 Security & Privacy
- **Firebase App Check** (Play Integrity + App Attest)
- **Biometric Login** — Fingerprint / Face ID via `local_auth`
- **SSL Certificate Pinning** for all API calls
- **Firestore Security Rules** — per-user data isolation
- **Storage Rules** — path-based `media/{userId}/...` enforcement

</td>
<td width="50%" valign="top">

### 📚 Academic Utilities
- Digital **University ID Card** with QR code
- **Lecture Schedule** viewer per department & level
- **CV Upload** (PDF) with Firebase Storage
- **Certificate Management** — upload, view, delete multiple PDFs
- Persistent **Dark / Light Mode** theming
- Full **Arabic & English** localization (RTL / LTR)

</td>
</tr>
</table>

---

## 🛠 Tech Stack

| Layer | Technology | Purpose |
|:---|:---|:---|
| **UI Framework** | Flutter + Dart | Cross-platform (Android, iOS, Web) |
| **State — Global** | Provider | Auth, Theme, Locale, Posts |
| **State — Features** | BLoC / Cubit | Chat, Community, Connections |
| **Database** | Cloud Firestore | Real-time NoSQL data sync |
| **Authentication** | Firebase Auth | Secure user login & identity |
| **File Storage** | Firebase Storage | Media, voice notes, PDFs |
| **Push Notifications** | Firebase Cloud Messaging (FCM) | Foreground + Background alerts |
| **Server Logic** | Firebase Cloud Functions (Node.js) | Serverless triggers & notification dispatch |
| **Security** | Firebase App Check | API protection from unauthorized clients |
| **Secondary Backend** | Supabase | Auxiliary storage & auth |
| **Local Storage** | SharedPreferences + SecureStorage | Theme persistence & sensitive data |

---

## 🏗 Architecture — Clean Architecture × Feature-First

```
lib/
├── core/
│   ├── config/            # SupabaseConfig, environment setups
│   ├── layout/            # Main bottom-navigation wrapper
│   ├── services/          # PushNotifications, DeepLink, Storage, Biometrics
│   ├── theme/             # AppTheme, ThemeProvider, ThemeRepository
│   └── providers/         # LocaleProvider
│
├── features/              # Feature-first modules (Clean Architecture)
│   ├── admin/             # Admin panel & content moderation dashboard
│   ├── assistant/         # TechBot AI — AiService, Peek UI
│   ├── auth/              # Sign In, Register, Forgot Password
│   ├── chat/              # Real-time messaging (BLoC)
│   │   ├── data/          # ConversationModel, MessageModel, Repositories Impl
│   │   ├── domain/        # Entities, Repository Interfaces
│   │   └── presentation/  # ConversationsBloc, MessagesBloc, Screens, Widgets
│   ├── community/         # Student groups & feeds (BLoC)
│   ├── connections/       # Follow & connection graph (BLoC)
│   ├── home/              # University feed (Provider + PostsProvider)
│   ├── profile/           # Student profile, CV, Certificates
│   └── splash/            # Splash & boot screen
│
├── models/                # Shared UserModel with counters
└── main.dart              # AppBootstrapper — Firebase init, FCM, Supabase
```

### Architecture Layers
```
┌──────────────────────────────────┐
│   Presentation Layer             │  ← BLoC / Provider / Widgets / Screens
├──────────────────────────────────┤
│   Domain Layer                   │  ← Entities + Repository Interfaces (pure Dart)
├──────────────────────────────────┤
│   Data Layer                     │  ← Models (JSON ↔ Dart) + Repository Implementations
└──────────────────────────────────┘
         ↑ talks to ↓
┌──────────────────────────────────┐
│   Firebase / Supabase / APIs     │  ← Firestore, Storage, FCM, Cloud Functions
└──────────────────────────────────┘
```

---

## 🔥 Advanced Technical Highlights

### ⚡ Real-Time Notifications Pipeline
1. User action writes to `notifications/{id}` in Firestore
2. Cloud Function `onDocumentCreated` triggers (region: `europe-west1`)
3. Function checks `muteUntil` and `archivedBy` fields → skips if muted
4. Sends **data-only high-priority FCM** payload to target device
5. App foreground: local notification shown via `flutter_local_notifications`
6. App background/killed: `@pragma('vm:entry-point')` background isolate handles it

### 🔁 Exponential Backoff for Firestore (Deep Link Resilience)
```dart
// DeepLinkService._retry() — handles transient 'unavailable' errors
Future<T> _retry<T>(Future<T> Function() op, {int maxAttempts = 3}) async {
  int delay = 500;
  for (int i = 1; i <= maxAttempts; i++) {
    try { return await op(); }
    on FirebaseException catch (e) {
      if (i == maxAttempts || e.code != 'unavailable') rethrow;
      await Future.delayed(Duration(milliseconds: delay));
      delay *= 2; // 500ms → 1s → 2s
    }
  }
  throw Exception('Retry limit exceeded');
}
```

### 🔕 Two-Tier Mute System
| Tier | Where | Mechanism |
|:---|:---|:---|
| **Server-side** | Cloud Function | Checks `muteUntil` timestamp before sending FCM → silent if muted |
| **Client-side** | `PushNotificationsService` | Suppresses local notification + auto-marks as read if muted/archived |

---

## ⚙️ Getting Started

### Prerequisites
- Flutter SDK ≥ 3.3
- Node.js (for Cloud Functions deployment)
- A Firebase project with Firestore, Auth, Storage, FCM, App Check enabled

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/GadallahMohamed41/Project_v2.git
cd Project_v2

# 2. Install Flutter dependencies
flutter pub get

# 3. Deploy Cloud Functions (requires Firebase CLI)
cd functions && npm install
firebase deploy --only functions

# 4. Run the app
flutter run
```

> [!IMPORTANT]
> Place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
> in the appropriate platform directories before running.

---

## 👨‍💻 Author

<div align="center">

**Gadallah Mohamed**  
*Software Engineer · Flutter Developer · Problem Solver*

[![GitHub](https://img.shields.io/badge/GitHub-GadallahMohamed41-181717?style=for-the-badge&logo=github)](https://github.com/GadallahMohamed41)

<br/>

*This project is licensed under the **MIT License**.*

</div>
