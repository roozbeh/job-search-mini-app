# JobSearch App — Project Context

## Overview
AI-powered job search app with:
- **iOS app** (SwiftUI, in `ios/`)
- **Python/FastAPI backend** (in `backend/`)
- **React/Vite web frontend** (in `src/`, Figma-generated UI from `src 2/`)
- Deployed at **https://jobsearch.ipronto.net** on AWS (ubuntu@ipronto.net)

---

## Architecture

### Backend
- FastAPI + Motor (async MongoDB) + Docker
- Port: `8001` on server, mapped from container port `8000`
- Docs at: `https://jobsearch.ipronto.net/api/docs`
- Health check: `GET /api/health`
- Source: `backend/`
- Docker Compose: `backend/docker-compose.yml`
- Container name: `jobsearch_api`

### Frontend
- React + Vite + Tailwind v4 + shadcn/ui + Radix UI
- Built locally → `dist/` → rsynced to server
- Server path: `/home/ubuntu/job-search-mini-app/dist/`
- Apache serves `dist/` as DocumentRoot at `/`
- Apache proxies `/api/` → `http://localhost:8001`

### iOS App
- SwiftUI, Xcode project at `ios/JobSearch.xcodeproj`
- Deployment target: iOS 17.0, Swift 5.0
- Default backend URL: `https://jobsearch.ipronto.net`

---

## Server Setup (ubuntu@ipronto.net)

### Apache Config
Location: `/etc/apache2/sites-available/jobsearch.ipronto.net.conf`

```apache
<VirtualHost *:80>
    ServerName jobsearch.ipronto.net
    DocumentRoot /home/ubuntu/job-search-mini-app/dist

    <Directory /home/ubuntu/job-search-mini-app/dist>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Proxy /api/ to FastAPI backend
    ProxyPreserveHost On
    ProxyPass /api/ http://localhost:8001/api/
    ProxyPassReverse /api/ http://localhost:8001/api/

    RewriteEngine On
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} !-f
    RewriteRule ^ /index.html [L]
</VirtualHost>

<VirtualHost *:443>
    ServerName jobsearch.ipronto.net
    DocumentRoot /home/ubuntu/job-search-mini-app/dist

    SSLEngine on
    SSLCertificateFile /home/ubuntu/.acme.sh/jobsearch.ipronto.net_ecc/jobsearch.ipronto.net.cer
    SSLCertificateKeyFile /home/ubuntu/.acme.sh/jobsearch.ipronto.net_ecc/jobsearch.ipronto.net.key
    SSLCertificateChainFile /home/ubuntu/.acme.sh/jobsearch.ipronto.net_ecc/fullchain.cer

    <Directory /home/ubuntu/job-search-mini-app/dist>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ProxyPreserveHost On
    ProxyPass /api/ http://localhost:8001/api/
    ProxyPassReverse /api/ http://localhost:8001/api/

    RewriteEngine On
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} !-f
    RewriteRule ^ /index.html [L]
</VirtualHost>
```

### SSL Cert (acme.sh)
- Issued via acme.sh (NOT certbot/nginx)
- Never use `sudo` for acme.sh
- `/var/www/html` must be owned by ubuntu for webroot challenge
- Cert path: `/home/ubuntu/.acme.sh/jobsearch.ipronto.net_ecc/`

### Server .env File
Must exist at `/home/ubuntu/job-search-mini-app/backend/.env`:
```
MONGODB_URL=mongodb+srv://...@cluster.mongodb.net/
MONGODB_DB=jobsearch
AGNICPAY_API_KEY=...
AGNICPAY_BASE_URL=https://api.agnic.ai
```

---

## Deployment & Build Workflow

### After changing backend code
1. Commit and push: `git add <files> && git commit -m "..." && git push`
2. Deploy: `bash deploy.sh api`
3. Always use `bash deploy.sh` (not `./deploy.sh`) — zsh plugins on macOS break `./` execution.

### After changing iOS code
1. Verify it compiles: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/JobSearch.xcodeproj -scheme JobSearch -destination "generic/platform=iOS Simulator" build 2>&1 | tail -20`
2. Then build/run in Xcode for device testing.
3. SourceKit diagnostics in editor are often false positives for cross-file types — trust the xcodebuild output.

### deploy.sh (project root)
```bash
bash deploy.sh        # build frontend + deploy API
bash deploy.sh api    # deploy API only
bash deploy.sh web    # build + deploy frontend only
```

- Builds frontend locally (`npm run build` → `dist/`)
- rsyncs `dist/` to `ubuntu@ipronto.net:/home/ubuntu/job-search-mini-app/dist/`
- SSHes to server: `git pull` + `docker-compose up --build -d` in `backend/`
- Polls `http://localhost:8001/api/health` for up to 60s

> **IMPORTANT**: The server deploys via `git pull`, so backend/frontend changes **must be committed and pushed** before running `deploy.sh`. Uncommitted local changes will NOT reach the server.

---

## Key Files

