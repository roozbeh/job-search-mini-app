const SIGN_PAYMENT_ENDPOINT = 'https://api.agnicpay.xyz/api/sign-payment';
const AGNIC_LLM_ENDPOINT = 'https://api.agnicpay.xyz/v1/chat/completions';

type PaymentRequirements = {
  x402Version?: number;
  accepts?: Array<Record<string, unknown>>;
  [key: string]: unknown;
};

export async function fetchX402WithOAuth(
  url: string,
  oauthToken: string,
  init: RequestInit = {}
): Promise<Response> {
  const method = init.method ?? 'GET';
  const headers = (init.headers ?? {}) as Record<string, string>;

  const initial = await fetch(url, { ...init, method, headers });
  if (initial.status !== 402) {
    return initial;
  }

  const paymentRequirements = (await initial.json()) as PaymentRequirements;
  const signResponse = await fetch(SIGN_PAYMENT_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${oauthToken}`,
    },
    body: JSON.stringify({
      paymentRequirements,
      requestData: { url, method },
    }),
  });

  if (!signResponse.ok) {
    const errorText = await signResponse.text();
    throw new Error(`Payment signing failed: ${signResponse.status} ${errorText}`);
  }

  const signData = await signResponse.json();
  const paymentHeader = signData?.paymentHeader as string | undefined;
  if (!paymentHeader) {
    throw new Error('Payment signing failed: missing paymentHeader');
  }

  return fetch(url, {
    ...init,
    method,
    headers: {
      ...headers,
      'X-Payment': paymentHeader,
    },
  });
}

export async function requestChatCompletionWithOAuth(
  payload: Record<string, unknown>,
  oauthToken: string
): Promise<unknown> {
  const response = await fetch(AGNIC_LLM_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${oauthToken}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`AgnicPay LLM error: ${response.status} ${errorText}`);
  }

  return response.json();
}
