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
    ServerAdmin info@ipronto.net
    ServerName jobsearch.ipronto.net

    ProxyPreserveHost On
    ProxyPass /.well-known/acme-challenge/ !
    ProxyPass / http://127.0.0.1:8001/

    RewriteEngine on
    RewriteCond %{REQUEST_URI} !^/.well-known/acme-challenge/
    RewriteCond %{SERVER_NAME} =jobsearch.ipronto.net
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>

<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerAdmin info@ipronto.net
    ServerName jobsearch.ipronto.net

    DocumentRoot /home/ubuntu/job-search-mini-app/dist

    <Directory /home/ubuntu/job-search-mini-app/dist>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ProxyPreserveHost On
    ProxyPass /api/ http://127.0.0.1:8001/api/
    ProxyPassReverse /api/ http://127.0.0.1:8001/api/

    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/api/
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} !-f
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} !-d
    RewriteRule ^ /index.html [L]

    SSLCertificateFile /etc/letsencrypt/live/jobsearch.ipronto.net/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/jobsearch.ipronto.net/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>
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

# Job search provider (switchable without code changes)
JOB_SEARCH_PROVIDER=serpapi   ← currently active provider
SERPAPI_KEY=<user must set>   ← required when JOB_SEARCH_PROVIDER=serpapi
```
> The app runs in **user-pays mode**: each user's Agnic OAuth token is the API key. `AGNICPAY_API_KEY` is optional as a server-side fallback but is currently empty on the server.
> **Job search is server-pays**: SerpAPI key is a server-side key, not per-user. Free tier = 250 searches/month.

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
- `backend/app/routers/jobs.py` — Job search with MongoDB cache (6hr TTL); provider-switchable via `JOB_SEARCH_PROVIDER` env var; dispatches to `_search_serpapi()` or `_search_agnic()`
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
2. **SERPAPI_KEY on server**: Must be added manually to `/home/ubuntu/job-search-mini-app/backend/.env` — cannot be deployed via git. Job search returns 500 until this is set.
3. **Session key stability**: Session is keyed by SHA256 of the OAuth token. A new login (new token) creates a new session. Future: use Agnic wallet address as stable user ID.
4. **Frontend build verification**: Run `npm install && npm run build` locally before deploying web frontend.
5. **Job search provider experimentation**: Currently using SerpAPI (250 free req/month). Other candidates: JSearch/RapidAPI (200 free/month), Adzuna (250/day free). Switch via `JOB_SEARCH_PROVIDER` in `.env` + add `_search_<provider>()` in `jobs.py`.

---

## Agnic API Model Names

Agnic uses a namespaced `provider/model` format. Confirmed working:
- `"openai/gpt-4o"` — used by backend `cv.py` for resume analysis (capable, costly)
- `"openai/gpt-4o-mini"` — used by iOS `APIService.computeMatchScore` for resume-job match (fast, cheap, ~30× less than gpt-4o)

When adding new LLM calls, use this `provider/model` format. Gemini models may work as `"google/gemini-2.0-flash"` but unconfirmed.

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
- **Job search 401/502**: Agnic x402/fetch proxy returns 401 for user OAuth tokens on the job-search custom endpoint — it requires a separate paid credential. Replaced with SerpAPI provider. `HTTPException` from `_search_*` functions must be re-raised (not caught by generic `except Exception`) to avoid masking 401 as 502.
- **src/ and src 2/ use mock jobs only**: Neither web frontend ever called a real job search API. All job search is handled by the backend + external provider.
- **Job search is provider-switchable**: Set `JOB_SEARCH_PROVIDER=serpapi|agnic` in `.env`. Add new providers as `_search_<name>()` in `jobs.py` + new branch in `_search_jobs()`.
- **advanceToNextJob off-by-one (fixed)**: Was `if currentJobIndex < discoveryJobs.count - 1` — last card never advanced. Fixed to always increment `currentJobIndex` unconditionally; the view's `vm.currentJobIndex >= vm.discoveryJobs.count` check handles the "all done" state.
- **computeMatchScore (fixed)**: Was using `model: "gpt-4o"` (wrong format) with `response_format: json_object` (unsupported by Agnic/Claude). Fixed to use `"openai/gpt-4o-mini"` with no `response_format`; JSON is extracted from raw text response (handles markdown wrapping). Errors now logged via `print("[MatchScore] failed for ...")` instead of silently swallowed.
- **computeMatchScore call style**: Uses `JSONSerialization` dict (not `OpenAIRequest` Codable struct) to avoid sending unsupported fields. Response parsed via `OpenAIResponse` then JSON extracted with brace-range search before `JSONDecoder().decode(MatchGuidance.self, ...)`.
- **caveman plugin node error**: The caveman Claude Code plugin requires Node.js installed. Error `SessionStart hook error: /bin/sh: node: command not found` means Node is not installed. Fix: `brew install node`.

---

## Reference Projects
- `smb_marketing/` — Reference for Apache config and deploy.sh patterns
- `app_store_analyzer/` — Reference for Apache + acme.sh setup
- `/Users/roozbeh/Google Drive/iPronto/discussion-panel-345090c6/` — PolyMind app; reference for Agnic balance display pattern (`AgnicBalance`, `CoinBalanceView`)
