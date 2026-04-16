# JobMatch iOS App — Setup Guide

## Prerequisites

- Xcode 15+ (Swift 5.9+, iOS 17+)
- An AgnicPay API key (from agnic.ai) — or a standard OpenAI key if you adapt APIService.swift
- The existing JobFlow backend running (see `/server/` in the repo root)

## Create the Xcode Project

1. Open Xcode → **File > New > Project**
2. Choose **iOS > App**
3. Set:
   - Product Name: `JobSearch`
   - Bundle Identifier: `com.yourname.jobsearch`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Minimum Deployment: **iOS 17.0**
4. Save the project inside `ios/`

## Add Source Files

Drag the following files/folders from `ios/JobSearch/` into your Xcode project:

```
JobSearchApp.swift
Models/Models.swift
Services/APIService.swift
ViewModels/AppViewModel.swift
Views/ContentView.swift
Views/Onboarding/OnboardingView.swift
Views/Resume/ResumeUploadView.swift
Views/Resume/ResumeAnalysisView.swift
Views/Preferences/PreferencesView.swift
Views/Discovery/JobDiscoveryView.swift
Views/Discovery/SwipeableJobCardView.swift
Views/SavedJobs/SavedJobsView.swift
Views/SavedJobs/JobDetailView.swift
Views/Components/MatchScoreBadge.swift
Views/Components/ResumeGuidanceSheet.swift
Views/ProfileView.swift
```

Make sure "Add to target: JobSearch" is checked for all files.

## Configure Your Backend URL

By default the app points to `https://jobflow-backend.onrender.com`.

To use your own backend:
1. Run the existing Node.js backend: `cd server && node index.js`
2. In the app, go to **Profile → API Configuration** and update the URL

## API Key

1. Go to [agnic.ai](https://agnic.ai) and create an account
2. Copy your API key
3. In the app: **Profile → API Configuration → API Key**
4. The key is stored in `UserDefaults` (device-only, not synced to iCloud in this MVP)

## App Flow

```
Onboarding → Resume Upload → AI Analysis → Preferences → Job Discovery
                                                              ↓
                                              Saved Jobs ← Swipe Right
                                              Dismissed  ← Swipe Left
```

## Key Features

| Feature | Implementation |
|---------|---------------|
| Resume PDF upload | `UIDocumentPickerViewController` via SwiftUI `fileImporter` |
| AI resume analysis | `POST /api/cv/analyze` on your backend |
| ATS scoring | `POST /api/cv/detailed-review` on your backend |
| Job search | `POST /api/jobs/search` → AgnicHub aggregator |
| Match score per job | Direct OpenAI GPT-4o call via AgnicPay proxy |
| Swipe UX | Custom `DragGesture` on `SwipeableJobCardView` |
| Persistence | `UserDefaults` (JSON-encoded models) |

## Architecture

```
AppViewModel (ObservableObject)
    ├── APIService (actor)         ← all network calls
    ├── Resume + ResumeAnalysis   ← persisted to UserDefaults
    ├── [Job] discoveryJobs       ← search results + match scores
    ├── [SavedJob] savedJobs      ← user's saved jobs
    └── AppPhase                  ← drives root view navigation
```

## What to Build Next (Post-MVP)

- [ ] **Resume text editor** — in-app editing with AI suggestions applied directly
- [ ] **Push notifications** — alert when new matching jobs appear
- [ ] **iCloud sync** — sync saved jobs across devices
- [ ] **Cover letter generator** — per-job cover letter using resume + JD
- [ ] **Interview prep** — role-specific practice questions from the JD
- [ ] **Application timeline** — visual tracker of where each application stands
- [ ] **Salary negotiation** — market rate data pulled from AgnicHub salary API
- [ ] **Analytics dashboard** — response rate, average match score, time-to-offer
