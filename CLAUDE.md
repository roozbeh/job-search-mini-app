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
AGNICPAY_API_KEY=      ← OPTIONAL server-side fallback key (currently not set)
AGNIC_LLM_BASE=https://api.agnic.ai/v1
AGNIC_JOB_SEARCH_BASE=https://api.agnic.ai/v1/custom/job-search
AGNIC_FETCH_PROXY=https://api.agnic.ai/api/x402/fetch
PORT=8000
```
> The app runs in **user-pays mode**: each user's Agnic OAuth token is the API key. `AGNICPAY_API_KEY` is optional as a server-side fallback but is currently empty on the server.

---

## Deployment & Build Workflow

### After changing backend code
1. Commit and push: `git add <files> && git commit -m "..." && git push`
2. Deploy: `bash deploy.sh api`
3. Always use `bash deploy.sh` (not `./deploy.sh`) — zsh plugins on macOS break `./` execution.

> **IMPORTANT**: After every backend code change, automatically git commit, push, and run `bash deploy.sh api` without waiting to be asked.

### After changing iOS code
1. Verify it compiles: `bash -c 'DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project "ios/JobSearch.xcodeproj" -scheme JobSearch -destination "generic/platform=iOS Simulator" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"'`
2. Then build/run in Xcode for device testing.
3. SourceKit diagnostics in editor are often false positives for cross-file types — trust the xcodebuild output.

### deploy.sh (project root)
```bash
bash deploy.sh        # build frontend + deploy API
bash deploy.sh api    # deploy API only
bash deploy.sh web    # build + deploy frontend only
```

> **IMPORTANT**: The server deploys via `git pull`, so backend/frontend changes **must be committed and pushed** before running `deploy.sh`. Uncommitted local changes will NOT reach the server.

---

## Key Files

### Backend
- `backend/app/main.py` — FastAPI app, `logging.basicConfig(level=logging.INFO)` set
- `backend/app/database.py` — Motor client with `connect=False, maxPoolSize=10`
- `backend/app/routers/cv.py` — CV parse/analyze/detailed-review; logs `apiKey_len` on each call
- `backend/app/routers/jobs.py` — Job search with MongoDB cache (6hr TTL); fallback to server API key
- `backend/app/routers/session.py` — User session save/load (keyed by SHA256 of token)
- `backend/requirements.txt` — No pinned pymongo (motor 3.6.0 requires pymongo<4.10)
- `backend/docker-compose.yml` — Single `api` service, ulimits + `seccomp=unconfined`

### Frontend (Web)
- `src/main.tsx` — Entry point
- `src/app/App.tsx` — Figma-generated main app (React Router v7)
- `vite.config.ts` — Dev proxy `/api` → `http://localhost:8001`

### iOS
- `ios/JobSearch.xcodeproj/project.pbxproj` — Hand-crafted Xcode project
- `ios/JobSearch/Services/APIService.swift` — `AgnicBalance` struct, `AgnicAuthService` (PKCE OAuth, token validation, balance fetch), `APIService` actor (all backend calls)
- `ios/JobSearch/Models/Models.swift` — `Job`, `JobPreferences` (`jobTypes: Set<JobType>`, no salaryMax), `ResumeAnalysis`, `AppPhase` (with `.order` property), `UserSession`
- `ios/JobSearch/ViewModels/AppViewModel.swift` — Central state; session sync with MongoDB; resets to `.onboarding` when token expires
- `ios/JobSearch/Views/ContentView.swift` — Root view + `JourneyStepBar` + `BalancePill` + `AccountMenuButton`
- `ios/JobSearch/Views/Onboarding/OnboardingView.swift` — Sign-in gate: 3 feature pages + Agnic explainer ($5 credit) + Sign in button
- `ios/JobSearch/Views/Resume/ResumeUploadView.swift` — Step 1 (always authenticated)
- `ios/JobSearch/Views/Resume/ResumeAnalysisView.swift` — Step 2 (ATS score, improvements, section feedback)
- `ios/JobSearch/Views/Preferences/PreferencesView.swift` — Step 3 (multi-select job types, salary chip row)
- `ios/JobSearch/Views/Discovery/JobDiscoveryView.swift` — Step 4 (swipeable cards, balance pill in toolbar)
- `ios/JobSearch/Assets.xcassets/AppIcon.appiconset/` — App icon

---

## App Flow

```
OnboardingView (sign-in gate)
  → [sign in with Agnic] → load MongoDB session → resume at saved phase
  → [no session] → ResumeUploadView (Step 1)
      → ResumeAnalysisView (Step 2)
          → PreferencesView (Step 3)
              → JobDiscoveryView (Step 4, MainTabView)
                  → [Apply] (Step 5, not built yet)
```

