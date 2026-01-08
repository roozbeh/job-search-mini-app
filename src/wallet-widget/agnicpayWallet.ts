/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { getAccessToken, WalletBalance } from './authService';

export interface WalletPaymentRequest {
  amountUsd: number;
  currency?: string;
  memo?: string;
  metadata?: Record<string, unknown>;
}

export interface WebhookPayload {
  accessToken: string;
  wallet?: WalletBalance | null;
  metadata?: Record<string, unknown>;
}

const DEFAULT_PAYMENT_URL = import.meta.env.VITE_AGNICPAY_PAYMENT_URL;
const DEFAULT_WEBHOOK_URL = import.meta.env.VITE_AGNICPAY_WEBHOOK_URL;

async function postJson<T>(url: string, body: T, token: string): Promise<unknown> {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Request failed: ${response.status} ${text}`);
  }

  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch (error) {
    return text;
  }
}

export async function requestWalletPayment(
  request: WalletPaymentRequest,
  endpoint: string | undefined = DEFAULT_PAYMENT_URL
): Promise<unknown> {
  if (!endpoint) {
    throw new Error('Payment endpoint is not configured.');
  }

  const token = getAccessToken();
  if (!token) {
    throw new Error('Not authenticated.');
  }

  return postJson(endpoint, request, token);
}

export async function sendApiKeyToWebhook(
  payload: Omit<WebhookPayload, 'accessToken'>,
  endpoint: string | undefined = DEFAULT_WEBHOOK_URL
): Promise<unknown> {
  if (!endpoint) {
    throw new Error('Webhook endpoint is not configured.');
  }

  const token = getAccessToken();
  if (!token) {
    throw new Error('Not authenticated.');
  }

  const body: WebhookPayload = {
    accessToken: token,
    wallet: payload.wallet ?? null,
    metadata: payload.metadata ?? {},
  };

  return postJson(endpoint, body, token);
}
