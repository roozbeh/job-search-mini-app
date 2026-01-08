/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import {
  initiateLogin,
  handleCallback,
  isLoggedIn,
  logout as authLogout,
  isCallbackUrl,
  getAccessToken,
  fetchWalletBalance,
  WalletBalance,
} from './authService';

interface AuthContextType {
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  login: () => Promise<void>;
  logout: () => void;
  getToken: () => string | null;
  wallet: WalletBalance | null;
  isLoadingBalance: boolean;
  refreshBalance: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

interface AuthProviderProps {
  children: ReactNode;
}

export function AuthProvider({ children }: AuthProviderProps) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [wallet, setWallet] = useState<WalletBalance | null>(null);
  const [isLoadingBalance, setIsLoadingBalance] = useState(false);

  const refreshBalance = useCallback(async () => {
    if (!isLoggedIn()) return;

    setIsLoadingBalance(true);
    try {
      const balance = await fetchWalletBalance();
      setWallet(balance);
    } finally {
      setIsLoadingBalance(false);
    }
  }, []);

  useEffect(() => {
    async function checkAuth() {
      if (isCallbackUrl()) {
        setIsLoading(true);
        const result = await handleCallback();

        if (result.success) {
          setIsAuthenticated(true);
          setError(null);
          window.location.href = '/';
          return;
        } else {
          setError(result.error || 'Login failed');
          setIsAuthenticated(false);
          window.location.href = '/';
          return;
        }
      }

      const loggedIn = isLoggedIn();
      setIsAuthenticated(loggedIn);
      setIsLoading(false);

      if (loggedIn) {
        refreshBalance();
      }
    }

    checkAuth();
  }, [refreshBalance]);

  const login = useCallback(async () => {
    setError(null);
    await initiateLogin();
  }, []);

  const logout = useCallback(() => {
    authLogout();
    setIsAuthenticated(false);
    setWallet(null);
    setError(null);
  }, []);

  const getToken = useCallback(() => {
    return getAccessToken();
  }, []);

  const value: AuthContextType = {
    isAuthenticated,
    isLoading,
    error,
    login,
    logout,
    getToken,
    wallet,
    isLoadingBalance,
    refreshBalance,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
