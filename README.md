# 🏭 MachAlert

> **Real-time machine fault reporting and maintenance monitoring using Flutter and Firebase.**

MachAlert is a mobile application designed to help manufacturing teams report machine faults immediately, monitor machine conditions, maintain fault history, and coordinate maintenance activities without waiting for end-of-shift review meetings.

---

## 📌 Problem Statement

A manufacturing company operates multiple production lines, but machine inspections and breakdown events are only captured during shift-end review meetings.

Because faults are not recorded and communicated immediately, recurring machine problems may go unnoticed until they cause:

- Unplanned machine downtime
- Repeated breakdowns
- Delayed maintenance
- Reduced production efficiency
- Missed production targets

The current process is largely **reactive** rather than proactive.

---

## 💡 Our Solution

MachAlert provides a mobile-based system where machine issues can be reported and monitored in real time.

Instead of waiting until the end of a shift, an operator can report a machine problem immediately through the app.

The reported data is stored using Firebase and can be viewed by the relevant users.

### Basic Workflow

```text
Machine Problem
      ↓
Operator notices fault
      ↓
Reports through MachAlert
      ↓
Fault stored in Firestore
      ↓
Manager / Technician sees update
      ↓
Maintenance action is taken
      ↓
Machine issue is resolved
```

---

## 🎯 Project Objectives

The main objectives of MachAlert are to:

- Enable immediate machine fault reporting
- Maintain digital machine fault history
- Reduce delay between fault detection and maintenance
- Provide real-time updates using Firebase
- Help managers monitor machine conditions
- Help technicians track maintenance work
- Provide a foundation for future recurring-fault detection and predictive maintenance

---

## 👥 User Roles

### 👷 Operator

Operators are responsible for using and inspecting machines.

They can:

- Login to the application
- View machines
- Report machine faults
- Enter fault severity
- Add fault descriptions
- Upload machine/fault images
- View submitted reports

### 👨‍🔧 Technician

Technicians handle machine maintenance.

They can:

- View reported faults
- View assigned maintenance tasks
- Update maintenance status
- Add repair notes
- Mark issues as resolved

### 👨‍💼 Manager

Managers monitor the overall production environment.

They can:

- View machines
- Monitor reported faults
- View machine condition/status
- Track maintenance activities
- Search and filter reports
- Monitor real-time updates

---

## ✨ Planned Features

### Authentication

- User Sign Up
- User Login
- User Logout
- Persistent Login
- Authentication State Handling
- Role-based application access

### Machine Management

- Machine List
- Machine Details
- Machine Status
- Machine Fault History

### Fault Reporting

- Select Machine
- Fault Type
- Severity
- Fault Description
- Image Upload
- Server Timestamp
- Real-time Fault Updates

### Maintenance

- Maintenance Task List
- Task Status
- Technician Assignment
- Maintenance Notes
- Resolved Fault Tracking

### Application Experience

- Splash Screen
- Bottom Navigation
- Form Validation
- Loading Indicators
- Error Handling
- SnackBars and Dialogs
- Search and Filtering

---

## 🚀 Future Scope

Once the basic Flutter + Firebase application is complete, MachAlert can be extended with:

- Machine Health Scores
- Recurring Fault Detection
- Automated Alerts
- Push Notifications
- Fault Analytics
- Downtime Analytics
- Predictive Maintenance
- Machine Learning
- IoT Sensor Integration
- Real-time temperature and vibration monitoring

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| Flutter | Mobile application development |
| Dart | Programming language |
| Firebase Authentication | User authentication |
| Cloud Firestore | Application database |
| Firebase Storage | Fault image/media storage |
| Firebase | Backend services |
| Git | Version control |
| GitHub | Collaboration and Pull Requests |
| Figma | UI/UX planning and mockups |

---

## 🏗️ Application Architecture

```text
                ┌─────────────────────┐
                │   Flutter Mobile    │
                │        App          │
                └──────────┬──────────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
            ▼              ▼              ▼
     Firebase Auth     Firestore      Firebase Storage
            │              │              │
            ▼              ▼              ▼
        User Login     App Data        Images/Media
```

---

## 🗄️ Proposed Firestore Structure

```text
users/
    userId/
        name
        email
        role

machines/
    machineId/
        name
        productionLine
        status
        temperature
        vibration
        healthScore

faults/
    faultId/
        machineId
        type
        severity
        description
        reportedBy
        imageUrl
        createdAt

maintenance/
    maintenanceId/
        machineId
        faultId
        technicianId
        priority
        status
        notes
        createdAt
```

The database structure may evolve as development progresses.

---

## 📁 Planned Flutter Folder Structure

