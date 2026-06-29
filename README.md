<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:1a3a6b,50:2563eb,100:38bdf8&height=220&section=header&text=NATU-Students&fontSize=72&fontColor=ffffff&fontAlignY=38&desc=🎓%20The%20Smart%20Social-Academic%20Platform&descAlignY=58&descSize=20&animation=fadeIn" width="100%"/>

<br/>

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=22&pause=1000&color=2563EB&center=true&vCenter=true&width=700&lines=Real-Time+Messaging+%F0%9F%92%AC;Student+Communities+%F0%9F%8F%98%EF%B8%8F;AI+Academic+Assistant+%F0%9F%A4%96;LinkedIn-Style+Networking+%F0%9F%A4%9D;Biometric+Login+%F0%9F%94%92;Full+Arabic+%26+English+Support+%F0%9F%8C%90" alt="Typing SVG" />

<br/><br/>

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![License: MIT](https://img.shields.io/badge/MIT-A855F7?style=for-the-badge&logo=opensourceinitiative&logoColor=white)](LICENSE)

</div>

---

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:1a3a6b,100:2563eb&height=3&section=header" width="100%"/>

## 📸 App Screenshots

<div align="center">

<br/>

### 🔐 Authentication — Sign In · Register · Forgot Password

<img src="assets/Photo github/1.jpeg" width="92%" alt="Auth Screens"/>

<br/><br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:38bdf8,100:2563eb&height=2" width="60%"/>

<br/><br/>

### 🏠 Home Feed &nbsp;·&nbsp; 👥 Community &nbsp;·&nbsp; 🤖 TechBot AI &nbsp;·&nbsp; 💬 Messages

<img src="assets/Photo github/2.jpeg" width="92%" alt="Home, Community, TechBot, Messages"/>

<br/><br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:38bdf8,100:2563eb&height=2" width="60%"/>

<br/><br/>

### 📄 Certificates &nbsp;·&nbsp; 📋 My CV &nbsp;·&nbsp; 🛡️ Admin Dashboard &nbsp;·&nbsp; 🔒 Privacy & Security

<img src="assets/Photo github/3.jpeg" width="92%" alt="Certificates, CV, Admin, Privacy"/>

<br/><br/>

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:38bdf8,100:2563eb&height=2" width="60%"/>

<br/><br/>

### 👤 Profile &nbsp;·&nbsp; ☰ Menu &nbsp;·&nbsp; 🤝 My Network

<img src="assets/Photo github/4.jpeg" width="92%" alt="Profile, Menu, Network"/>

<br/>

</div>

---

## ✨ Features at a Glance

<div align="center">

|  | Feature | What it does |
|:---:|:---|:---|
| 💬 | **Real-Time Messaging** | 1-to-1 & Group chats · Reply · Forward · Delete for everyone · Emoji reactions · Voice messages |
| 🤖 | **TechBot AI** | LLM-powered academic assistant with floating Peek UI & one-tap suggested questions |
| 🏘️ | **Student Communities** | Admin-approved posts · Multi-level threaded comments · QR invite links · Deep link navigation |
| 🤝 | **Academic Networking** | LinkedIn-style Connections · Follow system · People you may know suggestions |
| 🔕 | **Smart Mute System** | Server-side FCM suppression + client-side foreground suppression — true silence |
| 📌 | **Chat Management** | Pin · Archive · Mute conversations — all synced per-user in Firestore |
| 🔒 | **Security** | Firebase App Check · Biometric Login · Firestore Rules · Storage Rules |
| 📚 | **Academic Tools** | University ID Card · Lecture Schedule · CV & Certificate PDF management |
| 🌙 | **Theming & i18n** | Persistent Dark/Light mode · Full Arabic (RTL) & English (LTR) support |

</div>

---

## 🛠 Tech Stack

<div align="center">

| Layer | Technology |
|:---|:---|
| 📱 **UI Framework** | Flutter · Dart |
| 🔄 **State — Global** | Provider — Auth, Theme, Locale, Posts |
| ⚡ **State — Features** | BLoC / Cubit — Chat, Community, Connections |
| 🗄️ **Database** | Cloud Firestore (real-time NoSQL) |
| 🔐 **Authentication** | Firebase Auth |
| 🗂️ **File Storage** | Firebase Storage — media, voice notes, PDFs |
| 🔔 **Push Notifications** | Firebase Cloud Messaging (FCM) |
| ☁️ **Server Logic** | Firebase Cloud Functions v2 (Node.js · Serverless) |
| 🛡️ **Security** | Firebase App Check · Biometrics · SSL Pinning |
| 🟢 **Secondary Backend** | Supabase |

</div>

---

## 🏗 Architecture

<div align="center">

```
┌────────────────────────────────────────────┐
│          Presentation Layer                │
│   BLoC · Cubit · Provider · Widgets        │
├────────────────────────────────────────────┤
│            Domain Layer                    │
│   Entities · Repository Interfaces         │
├────────────────────────────────────────────┤
│             Data Layer                     │
│   Models (JSON ↔ Dart) · Repositories      │
└──────────────────┬─────────────────────────┘
                   │
     ┌─────────────▼──────────────┐
     │  Firebase · Supabase · APIs │
     └────────────────────────────┘
```

</div>

**Feature-First Structure** — every feature lives in `lib/features/{name}/` with its own `data/` · `domain/` · `presentation/` layers, keeping changes isolated and the codebase scalable.

---

## 👨‍💻 Author

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:1a3a6b,50:2563eb,100:38bdf8&height=120&section=footer&text=Gadallah%20Mohamed&fontSize=32&fontColor=ffffff&fontAlignY=65&desc=Software%20Engineer%20%C2%B7%20Flutter%20Developer&descAlignY=85&descSize=14" width="100%"/>

[![GitHub](https://img.shields.io/badge/GitHub-GadallahMohamed41-181717?style=for-the-badge&logo=github)](https://github.com/GadallahMohamed41)
&nbsp;
[![License: MIT](https://img.shields.io/badge/License-MIT-A855F7?style=for-the-badge)](LICENSE)

</div>
