# HAWK_ADMIN Setup

## 1) Backend deploy
Deploy `app.py` with PostgreSQL.

Required environment variables:
- `DATABASE_URL`
- `APP_SECRET`
- `CRON_TOKEN`
- `MOBILE_API_TOKEN`

Optional:
- `SUPER_ADMIN_EMAIL`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_BOT_USERNAME`

## 2) Mobile API (already added)
The app now uses:
- `POST /api/mobile/bootstrap`
- `GET /api/mobile/items`
- `POST /api/mobile/items`
- `PATCH /api/mobile/items/<item_id>/target`
- `DELETE /api/mobile/items/<item_id>`
- `POST /api/mobile/items/<item_id>/check`
- `POST /api/mobile/check-all`

All endpoints require:
- header `X-API-TOKEN: <MOBILE_API_TOKEN>`

## 3) Hourly update automation
GitHub workflow file:
- `.github/workflows/hawk_admin_hourly.yml`

Set repository secrets:
- `HAWK_ADMIN_BACKEND_URL`
- `CRON_TOKEN`

This triggers `/cron/update-all` every hour.

## 4) iOS app config
Open:
- `ios/HAWK_ADMIN/HAWK_ADMIN/AppConfig.swift`

Edit `HAWKAdminRemoteConfig`:
- `baseURLString`
- `apiToken` (must match `MOBILE_API_TOKEN`)
- `bootstrapEmail`

## 5) Build
Open:
- `ios/HAWK_ADMIN/HAWK_ADMIN.xcodeproj`

Scheme:
- `HAWK_ADMIN`
