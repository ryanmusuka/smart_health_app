# SmartHealth 🩺📱

> **Empowering Patients. Streamlining Medical Aid.**

SmartHealth is a high-performance prototype mobile application designed for a local medical aid company. Designed to modernize client services, it bridges the gap between medical institutions and patient transparency — a centralized, user-friendly hub where members can manage their health profiles, securely submit medical claims, and track their benefits in real-time, without ever needing to call a support desk.

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | [Flutter](https://flutter.dev/) — natively compiled, cross-platform mobile |
| Language | [Dart](https://dart.dev/) — type-safe, optimized for fast UI rendering |
| Backend & Database | [Supabase](https://supabase.com/) — PostgreSQL + Auth + Storage |
| UI & Animations | Custom Material Design, Shimmer (skeleton loaders), PageRouteBuilders |
| Typography | [Google Fonts — Outfit](https://fonts.google.com/specimen/Outfit) |

---

## ✨ Features

### 1. 🔐 Secure Authentication & Onboarding
A robust login and registration system powered by Supabase Auth, including email/password authentication, custom user data capture, and an integrated "Forgot Password" flow.

### 2. 🏥 Personal Medical Dashboard
A dynamic home screen displaying the user's **Premium Membership Card** — their unique medical aid number alongside recent claim activity.

### 3. 📊 Real-Time Claim Tracking
A detailed history module for tracking monthly claims, with a clear breakdown per claim:
- Total Billed
- Covered by Aid
- Patient Shortfall

Claims are color-coded by status: `Pending` · `Approved` · `Rejected`

### 4. 📋 Digital Claim Submission
A streamlined submission portal where users can input provider details, describe treatments, and upload supporting documents (receipts, doctor's notes) directly to secure cloud storage — all from their phone.

### 5. 🔔 Smart Notification System
An in-app notification center that alerts users to claim status updates, with a visual unread indicator on the dashboard so no important update is ever missed.

### 6. 🔔 Profile Details
A display of their general information and critical medical information (blood type, allergies, chronic conditions, and current medications), as well as an emergency contact information.

---

## 🔑 Demo Credentials

| Field | Value |
|---|---|
| Email | admin@smarthealth.com |
| Password | pass1234 |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- A [Supabase](https://supabase.com/) project with the required tables and RLS policies configured
- An Android or iOS device / emulator

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/smarthealth.git
cd smarthealth

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Environment Configuration

Create a `.env` file or update `lib/constants.dart` with your Supabase credentials:

```dart
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```
---

## 🗄️ Database Schema

The app relies on the following core Supabase tables:

- `profiles` — user demographic and medical info
- `claims` — submitted claims with status tracking
- `notifications` — in-app alerts linked to claim events
- `documents` — references to files stored in Supabase Storage

---

## 🔒 Security

Security is the foundation, not a feature. SmartHealth is built around HIPAA/POPIA principles:

- **Row-Level Security (RLS):** Strict PostgreSQL policies ensure users can only read, insert, or update their own data.
- **Secure Storage:** Claim documents are stored in Supabase Storage buckets with access controls — only the authenticated user and the admin portal can view them.
- **Ghost User Prevention:** The `profiles` table creation is decoupled from strict email verification to prevent orphaned database records and maintain database integrity.

---

## 🧠 Engineering Notes & Lessons

### Perceived Performance
Standard circular loaders were replaced with **Shimmer skeleton screens** for the dashboard. Since profile data, claims, and notifications are fetched simultaneously, skeleton loaders make the app feel significantly faster and more responsive.

### State Management
Rather than introducing complex state libraries (Riverpod, Bloc) for a prototype, the app uses strategic `Navigator.push` await calls. The dashboard re-fetches the latest Supabase data on return from any screen, ensuring data accuracy with minimal overhead.

### Enforcing Relational Data Integrity (Cascading Deletes)
When designing the Supabase PostgreSQL schema, I quickly realized the importance of the ON DELETE CASCADE constraint. Initially, deleting a test user left orphaned claims, notifications, and medical profiles cluttering the database. Implementing strict foreign key constraints ensured that when a profile is removed, all associated sensitive data is automatically and cleanly scrubbed, which is vital for data privacy compliance.

### The "Ghost User" Authentication Trap
While testing the registration flow with fake emails, I ran into Supabase's strict email verification requirements, which resulted in database triggers firing for users who couldn't actually log in. Navigating this taught me the importance of aligning the Auth Provider settings (toggling off forced email confirmation during development) with the database's automated trigger functions to maintain a smooth development lifecycle.

---

## 📦 Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^x.x.x
  shimmer: ^x.x.x
  google_fonts: ^x.x.x
```

> Replace `^x.x.x` with the latest compatible versions from [pub.dev](https://pub.dev).

---

## 🛣️ Roadmap

- [ ] Biometric authentication (Face ID / Fingerprint)
- [ ] Push notifications via Supabase Edge Functions
- [ ] Admin portal for claim review and approval
- [ ] PDF export of claim history
- [ ] Multi-language support

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

## 🙋

Built as a prototype to modernize medical aid services.  
Contributions, feedback, and issues are welcome.