```text
lib/
│
├── main.dart
│
├── models/
│   ├── user_model.dart
│   ├── machine_model.dart
│   ├── fault_model.dart
│   └── maintenance_model.dart
│
├── screens/
│   ├── auth/
│   ├── dashboard/
│   ├── machines/
│   ├── faults/
│   ├── maintenance/
│   └── profile/
│
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   └── storage_service.dart
│
├── widgets/
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   └── machine_card.dart
│
├── utils/
│   ├── constants.dart
│   ├── validators.dart
│   └── routes.dart
│
└── providers/
    └── app_state.dart
```

---

## 🗓️ Sprint 2 Roadmap

The project is being developed by a team of **3 members over 20 days**.

Each member is expected to raise **at least one Pull Request every day**.

That means:

```text
3 Members
×
20 Days
=
Minimum 60 Pull Requests
```

### Team Responsibilities

| Role | Primary Responsibility |
|---|---|
| Member 1 | Flutter UI/UX |
| Member 2 | Firebase & Database |
| Member 3 | Application Logic & Integration |

### Sprint Milestones

| Milestone | Target |
|---|---|
| Project Planning & Setup | Day 1–5 |
| Authentication | Day 6–10 |
| Firestore & Core Application | Day 11–15 |
| Storage, Security & Integration | Day 16–18 |
| Testing & Polish | Day 19 |
| Final Submission | Day 20 |

---

## 🔀 Git & GitHub Workflow

We follow a Pull Request based development workflow.

```text
main
 │
 ├── feature/member1-feature-name
 ├── feature/member2-feature-name
 └── feature/member3-feature-name
```

### Development Process

```text
Create Branch
     ↓
Make Changes
     ↓
Test Changes
     ↓
Commit
     ↓
Push Branch
     ↓
Raise Pull Request
     ↓
Peer Review
     ↓
Merge
```

### Branch Naming Examples

```text
feature/splash-screen
feature/firebase-auth
feature/machine-list
feature/fault-reporting
feature/firestore-integration
fix/login-validation
docs/update-readme
```

### Commit Naming Examples

```text
feat: add splash screen

feat: implement firebase authentication

feat: create machine model

feat: add fault reporting form

fix: resolve login validation issue

refactor: improve firestore service

docs: update README
```

---

## 💻 Getting Started

### Prerequisites

Before running the project, make sure you have:

- Git
- Flutter SDK
- Dart
- Android Studio or VS Code
- Android Emulator or physical Android device
- Firebase account
- FlutterFire CLI

Check Flutter installation:

```bash
flutter doctor
```

---

## 📥 Clone the Repository

```bash
git clone https://github.com/kalviumcommunity/SW2627-FlutterFire-MachAlert.git
```

Navigate into the project:

```bash
cd SW2627-FlutterFire-MachAlert
```

---

## 📦 Install Flutter Dependencies

After the Flutter project is initialized:

```bash
flutter pub get
```

---

## 🔥 Firebase Configuration

Install Firebase CLI:

```bash
npm install -g firebase-tools
```

Login:

```bash
firebase login
```

Install FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

Configure Firebase:

```bash
flutterfire configure
```

Firebase services planned for this project:

- Firebase Authentication
- Cloud Firestore
- Firebase Storage

---

## ▶️ Run the Application

Check available devices:

```bash
flutter devices
```

Run:

```bash
flutter run
```

---

## 🤝 Contribution Guidelines

Before starting work:

```bash
git checkout main
git pull origin main
```

Create your branch:

```bash
git checkout -b feature/your-feature-name
```

After completing your work:

```bash
git add .
git commit -m "feat: describe your change"
git push -u origin feature/your-feature-name
```

Then create a Pull Request on GitHub.

### Important Team Rule

Every team member must:

- Raise at least one PR every working day
- Keep PRs small and focused
- Test changes before raising a PR
- Write meaningful commit messages
- Review teammates' PRs
- Avoid pushing unfinished experimental code directly to `main`

---

## ✅ Current Project Status

```text
🟡 Status: Sprint 2 — Development
```

The project is currently being developed using Flutter and Firebase.

---

## 📖 Sprint 2 Learning Areas

This project covers:

- Dart Language
- Flutter Core
- Stateless Widgets
- Stateful Widgets
- Reusable Widgets
- Screen Navigation
- Splash Screen
- Forms
- Input Validation
- State Management
- Lists
- Loading Indicators
- Error Handling
- Async/Await
- Firebase Configuration
- Firebase Authentication
- Cloud Firestore
- CRUD Operations
- Firestore Queries
- Real-Time Updates
- Security Rules
- Firebase Storage
- Image Upload
- Persistent Login
- Bottom Navigation
- User Feedback
- Search and Filtering

---

## 📜 License

This project is being developed as part of an academic Sprint project.

---

## 🙌 Acknowledgements

Developed by the MachAlert team as part of the **Flutter & Firebase Mobile Application Development Sprint**.

---

<p align="center">
  <b>MachAlert</b><br>
  Detect Faster • Report Earlier • Maintain Smarter
</p>