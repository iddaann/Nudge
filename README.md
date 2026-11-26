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

## Quality checks

```bash
flutter analyze
flutter test
flutter build web --release --base-href /Nudge/
```

CI runs analysis, tests, and a release web build on pushes and pull requests to `main` and `improvement`.

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
