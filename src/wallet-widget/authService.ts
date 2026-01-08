/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

const OAUTH_CONFIG = {
  authorizationUrl: 'https://app.agnicpay.xyz/oauth-consent',
  tokenUrl: 'https://api.agnicpay.xyz/oauth/token',
  clientId: 'myfit-check',
  scopes: 'payments:sign balance:read',
  get redirectUri() {
    return `${window.location.origin}/callback`;
  }
};

const STORAGE_KEYS = {
  accessToken: 'agnic_access_token',
  codeVerifier: 'agnic_code_verifier',
  state: 'agnic_oauth_state',
};

export interface TokenResponse {
  access_token: string;
  token_type: string;
  expires_in?: number;
  scope?: string;
}

function generateRandomString(length: number): string {
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  const randomValues = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(randomValues, (byte) => charset[byte % charset.length]).join('');
}

async function sha256(plain: string): Promise<ArrayBuffer> {
  const encoder = new TextEncoder();
  const data = encoder.encode(plain);
  return crypto.subtle.digest('SHA-256', data);
}

function base64urlEncode(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

async function generateCodeChallenge(codeVerifier: string): Promise<string> {
  const hashed = await sha256(codeVerifier);
  return base64urlEncode(hashed);
}

export async function initiateLogin(): Promise<void> {
  const codeVerifier = generateRandomString(64);
  const codeChallenge = await generateCodeChallenge(codeVerifier);

  const state = generateRandomString(32);

  sessionStorage.setItem(STORAGE_KEYS.codeVerifier, codeVerifier);
  sessionStorage.setItem(STORAGE_KEYS.state, state);

  const params = new URLSearchParams({
    client_id: OAUTH_CONFIG.clientId,
    redirect_uri: OAUTH_CONFIG.redirectUri,
    state: state,
    scope: OAUTH_CONFIG.scopes,
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
  });

  const authUrl = `${OAUTH_CONFIG.authorizationUrl}?${params.toString()}`;

  console.log('Initiating OAuth login:', {
    clientId: OAUTH_CONFIG.clientId,
    redirectUri: OAUTH_CONFIG.redirectUri
  });

  window.location.href = authUrl;
}

export async function handleCallback(): Promise<{ success: boolean; error?: string }> {
  const urlParams = new URLSearchParams(window.location.search);

  const error = urlParams.get('error');
  if (error) {
    const errorDescription = urlParams.get('error_description') || 'Authorization failed';
    console.error('OAuth error:', error, errorDescription);
    cleanupOAuthParams();
    return { success: false, error: errorDescription };
  }

  const code = urlParams.get('code');
  const returnedState = urlParams.get('state');

  if (!code) {
    cleanupOAuthParams();
    return { success: false, error: 'No authorization code received' };
  }

  const storedState = sessionStorage.getItem(STORAGE_KEYS.state);
  if (returnedState !== storedState) {
    cleanupOAuthParams();
    return { success: false, error: 'State mismatch - possible CSRF attack' };
  }

  const codeVerifier = sessionStorage.getItem(STORAGE_KEYS.codeVerifier);
  if (!codeVerifier) {
    cleanupOAuthParams();
    return { success: false, error: 'Code verifier not found' };
  }

  try {
    const response = await fetch(OAUTH_CONFIG.tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: OAUTH_CONFIG.redirectUri,
        client_id: OAUTH_CONFIG.clientId,
        code_verifier: codeVerifier,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Token exchange failed:', response.status, errorText);
      cleanupOAuthParams();
      return { success: false, error: `Token exchange failed: ${response.status}` };
    }

    const tokenData: TokenResponse = await response.json();

    sessionStorage.setItem(STORAGE_KEYS.accessToken, tokenData.access_token);

    console.log('OAuth login successful');
    cleanupOAuthParams();

    return { success: true };
  } catch (err) {
    console.error('Token exchange error:', err);
    cleanupOAuthParams();
    return { success: false, error: 'Failed to exchange authorization code' };
  }
}

function cleanupOAuthParams(): void {
  sessionStorage.removeItem(STORAGE_KEYS.codeVerifier);
  sessionStorage.removeItem(STORAGE_KEYS.state);

  if (window.location.search) {
    window.history.replaceState({}, '', window.location.pathname);
  }
}

export function getAccessToken(): string | null {
  return sessionStorage.getItem(STORAGE_KEYS.accessToken);
}

export function isLoggedIn(): boolean {
  return !!getAccessToken();
}

export function logout(): void {
  sessionStorage.removeItem(STORAGE_KEYS.accessToken);
  console.log('User logged out');
}

export function isCallbackUrl(): boolean {
  return window.location.pathname === '/callback';
}

export interface WalletBalance {
  usdcBalance: string;
  address: string;
  hasWallet: boolean;
  network: string;
  chainType?: string;
  creditBalance?: string;
}

export interface Transaction {
  id: string;
  amount_usd: number;
  network: string;
  endpoint: string;
  timestamp: string;
  date: string;
  status: 'success' | 'failed' | 'pending';
}

export interface TransactionsResponse {
  transactions: Transaction[];
  pagination: {
    currentPage: number;
    totalPages: number;
    totalCount: number;
    hasNextPage: boolean;
  };
  stats: {
    totalTransactions: number;
    totalSpent: number;
    successRate: number;
  };
}

export async function fetchWalletBalance(): Promise<WalletBalance | null> {
  const token = getAccessToken();
  if (!token) return null;

  try {
    const response = await fetch('https://api.agnicpay.xyz/api/balance?network=base', {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      console.error('Failed to fetch balance:', response.status);
      return null;
    }

    const data = await response.json();
    console.log('Balance API response:', data);

    if (Array.isArray(data)) {
      const baseBalance = data.find((b: WalletBalance) =>
        b.network === 'base' || b.network === 'base-sepolia'
      );
      return baseBalance || data[0] || null;
    }

    return data;
  } catch (err) {
    console.error('Error fetching balance:', err);
    return null;
  }
}

export async function fetchTransactions(limit = 10): Promise<TransactionsResponse | null> {
  const token = getAccessToken();
  if (!token) return null;

  try {
    const response = await fetch(`https://api.agnicpay.xyz/api/transactions?limit=${limit}`, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      console.error('Failed to fetch transactions:', response.status);
      return null;
    }

    return await response.json();
  } catch (err) {
    console.error('Error fetching transactions:', err);
    return null;
  }
}