### Backend
- `backend/app/main.py` — FastAPI app, lifespan, docs at `/api/docs`
- `backend/app/database.py` — Motor client with `connect=False, maxPoolSize=10` (threading fix for small servers)
- `backend/app/routers/cv.py` — CV parse/analyze/detailed-review endpoints
- `backend/app/routers/jobs.py` — Job search with MongoDB cache (6hr TTL)
- `backend/requirements.txt` — No pinned pymongo (motor 3.6.0 requires pymongo<4.10)
- `backend/docker-compose.yml` — Single `api` service, ulimits + `seccomp=unconfined`
- `backend/.env.example` — Template for required env vars

### Frontend (Web)
- `src/main.tsx` — Entry point, imports `./styles/index.css` and `./app/App`
- `src/app/App.tsx` — Figma-generated main app (React Router v7)
- `src/styles/index.css` — Imports fonts, tailwind, theme
- `src/styles/theme.css` — CSS custom properties (light/dark)
- `vite.config.ts` — Dev proxy `/api` → `http://localhost:8001`

### iOS
- `ios/JobSearch.xcodeproj/project.pbxproj` — Hand-crafted Xcode project
- `ios/JobSearch/Services/APIService.swift` — Backend URL, Agnic OAuth PKCE, token validation, API calls
- `ios/JobSearch/Models/Models.swift` — `Job`, `JobPreferences` (jobTypes: `Set<JobType>`, no salaryMax), `ResumeAnalysis`
- `ios/JobSearch/ViewModels/AppViewModel.swift` — Central state, `showLoginSheet` for token expiry UX
- `ios/JobSearch/Views/ContentView.swift` — Root view + `JourneyStepBar` (5-step progress bar) + `AgnicLoginSheet`
- `ios/JobSearch/Views/Resume/ResumeUploadView.swift` — Step 1
- `ios/JobSearch/Views/Resume/ResumeAnalysisView.swift` — Step 2 (ATS score, improvements, section feedback)
- `ios/JobSearch/Views/Preferences/PreferencesView.swift` — Step 3 (multi-select job types, salary chip row)
- `ios/JobSearch/Views/Discovery/JobDiscoveryView.swift` — Step 4 (swipeable job cards)
- `ios/JobSearch/Assets.xcassets/AppIcon.appiconset/` — App icon from Gemini-generated PNG

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/docs` | Swagger UI |
| POST | `/api/cv/parse` | Upload CV (multipart `cv` field) |
| POST | `/api/cv/analyze` | Analyze CV against preferences |
| POST | `/api/cv/detailed-review` | Detailed CV review |
| POST | `/api/jobs/search` | Search jobs by preferences |

### CV Response Format (matches iOS Codable models)
```json
{
  "sections": [
    { "section": "...", "message": "...", "suggestions": ["..."] }
  ]
}
```

### Job Search Request (`/api/jobs/search`)
```json
{
  "jobTitles": ["iOS Engineer"],
  "locations": ["San Francisco"],
  "isRemote": false,
  "salaryMin": 120000,
  "jobTypes": ["Full-time", "Contract"],
  "apiKey": "<agnic_access_token>"
}
```
`jobTypes` is multi-select array (empty = any). `apiKey` is the Agnic OAuth access_token.

### Job Object Format (matches iOS `Job` struct)
Fields: `id`, `title`, `company`, `location`, `salary`, `description`, `postedDate`, `applicationUrl`, `companyLogo`, `isRemote`, `employmentType`

---

## Pending Tasks

1. **Step 5 "Apply" feature**: Journey bar shows 5 steps; step 5 (application tracking) UI/backend not built yet.
2. **Frontend build verification**: Run `npm install && npm run build` locally to confirm no TypeScript/import errors before deploying web frontend.

---

## Known Issues & Fixes

- **pymongo conflict**: `motor==3.6.0` requires `pymongo<4.10`. Do NOT pin pymongo in requirements.txt.
- **MongoDB threading on small servers**: Use `connect=False, maxPoolSize=10` in `AsyncIOMotorClient`.
- **Docker on small AWS**: Need `ulimits` and `seccomp=unconfined` in docker-compose.
- **iOS `Job` Hashable**: `navigationDestination(item:)` requires `Hashable`. Implemented via `hasher.combine(id)`.
- **xcodebuild path**: Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild` if xcode-select points to CLT.
- **Apache configtest with missing SSL cert**: Temporarily remove HTTPS VirtualHost, get cert via acme.sh, then restore.
- **zsh plugin conflict on macOS**: `exec_scmb_expand_args: command not found: _safe_eval` — always use `bash -c '...'` or `bash deploy.sh`, never `./deploy.sh`.
- **SourceKit false positives**: Cross-file type errors in editor are not real; trust `xcodebuild` output only.
- **Agnic token expiry**: Backend returns 401 when OAuth token expires. iOS `APIService` throws `APIError.tokenExpired`; `AppViewModel` catches it, calls `auth.logout()`, sets `showLoginSheet = true`. Token is validated on app startup via `auth.validateStoredToken()`.
- **Agnic OAuth flow**: iOS uses `ASWebAuthenticationSession` with PKCE. Callback scheme `jobsearch://`. Backend relay at `/api/oauth/callback` returns 302 → `jobsearch://oauth/callback?code=...`. The OAuth `access_token` IS the `apiKey` sent in all API requests (user-pays model).

---

## Reference Projects
- `smb_marketing/` — Reference for Apache config and deploy.sh patterns
- `app_store_analyzer/` — Reference for Apache + acme.sh setup
