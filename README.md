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
```

The repository includes SQLite CRUD and persistence tests in `test/nudge_database_test.dart`. Run the web setup command before launching the app in Chrome so the SQLite WASM assets are available.

## Notes

- Task data is stored locally on the device/browser; it is not synchronized to a cloud account.
- Clearing browser site data can erase the local web database. Export a JSON backup regularly and keep it somewhere safe.
- Export copies JSON to the clipboard. Import replaces the current local task and project data after validating the backup format.
