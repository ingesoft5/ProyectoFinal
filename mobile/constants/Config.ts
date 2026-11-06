/**
 * Global Configuration for CircleGuard Mobile.
 *
 * - Web build (Docker image): every service goes through the nginx of the same origin,
 *   at /api/<service>/..., so the same image works in dev, stage and prod.
 * - Native app or `expo start`: each service on its local port.
 * - EXPO_PUBLIC_API_URL (e.g. http://localhost) forces the /api/<service> scheme on another host.
 */
import { Platform } from 'react-native';

const API_URL_OVERRIDE = process.env.EXPO_PUBLIC_API_URL;
const IS_WEB_BUILD = Platform.OS === 'web' && process.env.NODE_ENV === 'production';

function serviceUrl(service: string, localPort: number): string {
  if (API_URL_OVERRIDE) return `${API_URL_OVERRIDE}/api/${service}`;
  if (IS_WEB_BUILD) return `/api/${service}`;
  return `http://localhost:${localPort}`;
}

export const AUTH_BASE_URL = serviceUrl('auth', 8180); // Auth Service
export const DASHBOARD_BASE_URL = serviceUrl('dashboard', 8084); // Dashboard Service
export const FILE_BASE_URL = serviceUrl('file', 8085); // File Service
export const FORM_BASE_URL = serviceUrl('form', 8086); // Form Service
export const GATEWAY_BASE_URL = serviceUrl('gateway', 8087); // Gateway Service
export const IDENTITY_BASE_URL = serviceUrl('identity', 8083); // Identity Service
export const NOTIFICATION_BASE_URL = serviceUrl('notification', 8082); // Notification Service
export const PROMOTION_BASE_URL = serviceUrl('promotion', 8088); // Promotion Service
