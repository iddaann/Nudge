# Changelog

## 1.0.0+14 — Milestones 9–14 (Release candidate)

### Reliability
- Validate task/project input and project references before database writes.
- Validate imported backup data and reject duplicate IDs/invalid dates.
- Restore backups in a transaction so failed imports do not destroy current data.
- Preserve tasks when deleting a project by clearing their project reference.

### Smart Reminder (Android)
- Local reminders at 09:00 WIB the day before, on the due date, and for two follow-up overdue mornings.
- Reminders reschedule when tasks are created, edited, completed, or when the app opens.
- Uses inexact scheduling to avoid requiring exact-alarm permission.
- Notification permission is requested by the Android plugin. Web does not schedule operating-system notifications.

### Smart Nudge
- Rule-based focus recommendation.
- Alerts for overdue work, high workload today, and clustered deadlines.
- No account, network, AI API, or background service required.

### UX and QA
- Improved reminder refresh feedback and Web limitation messaging.
- Added database edge-case tests for invalid task/project data, malformed backup, duplicate backup IDs, transactional safety, project CRUD, and task retention on project deletion.
- Added widget smoke checks for Home/Smart Nudge, empty state, Calendar, and Projects navigation.

### Release
- Version: 1.0.0, build 14.
- CI analyzes, tests, builds Web, builds Android APK, and uploads APK artifacts (14-day retention).
- APK uses debug signing for this project template; production distribution requires a private signing configuration.
