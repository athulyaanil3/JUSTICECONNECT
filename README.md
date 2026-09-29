# JusticeConnect

JusticeConnect is a unified legal services and case management platform built with Flutter and Supabase. The platform streamlines collaboration between citizens, lawyers, advocate clerks, and system administrators with role-based dashboards, secure messaging, case tracking, digital filings, and end-to-end encrypted evidence vaults.

---

## Tech Stack

- **Frontend:** Flutter (Dart), Material Design 3
- **Backend & Database:** Supabase (PostgreSQL, Row Level Security, Edge Functions with Deno runtime)
- **State Management:** Provider
- **Security & Encryption:** AES-GCM / Hybrid Cryptography, Android FLAG_SECURE window protection
- **File Handling & PDF:** syncfusion_flutter_pdfviewer, ile_picker, open_filex

---

## Module Owners & Responsibilities

| Module | Branch | Lead / Owner | Scope |
| :--- | :--- | :--- | :--- |
| **Admin Module** | eature/admin-module | **Athulya** | System administration, lawyer verification, advocate clerk management, role assignment, complaint tracking, audit logs. |
| **Citizen (User) Module** | eature/user-module | **Rufus** | Citizen dashboard, lawyer discovery & profile view, appointment booking, AI legal assistant, case status tracking. |
| **Lawyer Module** | eature/lawyer-module | **Moncy** | Lawyer dashboard, case management, client consultation requests, hearing schedules, verified profile management. |
| **Advocate Clerk Module** | eature/clerk-module | **Dona** | Clerk dashboard, case filings workflow, judge assist, cause list generation, verification handling, daily case logs. |

---

## Development Notes

This project was originally developed collaboratively on a local development workstation and subsequently structured into Git for distributed development and continuous integration.

To maintain clean modular separation while preserving shared foundational code, the codebase was organized with a shared core on main and dedicated feature branches for each role module:
- eature/admin-module
- eature/user-module
- eature/lawyer-module
- eature/clerk-module

### Ongoing Workflow
Going forward, all new bug fixes and feature additions must follow the standard branch-and-PR workflow:
1. Branch off main using standard prefixes (eature/..., ix/..., chore/...).
2. Implement and test changes locally (lutter pub get, lutter analyze).
3. Open a Pull Request targeting main for code review and merge.

---

## Getting Started & Setup

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or higher)
- [Dart SDK](https://dart.dev/get-dart)
- An active [Supabase](https://supabase.com) project

### Installation Steps

1. **Clone the repository:**
   `ash
   git clone https://github.com/athulyaanil3/JUSTICECONNECT.git
   cd JUSTICECONNECT
   `

2. **Install Flutter dependencies:**
   `ash
   flutter pub get
   `

3. **Database Setup:**
   Execute the migration SQL scripts located in the database/ folder sequentially in your Supabase SQL Editor:
   - database/setup_profiles_rls.sql
   - database/setup_cases_tables.sql
   - database/setup_lawyer_offices.sql
   - database/setup_chat.sql
   - database/setup_notifications.sql
   - database/setup_storage.sql
   - database/setup_reviews_ratings.sql
   - database/create_lawyer_reviews.sql

4. **Run the Application:**
   `ash
   flutter run
   `
