# HAWK_ADMIN (Cloud-Synced iOS)

`HAWK_ADMIN` is the cloud version of your app:
- iOS app is the UI.
- Backend stores all users/items/history.
- Hourly server checks keep running even when app is closed.

## What changed
- Added mobile backend API in `app.py` (`/api/mobile/*`).
- Added hourly GitHub Actions trigger: `.github/workflows/hawk_admin_hourly.yml`.
- `HAWK_ADMIN` iOS app now syncs from backend, not device-only storage.

## Configure iOS app
Open:
`/Users/abdullahalghamdi/Downloads/amazonsa-track-main 3/ios/HAWK_ADMIN/HAWK_ADMIN/AppConfig.swift`

Set these values in `HAWKAdminRemoteConfig`:
1. `baseURLString` = your backend URL (HTTPS).
2. `apiToken` = same value as backend `MOBILE_API_TOKEN`.
3. `bootstrapEmail` = account email for this app/device.

## Open and run
1. Open `/Users/abdullahalghamdi/Downloads/amazonsa-track-main 3/ios/HAWK_ADMIN/HAWK_ADMIN.xcodeproj` in Xcode.
2. Select `HAWK_ADMIN` scheme.
3. Build/run on iPhone.

## Backend requirements
At minimum set these env vars in backend:
- `DATABASE_URL`
- `APP_SECRET`
- `CRON_TOKEN`
- `MOBILE_API_TOKEN`

Optional:
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_BOT_USERNAME`
- `SUPER_ADMIN_EMAIL`

## Hourly server updates
Set GitHub repo secrets:
- `HAWK_ADMIN_BACKEND_URL` (example: `https://your-app.onrender.com`)
- `CRON_TOKEN`

The workflow calls:
- `POST /cron/update-all` every hour.
