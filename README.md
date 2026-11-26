# Nudge

Nudge is a lightweight academic task tracker built with Flutter. It uses a dark charcoal interface with warm orange accents and local SQLite persistence.

## Features

- Create, edit, complete, and delete tasks.
- Store task data locally with SQLite.
- Run in Chrome using SQLite WebAssembly and browser IndexedDB storage.
- Filter tasks by All, Overdue, Today, Upcoming, and Completed.
- Prioritize unfinished tasks by nearest deadline, with completed tasks at the bottom of the All list.
- Organize tasks into projects and track milestone completion progress.
- Browse deadlines in a monthly calendar and inspect tasks by date.
- Search task titles and subjects.
- Export and restore a versioned JSON backup containing projects and tasks.
- Smart Nudge recommends a focus task based on overdue items, today's workload, and deadline clusters.
- Android local deadline reminders: day-before, deadline-day, and two overdue follow-ups.

## Run in Chrome

```bash
flutter pub get
dart run sqflite_common_ffi_web:setup
flutter run -d chrome --web-port 8080
```

Use the same origin and port while testing persistence. Browser storage is scoped to the site origin; changing the port can make the app appear to have a separate database.

## Run on Android

```bash
flutter pub get
flutter run
```

Android notifications need notification permission. Reminders are scheduled at 9:00 AM Jakarta time: the day before the due date, on the due date, and on the following two days if the task is still unfinished. Notifications are inexact so Android battery optimization may delay delivery. Web currently does not schedule OS notifications; Smart Nudge remains available in-app.

## Quality checks

```bash
flutter analyze
flutter test
flutter build web --release --base-href /Nudge/
flutter build apk --release
```

CI runs analysis, tests, a release web build, and a release Android APK build on pushes and pull requests to `main` and `improvement`. APKs are uploaded as workflow artifacts for 14 days.

## Deployment (GitHub Pages)

Web deployment is configured to run automatically when code is pushed to the `improvement` branch.

1. Open the repository **Settings → Pages**.
2. In **Build and deployment → Source**, select **GitHub Actions** (one-time setup).
3. Push a commit to `improvement` or run the **Deploy Nudge Web to GitHub Pages** workflow manually from Actions.
4. When the deployment workflow succeeds, the app is published at:

   https://iddaann.github.io/Nudge/

Deployment status: check the Actions tab. The first deployment may fail until GitHub Pages is enabled for the repository.

## Data and privacy

- Tasks and projects are stored locally on the device/browser; there is no account or cloud sync.
- Browser storage is origin-specific. Changing the deployment URL or clearing browser site data can make the local database inaccessible or erase it.
- Export JSON regularly and keep a copy somewhere safe.
- Import restores a backup by replacing the existing local task and project data.
- SQLite Web uses browser IndexedDB-backed storage; this is not a server-side database.


## Milestones 10–14 release candidate notes

- **Milestone 10:** Android deadline reminders are scheduled locally; completed tasks cancel their remaining reminders. Reminders are re-synced on app startup and when task status/deadline changes.
- **Milestone 11:** Smart Nudge shows a rule-based focus suggestion, workload warning, overdue warning, and deadline-cluster warning. It does not require AI, internet, or an account.
- **Milestone 12:** Home empty state and error/loading states retained; reminders provide a clear permission/failure feedback path. UI remains lightweight.
- **Milestone 13:** Added database validation/backup edge-case tests and widget smoke checks. Run `flutter analyze` and `flutter test` before release.
- **Milestone 14:** Version is set to `1.0.0+14`. CI builds the Web and Android release APK. APK is CI artifact, not signed with a production keystore; configure a private release signing key before Play Store distribution.
