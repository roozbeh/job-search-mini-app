// API base URL - use environment variable in production, fallback to proxy in development
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '';

// Helper function to get full API URL
export function getApiUrl(endpoint: string): string {
  if (API_BASE_URL) {
    // Production: use full URL from environment variable
    return `${API_BASE_URL}${endpoint}`;
  }
  // Development: use relative URL (will be proxied by Vite)
  return endpoint;
}

