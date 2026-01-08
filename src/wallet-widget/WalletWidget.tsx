/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
*/

import React, { useEffect, useRef, useState } from 'react';
import { useAuth } from './AuthContext';
import { requestWalletPayment, sendApiKeyToWebhook } from './agnicpayWallet';
import type { WalletBalance } from './authService';

export interface WalletWidgetActionContext {
  token: string;
  wallet: WalletBalance | null;
  refreshBalance: () => Promise<void>;
}

interface WalletWidgetProps {
  className?: string;
  connectLabel?: string;
  onRequestPayment?: (context: WalletWidgetActionContext) => Promise<void>;
  onSendWebhook?: (context: WalletWidgetActionContext) => Promise<void>;
}

const WalletWidget: React.FC<WalletWidgetProps> = ({
  className,
  connectLabel = 'Connect wallet',
  onRequestPayment,
  onSendWebhook,
}) => {
  const {
    isAuthenticated,
    isLoading,
    login,
    logout,
    wallet,
    isLoadingBalance,
    refreshBalance,
    getToken,
  } = useAuth();
  const [showWalletMenu, setShowWalletMenu] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [isActionLoading, setIsActionLoading] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  const paymentEndpoint = import.meta.env.VITE_AGNICPAY_PAYMENT_URL;
  const webhookEndpoint = import.meta.env.VITE_AGNICPAY_WEBHOOK_URL;
  const hasPaymentAction = Boolean(onRequestPayment || paymentEndpoint);
  const hasWebhookAction = Boolean(onSendWebhook || webhookEndpoint);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setShowWalletMenu(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const shortenAddress = (address: string) => {
    if (!address || address.length < 10) return address;
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  const formatBalance = (balance: string) => {
    const num = parseFloat(balance);
    if (isNaN(num)) return '0.00';
    const formatted = num.toFixed(6);
    return formatted.replace(/(\.\d{2,}?)0+$/, '$1');
  };

  const getActionContext = () => {
    const token = getToken();
    if (!token) return null;
    return { token, wallet, refreshBalance };
  };

  const handleRequestPayment = async () => {
    setActionError(null);
    const context = getActionContext();
    if (!context) {
      setActionError('Not authenticated.');
      return;
    }

    setIsActionLoading(true);
    try {
      if (onRequestPayment) {
        await onRequestPayment(context);
        setShowWalletMenu(false);
        return;
      }

      const amountInput = window.prompt('Enter amount in USDC');
      if (!amountInput) return;
      const amountUsd = Number(amountInput);
      if (!Number.isFinite(amountUsd) || amountUsd <= 0) {
        setActionError('Enter a valid amount.');
        return;
      }
      const memoInput = window.prompt('Memo (optional)');
      const memo = memoInput ? memoInput.trim() : undefined;

      await requestWalletPayment(
        { amountUsd, currency: 'USDC', memo },
        paymentEndpoint
      );
      await refreshBalance();
      setShowWalletMenu(false);
    } catch (err) {
      console.error('Payment request failed:', err);
      setActionError('Payment request failed.');
    } finally {
      setIsActionLoading(false);
    }
  };

  const handleSendWebhook = async () => {
    setActionError(null);
    const context = getActionContext();
    if (!context) {
      setActionError('Not authenticated.');
      return;
    }

    setIsActionLoading(true);
    try {
      if (onSendWebhook) {
        await onSendWebhook(context);
        setShowWalletMenu(false);
        return;
      }

      await sendApiKeyToWebhook(
        { wallet: context.wallet, metadata: { source: 'wallet-widget' } },
        webhookEndpoint
      );
      setShowWalletMenu(false);
    } catch (err) {
      console.error('Webhook send failed:', err);
      setActionError('Webhook send failed.');
    } finally {
      setIsActionLoading(false);
    }
  };

  const containerClassName = ['flex items-center gap-3', className].filter(Boolean).join(' ');

  if (!isAuthenticated) {
    return (
      <div className={containerClassName}>
        <button
          onClick={login}
          disabled={isLoading}
          className="flex items-center gap-3 px-4 py-2 text-sm font-semibold text-white bg-gray-900 rounded-lg hover:bg-gray-700 transition-colors disabled:opacity-60"
        >
          <span className="text-white text-sm font-semibold">Login with</span>
          <span className="flex items-center gap-2">
            <span className="w-7 h-7 grid place-items-center">
              <span className="w-4 h-4 rotate-45 rounded-[1px] bg-[#7ecd33] shadow-[0_4px_12px_rgba(0,0,0,0.35)]" />
            </span>
            <span className="inline-flex items-baseline gap-0.5 text-sm font-semibold">
              <span className="text-white">Agnic</span>
              <span className="text-[#7ecd33]">Pay</span>
            </span>
          </span>
        </button>
      </div>
    );
  }

  return (
    <div className={containerClassName}>
      {isLoadingBalance && !wallet ? (
        <div className="flex items-center gap-2 text-sm text-gray-500">
          <div className="w-3 h-3 border border-gray-400 border-t-transparent rounded-full animate-spin" />
          <span>Loading...</span>
        </div>
      ) : wallet ? (
        <div className="flex items-center gap-2">
          <div className="relative" ref={menuRef}>
            <button
              onClick={() => setShowWalletMenu(!showWalletMenu)}
              className={`flex items-center gap-2 px-3 py-1.5 bg-gray-50 rounded-lg border border-gray-200 hover:bg-gray-100 transition-colors ${isLoadingBalance ? 'opacity-60' : ''}`}
              title="Wallet options"
              disabled={isActionLoading}
            >
              <div className="flex items-center gap-1.5">
                <svg className="w-4 h-4 text-blue-500" viewBox="0 0 24 24" fill="currentColor">
                  <circle cx="12" cy="12" r="10" />
                  <text x="12" y="16" textAnchor="middle" fill="white" fontSize="10" fontWeight="bold">$</text>
                </svg>
                <span className="text-sm font-medium text-gray-800">
                  {formatBalance(wallet.usdcBalance)}
                </span>
              </div>
              {wallet.creditBalance && parseFloat(wallet.creditBalance) > 0 && (
                <>
                  <div className="w-px h-4 bg-gray-300" />
                  <div className="flex items-center gap-1.5" title="Credit Balance">
                    <svg className="w-4 h-4 text-emerald-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span className="text-sm font-medium text-emerald-700">
                      {formatBalance(wallet.creditBalance)}
                    </span>
                    <span className="text-xs text-emerald-600">credit</span>
                  </div>
                </>
              )}
              <div className="w-px h-4 bg-gray-300" />
              <span className="text-xs text-gray-500 font-mono">
                {shortenAddress(wallet.address)}
              </span>
              <span className="text-xs px-1.5 py-0.5 bg-blue-100 text-blue-700 rounded capitalize">
                {wallet.network.replace('-', ' ')}
              </span>
              {isLoadingBalance && (
                <div className="w-3 h-3 border border-gray-400 border-t-transparent rounded-full animate-spin" />
              )}
              <svg className={`w-3 h-3 text-gray-400 transition-transform ${showWalletMenu ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
              </svg>
            </button>

            {showWalletMenu && (
              <div className="absolute right-0 mt-2 w-64 max-w-[calc(100vw-2rem)] bg-white rounded-lg shadow-lg border border-gray-200 py-1 z-50">
                {actionError && (
                  <div className="px-4 py-2 text-xs text-red-600">
                    {actionError}
                  </div>
                )}
                <a
                  href="https://app.agnicpay.xyz/"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                  onClick={() => setShowWalletMenu(false)}
                >
                  <svg className="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                  </svg>
                  Fund your wallet
                  <svg className="w-3 h-3 text-gray-400 ml-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                </a>
                <a
                  href="https://app.agnicpay.xyz/wallet/transactions"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                  onClick={() => setShowWalletMenu(false)}
                >
                  <svg className="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
                  </svg>
                  See your transactions
                  <svg className="w-3 h-3 text-gray-400 ml-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                </a>
                {(hasPaymentAction || hasWebhookAction) && (
                  <div className="my-1 border-t border-gray-200" />
                )}
                {hasPaymentAction && (
                  <button
                    type="button"
                    onClick={handleRequestPayment}
                    disabled={isActionLoading}
                    className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-60"
                  >
                    <svg className="w-4 h-4 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8V6m0 10v2m9-6a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Request payment
                  </button>
                )}
                {hasWebhookAction && (
                  <button
                    type="button"
                    onClick={handleSendWebhook}
                    disabled={isActionLoading}
                    className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-60"
                  >
                    <svg className="w-4 h-4 text-orange-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 8h10M7 12h10m-6 4h6M5 6a2 2 0 012-2h10a2 2 0 012 2v12a2 2 0 01-2 2H7l-4 4V6z" />
                    </svg>
                    Send API key to webhook
                  </button>
                )}
              </div>
            )}
          </div>
          <button
            onClick={logout}
            className="p-2 text-gray-400 hover:text-red-500 transition-colors"
            title="Sign out"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
          </button>
        </div>
      ) : (
        <button
          onClick={logout}
          className="text-sm text-gray-500 hover:text-red-500 transition-colors"
        >
          Sign out
        </button>
      )}
    </div>
  );
};

export default WalletWidget;
