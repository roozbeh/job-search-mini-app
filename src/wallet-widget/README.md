# AgnicPay Wallet Widget (Reusable Package)

This folder contains a self-contained wallet widget and auth helpers you can copy into any React + Vite project.

## Files to copy

- `wallet-widget/AuthContext.tsx`
- `wallet-widget/authService.ts`
- `wallet-widget/WalletWidget.tsx`
- `wallet-widget/agnicpayWallet.ts`

Place them in your project (e.g., `src/wallet/`) keeping the relative imports intact.

## Quick start

1) Configure your AgnicPay OAuth client
- Update `clientId` in `authService.ts`
- Register your redirect URI (default `/callback`)

2) Wrap your app with the provider:

```tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { AuthProvider } from './wallet/AuthContext';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AuthProvider>
      <App />
    </AuthProvider>
  </React.StrictMode>
);
```

3) Add the widget where you want it:

```tsx
import WalletWidget from './wallet/WalletWidget';

export default function Header() {
  return (
    <header>
      <WalletWidget connectLabel="Connect wallet" />
    </header>
  );
}
```

4) Ensure `/callback` is routable.
- The auth flow expects the app to load at `/callback` so it can read `code` and `state` query params.
- If you use a router, add a route that renders your app or a callback page that calls `handleCallback()`.

## Optional payment and webhook actions

The widget can show two actions if you provide endpoints:
- **Request payment**: prompts for amount and POSTs to your server.
- **Send API key to webhook**: POSTs the access token and wallet info to your webhook (e.g., n8n).

Set env vars in your project:
- `VITE_AGNICPAY_PAYMENT_URL`
- `VITE_AGNICPAY_WEBHOOK_URL`

Or override with custom handlers:

```tsx
<WalletWidget
  onRequestPayment={async ({ token }) => {
    await fetch('/api/pay', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
  }}
  onSendWebhook={async ({ token, wallet }) => {
    await fetch('/api/webhook', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({ token, wallet }),
    });
  }}
/>
```

## Developer considerations

- **OAuth client setup:** Update `clientId` and register your redirect URI with AgnicPay.
- **Scopes:** Change `OAUTH_CONFIG.scopes` if you need fewer/extra permissions.
- **Token storage:** Access tokens are stored in `sessionStorage`. Add refresh/expiry handling if needed.
- **Backend security:** Prefer a backend proxy for payments; avoid direct browser calls unless AgnicPay supports it.
- **Webhook privacy:** Only send tokens to trusted webhooks and get user consent if needed.
- **CORS & HTTPS:** Your API endpoints must accept requests from your app origin and use HTTPS in production.