**Session persistence**: After login, `AppViewModel` loads the user's session from `POST /api/session/load` (keyed by SHA256 of their token). On any state change, it saves to `POST /api/session/save`. Phase, resume, preferences, saved jobs, and dismissed job IDs are all persisted.

**Token expiry**: When `auth.isLoggedIn` becomes `false` (from `validateStoredToken()` or manual logout), `AppViewModel` immediately resets `phase = .onboarding`, preventing the user from reaching upload/analysis screens with an empty token.

**Balance display**: `BalancePill` (green dollar icon + `$X.XX`) shown in toolbar on all post-login screens. Fetched after login and after token validation. Refreshed after resume analysis.

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/docs` | Swagger UI |
| POST | `/api/cv/parse` | Upload CV (multipart `cv` field) — no apiKey needed |
| POST | `/api/cv/analyze` | Analyze CV; body: `{cvText, apiKey}` |
| POST | `/api/cv/detailed-review` | Detailed CV review; body: `{cvText, apiKey}` |
| POST | `/api/jobs/search` | Search jobs; body: `{jobTitles, locations, isRemote, salaryMin, jobTypes, resumeText, apiKey}` |
| POST | `/api/session/load` | Load user session; body: `{apiKey}` |
| POST | `/api/session/save` | Save user session; body: `{apiKey, session}` |
| GET | `/api/oauth/callback` | Relay Agnic OAuth code to iOS `jobsearch://` scheme |

### Important: apiKey is always the user's Agnic OAuth access_token
The iOS captures `auth.accessToken` explicitly at call time (not from actor-stored state) to avoid race conditions. CV endpoints receive apiKey in the JSON body and pass it to `AsyncOpenAI(api_key=key, base_url="https://api.agnic.ai/v1")`.

### Job Search Request
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

---

## Pending Tasks

1. **Step 5 "Apply" feature**: Journey bar shows 5 steps; step 5 (application tracking) UI/backend not built yet.
2. **Server AGNICPAY_API_KEY**: Currently empty in `.env`. If the user's token ever expires mid-request, there's no server fallback. Consider adding a server-side Agnic API key.
3. **Session key stability**: Session is keyed by SHA256 of the OAuth token. A new login (new token) creates a new session. Future: use Agnic wallet address as stable user ID.
4. **Frontend build verification**: Run `npm install && npm run build` locally before deploying web frontend.

---

## Known Issues & Fixes

- **pymongo conflict**: `motor==3.6.0` requires `pymongo<4.10`. Do NOT pin pymongo in requirements.txt.
- **MongoDB threading on small servers**: Use `connect=False, maxPoolSize=10` in `AsyncIOMotorClient`.
- **Docker on small AWS**: Need `ulimits` and `seccomp=unconfined` in docker-compose.
- **iOS `Job` Hashable**: `navigationDestination(item:)` requires `Hashable`. Implemented via `hasher.combine(id)`.
- **xcodebuild path**: Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild` if xcode-select points to CLT. Always wrap in `bash -c '...'`.
- **zsh plugin conflict on macOS**: `exec_scmb_expand_args: command not found: _safe_eval` — always use `bash -c '...'` or `bash deploy.sh`, never `./deploy.sh` or bare commands.
- **SourceKit false positives**: Cross-file type errors in editor are not real; trust `xcodebuild` output only.
- **apiKey empty → 500**: If `AppViewModel.apiKey` is read before `auth.accessToken` is set, backend gets empty key → HTTP 500. Fixed by: (1) passing apiKey explicitly at call time, (2) resetting phase to `.onboarding` whenever `auth.isLoggedIn` becomes false.
- **Agnic OAuth flow**: iOS uses `ASWebAuthenticationSession` with PKCE. Callback scheme `jobsearch://`. Backend relay at `/api/oauth/callback` returns 302 → `jobsearch://oauth/callback?code=...`. The OAuth `access_token` IS the `apiKey` sent in all API requests (user-pays model).
- **Token expiry → phase stuck**: If stored token is expired at startup, `validateStoredToken()` logs out. The `auth.$isLoggedIn` subscriber in AppViewModel now detects `loggedIn=false` and resets phase to `.onboarding`. Without this, the user could reach upload screen with an empty token.
- **Job search 401**: `_agnic_fetch` in jobs.py now falls back to `settings.agnicpay_api_key` if user key is empty. Agnic 401 re-raised as HTTP 401 (not 502) so iOS shows sign-in prompt.

---

## Reference Projects
- `smb_marketing/` — Reference for Apache config and deploy.sh patterns
- `app_store_analyzer/` — Reference for Apache + acme.sh setup
- `/Users/roozbeh/Google Drive/iPronto/discussion-panel-345090c6/` — PolyMind app; reference for Agnic balance display pattern (`AgnicBalance`, `CoinBalanceView`)
