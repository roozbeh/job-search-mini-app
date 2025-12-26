# JobFlow 🚀

AI-powered job search that understands your career goals. A beautiful, modern single-page application that helps you find the perfect job.

![JobFlow Screenshot](./screenshot.png)

## Features

- **Smart Job Search**: Search across LinkedIn, Indeed, Glassdoor, and other major job boards
- **AI CV Analysis**: Upload your CV (PDF or TXT) and get personalized job search criteria extracted automatically
- **CV Improvement Suggestions**: Get 3 actionable suggestions to improve your CV
- **Beautiful Dark UI**: Modern, minimal, and exciting design with smooth animations
- **Rate Limited**: Maximum 5 API calls per session to manage costs

## Tech Stack

- **Frontend**: React 18 + TypeScript + Vite
- **Styling**: Tailwind CSS v4 with custom theme
- **Animations**: Motion (Framer Motion)
- **Icons**: Lucide React
- **Backend**: Express.js
- **AI**: OpenAI GPT-4o via AgnicPay proxy for CV analysis
- **Job Data**: AgnicHub Job Search API via AgnicPay proxy

## Single API Key

Both job search and AI-powered CV analysis use the same AgnicPay API key. Users only need one API key from their Agnic Wallet for all features!

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn
- **AgnicPay API Key** - A single API key (starting with `agnic_tok_`) that works for both job search AND AI-powered CV analysis! Get it from your Agnic Wallet after registering at [AgnicPay.xyz](https://agnicpay.xyz)

### Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd job-search-mini-app
```

2. Install frontend dependencies:
```bash
npm install
```

3. Install server dependencies:
```bash
cd server
npm install
cd ..
```

4. No environment variables needed! The API key is entered by users in the UI.

### Running the App

1. Start the backend server:
```bash
cd server
npm run dev
```

2. In a new terminal, start the frontend:
```bash
npm run dev
```

3. Open [http://localhost:5173](http://localhost:5173) in your browser

### API Key Setup

The API key is entered directly in the UI and stored securely in your browser's localStorage:

1. **Register** at [AgnicPay.xyz](https://agnicpay.xyz)
2. **Create a new connection** in your Agnic Wallet
3. **Get your API key** (starting with `agnic_tok_`) from your Agnic Wallet
4. Enter it in the "API Key" section at the top of the app
5. Click "Save Key" - it will be remembered for future sessions
6. The key is stored locally in your browser and never sent to our servers

## How to Use

### Step 1: Enter Your API Key

1. **Register** at [AgnicPay.xyz](https://agnicpay.xyz) if you haven't already
2. **Create a new connection** in your Agnic Wallet
3. **Copy your API key** (starting with `agnic_tok_`) from your Agnic Wallet
4. Paste it in the "API Key" input field in the app
5. Click "Save Key"

### Step 2: Set Job Preferences

1. Add job titles you're interested in (e.g., "Frontend Developer", "React Engineer")
2. Add preferred locations (e.g., "San Francisco, CA", "New York")
3. Toggle "Include Remote Jobs" if you prefer remote work
4. Set your salary expectations (optional)
5. Click **Find Jobs** to search

### AI-Powered CV Analysis

1. Upload your CV as a **PDF or TXT file**, or paste the content directly
2. Click **Analyze with AI**
3. Review the extracted search criteria and click **Apply to Search Preferences**
4. Get 3 personalized CV improvement suggestions

## API Usage

The app limits job search to **5 API calls per session** to manage costs. Each search query uses 1 API call. The counter is displayed on the search button.

## Project Structure

```
job-search-mini-app/
├── src/
│   ├── components/
│   │   ├── Background.tsx     # Animated gradient background
│   │   ├── CVUpload.tsx       # CV upload and analysis
│   │   ├── Header.tsx         # App header
│   │   ├── JobCard.tsx        # Individual job listing
│   │   ├── JobResults.tsx     # Job results container
│   │   └── PreferencesForm.tsx # Job preferences form
│   ├── types.ts               # TypeScript interfaces
│   ├── App.tsx                # Main app component
│   ├── main.tsx               # Entry point
│   └── index.css              # Tailwind + custom styles
├── server/
│   ├── index.js               # Express server
│   └── package.json
├── index.html
├── vite.config.ts
└── package.json
```

## License

MIT
