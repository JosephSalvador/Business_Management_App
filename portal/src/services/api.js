// Jolinx Back-Office Portal - Central API Client & Offline Fallbacks

const STORAGE_KEY_TOKEN = 'jlx_admin_token';
const STORAGE_KEY_USER = 'jlx_admin_user';
const STORAGE_KEY_API_URL = 'jlx_admin_api_url';

const DEFAULT_API_URL = import.meta.env.VITE_API_BASE_URL ||
  (typeof window !== 'undefined' && window.location.hostname.includes('localhost')
    ? 'http://localhost:5000'
    : 'https://jolinx-api-staging.kindsky-ea584b9f.centralindia.azurecontainerapps.io');

export const getApiBaseUrl = () => {
  return localStorage.getItem(STORAGE_KEY_API_URL) || DEFAULT_API_URL;
};

export const setApiBaseUrl = (url) => {
  if (url) {
    localStorage.setItem(STORAGE_KEY_API_URL, url.trim().replace(/\/+$/, ''));
  } else {
    localStorage.removeItem(STORAGE_KEY_API_URL);
  }
};

export const getAuthToken = () => {
  return localStorage.getItem(STORAGE_KEY_TOKEN) || '';
};

export const getStoredUser = () => {
  try {
    const raw = localStorage.getItem(STORAGE_KEY_USER);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
};

export const setAuthSession = (token, user) => {
  if (token) {
    localStorage.setItem(STORAGE_KEY_TOKEN, token);
  } else {
    localStorage.removeItem(STORAGE_KEY_TOKEN);
  }
  if (user) {
    localStorage.setItem(STORAGE_KEY_USER, JSON.stringify(user));
  } else {
    localStorage.removeItem(STORAGE_KEY_USER);
  }
};

export const clearAuthSession = () => {
  localStorage.removeItem(STORAGE_KEY_TOKEN);
  localStorage.removeItem(STORAGE_KEY_USER);
};

// Central fetch helper with automatic JWT injection
async function request(endpoint, options = {}) {
  const baseUrl = getApiBaseUrl();
  const token = getAuthToken();

  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...(options.headers || {}),
  };

  const url = `${baseUrl}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`;

  try {
    const res = await fetch(url, {
      ...options,
      headers,
    });

    if (res.status === 401) {
      console.warn('Unauthorized admin request to:', endpoint);
      clearAuthSession();
      if (typeof window !== 'undefined') {
        window.dispatchEvent(new CustomEvent('jlx:unauthorized'));
      }
    }

    const contentType = res.headers.get('content-type') || '';
    let data = null;
    if (contentType.includes('application/json')) {
      data = await res.json();
    } else {
      data = await res.text();
    }

    if (!res.ok) {
      const errMsg = (data && data.error) || (data && data.message) || (data && data.title) || `Request failed with status ${res.status}`;
      const err = new Error(errMsg);
      err.status = res.status;
      err.data = data;
      throw err;
    }

    return data;
  } catch (err) {
    console.error(`API Error [${endpoint}]:`, err);
    throw err;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH & PLATFORM IDENTITY
// ─────────────────────────────────────────────────────────────────────────────

export async function loginOperator(identifier, password) {
  const data = await request('/api/v1/auth/login', {
    method: 'POST',
    body: JSON.stringify({ identifier: (identifier || '').trim(), password }),
  });

  const authResponse = data.tokens || data;
  const token = authResponse.accessToken || authResponse.token;
  const user = authResponse.user || data.user || {
    email: data.email || identifier,
    platformRole: data.platformRole || (identifier.toLowerCase().includes('admin') || identifier.toLowerCase().includes('joberthix') ? 'PlatformSuperAdmin' : 'PlatformStaff')
  };

  if (!token) {
    throw new Error(data.message || 'Haikupokea token ya uthibitisho kutoka kwa seva.');
  }

  setAuthSession(token, user);
  return { token, user };
}

export async function getCurrentOperator() {
  try {
    const token = getAuthToken();
    if (!token) return null;

    const data = await request('/api/v1/users/me');
    if (data) {
      setAuthSession(token, data);
    }
    return data;
  } catch (err) {
    if (err.status === 401) {
      clearAuthSession();
      return null;
    }
    return getStoredUser();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLEET MANAGEMENT APIS
// ─────────────────────────────────────────────────────────────────────────────

export async function getFleetSummary() {
  return request('/api/v1/admin/fleet/summary');
}

export async function listFleetTenants({ search = '', status = '', health = '', page = 1, pageSize = 20 } = {}) {
  const params = new URLSearchParams();
  if (search) params.append('search', search);
  if (status) params.append('status', status);
  if (health) params.append('health', health);
  params.append('page', page);
  params.append('pageSize', pageSize);

  return request(`/api/v1/admin/fleet/tenants?${params.toString()}`);
}

export async function getTenantAdminDetail(tenantId) {
  return request(`/api/v1/admin/fleet/tenants/${tenantId}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// OMNI-TENANT CATALOG & PRODUCTS APIS
// ─────────────────────────────────────────────────────────────────────────────

export async function listTenantProducts(tenantId, { search = '', lowStockOnly = false, page = 1, pageSize = 50 } = {}) {
  const params = new URLSearchParams();
  if (search) params.append('search', search);
  if (lowStockOnly) params.append('lowStockOnly', 'true');
  params.append('page', page);
  params.append('pageSize', pageSize);

  return request(`/api/v1/admin/tenants/${tenantId}/products?${params.toString()}`);
}

export async function updateTenantProduct(tenantId, productId, payload) {
  return request(`/api/v1/admin/tenants/${tenantId}/products/${productId}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  });
}

export async function adjustTenantStock(tenantId, productId, newStockQuantity, reason = 'Operator Adjustment') {
  return request(`/api/v1/admin/tenants/${tenantId}/products/${productId}/stock`, {
    method: 'POST',
    body: JSON.stringify({ newStockQuantity: Number(newStockQuantity), reason }),
  });
}

export async function seedStarterCatalog(tenantId, templateType) {
  return request(`/api/v1/admin/tenants/${tenantId}/seed-starter-catalog`, {
    method: 'POST',
    body: JSON.stringify({ templateType }),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// OMNI-TENANT SALES & POS APIS
// ─────────────────────────────────────────────────────────────────────────────

export async function listTenantSales(tenantId, { search = '', startDate = '', endDate = '', page = 1, pageSize = 25 } = {}) {
  const params = new URLSearchParams();
  if (search) params.append('search', search);
  if (startDate) params.append('from', startDate);
  if (endDate) params.append('to', endDate);
  params.append('page', page);
  params.append('pageSize', pageSize);

  return request(`/api/v1/admin/tenants/${tenantId}/sales?${params.toString()}`);
}

export async function getTenantSaleDetail(tenantId, saleId) {
  return request(`/api/v1/admin/tenants/${tenantId}/sales/${saleId}`);
}

export async function voidTenantSale(tenantId, saleId, reason = 'Platform Operator Cancellation') {
  return request(`/api/v1/admin/tenants/${tenantId}/sales/${saleId}/void`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  });
}

export async function listTenantCashSessions(tenantId, { page = 1, pageSize = 20 } = {}) {
  const params = new URLSearchParams({ page, pageSize });
  return request(`/api/v1/admin/tenants/${tenantId}/cash-sessions?${params.toString()}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// OMNI-TENANT INVOICES APIS
// ─────────────────────────────────────────────────────────────────────────────

export async function listTenantInvoices(tenantId, { search = '', status = '', page = 1, pageSize = 25 } = {}) {
  const params = new URLSearchParams();
  if (search) params.append('search', search);
  if (status) params.append('status', status);
  params.append('page', page);
  params.append('pageSize', pageSize);

  return request(`/api/v1/admin/tenants/${tenantId}/invoices?${params.toString()}`);
}

export async function updateTenantInvoiceStatus(tenantId, invoiceId, newStatus) {
  return request(`/api/v1/admin/tenants/${tenantId}/invoices/${invoiceId}/status`, {
    method: 'PUT',
    body: JSON.stringify({ newStatus }),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPERSONATION & SUPPORT MODE
// ─────────────────────────────────────────────────────────────────────────────

export async function impersonateTenant(tenantId, reason = 'Platform Admin Support Session') {
  return request(`/api/v1/admin/tenants/${tenantId}/impersonate`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// BILLING & SUBSCRIPTIONS
// ─────────────────────────────────────────────────────────────────────────────

export async function extendTenantTrial(tenantId, days = 14) {
  return request(`/api/v1/admin/billing/tenants/${tenantId}/extend-trial`, {
    method: 'POST',
    body: JSON.stringify({ days }),
  });
}

export async function directActivateTenant(tenantId, months = 1, planCode = 'Pro', referenceNote = 'Direct Backoffice Activation') {
  return request(`/api/v1/admin/billing/tenants/${tenantId}/direct-activate`, {
    method: 'POST',
    body: JSON.stringify({ months, planCode, referenceNote }),
  });
}

export async function updateTenantFeatures(tenantId, features = {}) {
  return request(`/api/v1/admin/tenants/${tenantId}/features`, {
    method: 'PUT',
    body: JSON.stringify({ features }),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PLATFORM TEAM MANAGEMENT (SUPER ADMIN ONLY)
// ─────────────────────────────────────────────────────────────────────────────

export async function listPlatformTeam() {
  return request('/api/v1/admin/platform-team');
}

export async function assignPlatformRole(email, role = 'PlatformStaff') {
  return request('/api/v1/admin/platform-team', {
    method: 'POST',
    body: JSON.stringify({ email, role }),
  });
}

export async function revokePlatformRole(operatorId) {
  return request(`/api/v1/admin/platform-team/${operatorId}`, {
    method: 'DELETE',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANS & PACKAGES MANAGEMENT (CONTROL PLANE)
// ─────────────────────────────────────────────────────────────────────────────

export async function listAllPlansAdmin() {
  return request('/api/v1/admin/billing/plans');
}

export async function createPlanAdmin(payload) {
  return request('/api/v1/admin/billing/plans', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function updatePlanAdmin(code, payload) {
  return request(`/api/v1/admin/billing/plans/${code}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// VOUCHER MACHINE (CONTROL PLANE)
// ─────────────────────────────────────────────────────────────────────────────

export async function listVouchersAdmin({ page = 1, pageSize = 50, status = '' } = {}) {
  const params = new URLSearchParams();
  params.append('page', page);
  params.append('pageSize', pageSize);
  if (status) params.append('status', status);
  return request(`/api/v1/admin/billing/vouchers?${params.toString()}`);
}

export async function issueVouchersAdmin({ count = 1, valueDays = 30, planCode = 'Pro', targetTenantId = null, expiresAtUtc = null }) {
  return request('/api/v1/admin/billing/vouchers/issue', {
    method: 'POST',
    body: JSON.stringify({
      count: Number(count),
      valueDays: Number(valueDays),
      planCode: planCode || null,
      targetTenantId: targetTenantId || null,
      expiresAtUtc: expiresAtUtc || null,
    }),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT INSTRUCTIONS (CONTROL PLANE)
// ─────────────────────────────────────────────────────────────────────────────

export async function getPaymentInstructionsAdmin() {
  return request('/api/v1/admin/billing/payment-instructions');
}

export async function updatePaymentInstructionsAdmin(payload) {
  return request('/api/v1/admin/billing/payment-instructions', {
    method: 'PUT',
    body: JSON.stringify({
      mpesaTill: payload.mpesaTill || '',
      airtelMoney: payload.airtelMoney || '',
      bankName: payload.bankName || '',
      bankAccountNumber: payload.bankAccountNumber || '',
      bankAccountName: payload.bankAccountName || '',
      whatsAppContact: payload.whatsAppContact || '',
      notes: payload.notes || '',
    }),
  });
}

