import React, { useState, useEffect, useRef } from 'react';
import {
  Search,
  RefreshCw,
  Plus,
  Copy,
  Check,
  LogOut,
  Menu,
  X,
  ExternalLink,
  Shield,
  Sliders,
} from 'lucide-react';

import TenantDetailConsole from './components/TenantDetailConsole';
import PlatformTeamManager from './components/PlatformTeamManager';
import {
  getFleetSummary,
  listFleetTenants,
  extendTenantTrial,
  directActivateTenant,
  loginOperator,
  getCurrentOperator,
  clearAuthSession,
  getStoredUser,
  getAuthToken,
  getApiBaseUrl,
  listAllPlansAdmin,
  createPlanAdmin,
  updatePlanAdmin,
  listVouchersAdmin,
  issueVouchersAdmin,
  getPaymentInstructionsAdmin,
  updatePaymentInstructionsAdmin,
} from './services/api';
import {
  Button,
  Container,
  PageHeader,
  Breadcrumbs,
  StatusIndicator,
  Badge,
  Alert,
  Modal,
  KeyValueGrid,
  KpiStrip,
} from './ui/primitives';

const ALL_AVAILABLE_FEATURES = [
  {
    key: 'pos.enabled',
    name: 'Point of Sale (POS)',
    desc: 'Offline cashier checkout & receipts',
  },
  {
    key: 'inventory.enabled',
    name: 'Inventory & Stock',
    desc: 'Real-time stock ledger, movements & alerts',
  },
  {
    key: 'invoicing.enabled',
    name: 'Invoicing & Proforma',
    desc: 'PDF invoices, debtor tracking & payments',
  },
  {
    key: 'credit.enabled',
    name: 'Customer Credit',
    desc: 'Customer debt limits & reminders',
  },
  {
    key: 'purchasing.enabled',
    name: 'Purchasing & Suppliers',
    desc: 'Supplier purchase orders & accounts payable',
  },
  {
    key: 'accounting.enabled',
    name: 'Accounting & P&L',
    desc: 'Chart of accounts & profit/loss',
  },
  {
    key: 'finance.enabled',
    name: 'Cashbook & Money Accounts',
    desc: 'Till, Bank, M-Pesa drawer reconciliation',
  },
  {
    key: 'crm.enabled',
    name: 'Customer Directory',
    desc: 'Customer contact history & insights',
  },
  {
    key: 'reports.enabled',
    name: 'Reports & Export',
    desc: 'Sales, stock & financial reports export',
  },
  {
    key: 'multi-branch.enabled',
    name: 'Multi-Branch & Transfers',
    desc: 'Manage 2+ physical shops & warehouses',
  },
  {
    key: 'pricing.enabled',
    name: 'Wholesale & Price Lists',
    desc: 'Tiered wholesale & retail price rules',
  },
];

export default function App() {
  // Navigation & View State
  const [activeTab, setActiveTab] = useState('clients'); // clients | tenant-console | team | packages | vouchers | payment
  const [savedView, setSavedView] = useState('all'); // all | trials | overdue | at-risk
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  // Selected Tenant & Support Mode State
  const [selectedTenant, setSelectedTenant] = useState(null);
  const [tenantSubTab, setTenantSubTab] = useState('overview');
  const [supportReason, setSupportReason] = useState(
    'Customer support & catalog inspection'
  );
  const [enterModalTenant, setEnterModalTenant] = useState(null);
  const [enterReasonInput, setEnterReasonInput] = useState(
    'Customer support & catalog inspection'
  );

  // Split-Panel Quick Preview State
  const [previewTenant, setPreviewTenant] = useState(null);

  // Global TopBar Search (Ctrl+K)
  const [globalQuery, setGlobalQuery] = useState('');
  const [globalDropdownOpen, setGlobalDropdownOpen] = useState(false);
  const globalSearchInputRef = useRef(null);

  // Operator Auth State
  const [currentOperator, setCurrentOperator] = useState(() => getStoredUser());
  const [authToken, setAuthToken] = useState(() => getAuthToken());
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [loginLoading, setLoginLoading] = useState(false);
  const [loginError, setLoginError] = useState(null);

  // Notification Banner
  const [bannerNotice, setBannerNotice] = useState(null);
  const showNotification = (msg) => {
    setBannerNotice(msg);
    setTimeout(() => setBannerNotice(null), 4500);
  };

  // Fleet State (Live Database Data)
  const [fleetSummary, setFleetSummary] = useState(null);
  const [clients, setClients] = useState([]);
  const [fleetLoading, setFleetLoading] = useState(false);
  const [fleetError, setFleetError] = useState(null);
  const [clientSearch, setClientSearch] = useState('');
  const [healthFilter, setHealthFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  const fetchFleet = async () => {
    if (!getAuthToken()) return;
    setFleetLoading(true);
    setFleetError(null);
    try {
      const [summary, tenantsRes] = await Promise.all([
        getFleetSummary().catch(() => null),
        listFleetTenants({
          search: clientSearch,
          status: statusFilter,
          health: healthFilter,
          pageSize: 50,
        }),
      ]);

      if (summary) {
        setFleetSummary(summary);
      }
      if (tenantsRes && Array.isArray(tenantsRes.items)) {
        setClients(tenantsRes.items);
      } else if (Array.isArray(tenantsRes)) {
        setClients(tenantsRes);
      } else {
        setClients([]);
      }
    } catch (err) {
      setFleetError(err.message || 'Failed to load tenants from API server.');
    } finally {
      setFleetLoading(false);
    }
  };

  useEffect(() => {
    if (authToken) {
      fetchFleet();
    }
  }, [authToken, clientSearch, statusFilter, healthFilter]);

  // Keyboard shortcut Ctrl+K / Cmd+K for global search
  useEffect(() => {
    const onKeyDown = (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        globalSearchInputRef.current?.focus();
        setGlobalDropdownOpen(true);
      } else if (e.key === 'Escape') {
        setGlobalDropdownOpen(false);
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  // Global 401 listener
  useEffect(() => {
    const handleUnauthorized = () => {
      clearAuthSession();
      setCurrentOperator(null);
      setAuthToken('');
      showNotification('Your session has expired. Please sign in again.');
    };
    window.addEventListener('jlx:unauthorized', handleUnauthorized);
    return () =>
      window.removeEventListener('jlx:unauthorized', handleUnauthorized);
  }, []);

  // Validate session on mount
  useEffect(() => {
    const token = getAuthToken();
    if (token) {
      getCurrentOperator().then((user) => {
        if (user) {
          setCurrentOperator(user);
          setAuthToken(token);
        } else {
          setCurrentOperator(null);
          setAuthToken('');
        }
      });
    }
  }, []);

  const handleLoginSubmit = async (e) => {
    if (e) e.preventDefault();
    setLoginLoading(true);
    setLoginError(null);
    try {
      const res = await loginOperator(loginEmail, loginPassword);
      setCurrentOperator(res.user);
      setAuthToken(res.token);
      showNotification(
        `Signed in as ${res.user.email} (${
          res.user.platformRole || 'PlatformSuperAdmin'
        })`
      );
      fetchFleet();
    } catch (err) {
      const msg = err.message || 'Invalid operator credentials.';
      setLoginError(msg);
    } finally {
      setLoginLoading(false);
    }
  };

  const handleLogout = () => {
    clearAuthSession();
    setCurrentOperator(null);
    setAuthToken('');
    setClients([]);
    setFleetSummary(null);
    setSelectedTenant(null);
    setPreviewTenant(null);
    showNotification('Signed out of Jolinx Console.');
  };

  const isSuperAdmin =
    !currentOperator?.platformRole ||
    currentOperator?.platformRole === 'PlatformSuperAdmin';

  // Saved sidebar views handler
  const handleSelectSavedView = (view) => {
    setSavedView(view);
    setActiveTab('clients');
    if (view === 'all') {
      setStatusFilter('');
      setHealthFilter('');
    } else if (view === 'trials') {
      setStatusFilter('Trial');
      setHealthFilter('');
    } else if (view === 'overdue') {
      setStatusFilter('Debt');
      setHealthFilter('');
    } else if (view === 'at-risk') {
      setStatusFilter('');
      setHealthFilter('AtRisk');
    }
  };

  // Enter Tenant Workspace (Support Mode)
  const promptEnterTenant = (tenant, initialTab = 'overview') => {
    setEnterModalTenant({ tenant, initialTab });
    setEnterReasonInput(
      supportReason || 'Customer support & catalog inspection'
    );
  };

  const confirmEnterTenant = (e) => {
    if (e) e.preventDefault();
    if (!enterModalTenant) return;
    const { tenant, initialTab } = enterModalTenant;
    setSupportReason(
      enterReasonInput.trim() || 'Customer support & catalog inspection'
    );
    setSelectedTenant(tenant);
    setTenantSubTab(initialTab || 'overview');
    setPreviewTenant(null);
    setEnterModalTenant(null);
    setActiveTab('tenant-console');
  };

  const handleQuickEnterTenant = (tenant, initialTab = 'overview') => {
    setSelectedTenant(tenant);
    setTenantSubTab(initialTab);
    setPreviewTenant(null);
    setActiveTab('tenant-console');
  };

  // Quick Tenant Actions
  const handleQuickExtendTrial = async (tenantId, days) => {
    try {
      await extendTenantTrial(tenantId, days);
      setClients(
        clients.map((c) =>
          c.tenantId === tenantId
            ? {
                ...c,
                trialDaysLeft: (c.trialDaysLeft || 0) + days,
                status: 'Trial',
              }
            : c
        )
      );
      if (previewTenant?.tenantId === tenantId) {
        setPreviewTenant((p) => ({
          ...p,
          trialDaysLeft: (p.trialDaysLeft || 0) + days,
          status: 'Trial',
        }));
      }
      showNotification(`Extended trial by ${days} days.`);
    } catch (err) {
      showNotification(`Failed to extend trial: ${err.message || 'Retry'}`);
    }
  };

  const handleQuickActivate = async (tenantId, months, planCode = 'Pro') => {
    try {
      await directActivateTenant(tenantId, months, planCode);
      const today = new Date();
      today.setDate(today.getDate() + months * 30);
      const dateStr = today.toISOString().split('T')[0];

      setClients(
        clients.map((c) =>
          c.tenantId === tenantId
            ? { ...c, status: 'Active', trialDaysLeft: 0, paidUntil: dateStr }
            : c
        )
      );
      if (previewTenant?.tenantId === tenantId) {
        setPreviewTenant((p) => ({
          ...p,
          status: 'Active',
          trialDaysLeft: 0,
          paidUntil: dateStr,
        }));
      }
      showNotification(
        `Activated subscription for ${months} month(s) until ${dateStr}.`
      );
    } catch (err) {
      showNotification(`Activation failed: ${err.message || 'Retry'}`);
    }
  };

  // ── Plans & Packages State (Live Database Data) ───────────────────
  const [packages, setPackages] = useState([]);
  const [packagesLoading, setPackagesLoading] = useState(false);
  const [packagesError, setPackagesError] = useState(null);
  const [editingPackage, setEditingPackage] = useState(null);
  const [savingPackage, setSavingPackage] = useState(false);
  const [showAddPackageModal, setShowAddPackageModal] = useState(false);
  const [creatingPackage, setCreatingPackage] = useState(false);

  const fetchPackages = async () => {
    if (!getAuthToken()) return;
    setPackagesLoading(true);
    setPackagesError(null);
    try {
      const res = await listAllPlansAdmin();
      if (Array.isArray(res)) {
        setPackages(res);
      } else if (res && Array.isArray(res.items)) {
        setPackages(res.items);
      } else {
        setPackages([]);
      }
    } catch (err) {
      setPackagesError(err.message || 'Failed to load plans from server.');
      setPackages([]);
    } finally {
      setPackagesLoading(false);
    }
  };

  const handleSavePackageEdit = async () => {
    if (!editingPackage) return;
    setSavingPackage(true);
    try {
      await updatePlanAdmin(editingPackage.code, {
        name: editingPackage.name,
        monthlyPrice: Number(editingPackage.monthlyPrice),
        currency: editingPackage.currency || 'TZS',
        featureKeys: editingPackage.featureKeys || [],
        maxBranches: editingPackage.maxBranches
          ? Number(editingPackage.maxBranches)
          : null,
        maxUsers: editingPackage.maxUsers
          ? Number(editingPackage.maxUsers)
          : null,
        maxProducts: editingPackage.maxProducts
          ? Number(editingPackage.maxProducts)
          : null,
        isPackage: Boolean(editingPackage.isPackage),
        isActive: Boolean(editingPackage.isActive),
      });
      showNotification(`Updated plan "${editingPackage.name}".`);
      setEditingPackage(null);
      fetchPackages();
    } catch (err) {
      showNotification(`Failed to update plan: ${err.message || 'Retry'}`);
    } finally {
      setSavingPackage(false);
    }
  };

  const handleCreatePackage = async (e) => {
    e.preventDefault();
    setCreatingPackage(true);
    const form = e.target;
    try {
      const payload = {
        code: form.code.value.trim(),
        name: form.name.value.trim(),
        monthlyPrice: Number(form.monthlyPrice.value),
        currency: 'TZS',
        featureKeys: ['pos.enabled', 'inventory.enabled'],
        maxBranches: form.maxBranches?.value
          ? Number(form.maxBranches.value)
          : null,
        maxUsers: form.maxUsers?.value ? Number(form.maxUsers.value) : null,
        maxProducts: form.maxProducts?.value
          ? Number(form.maxProducts.value)
          : null,
        isPackage: Boolean(form.isPackage?.checked),
      };
      await createPlanAdmin(payload);
      setShowAddPackageModal(false);
      showNotification(`Created plan "${payload.name}".`);
      fetchPackages();
    } catch (err) {
      showNotification(`Failed to create plan: ${err.message || 'Retry'}`);
    } finally {
      setCreatingPackage(false);
    }
  };

  // ── Voucher Machine State (Live Database Data) ────────────────────
  const [vouchers, setVouchers] = useState([]);
  const [vouchersLoading, setVouchersLoading] = useState(false);
  const [vouchersError, setVouchersError] = useState(null);
  const [voucherPage] = useState(1);
  const [generatingVoucher, setGeneratingVoucher] = useState(false);
  const [newVoucherDays, setNewVoucherDays] = useState(30);
  const [newVoucherPlan, setNewVoucherPlan] = useState('Pro');
  const [newVoucherTarget, setNewVoucherTarget] = useState('');
  const [lastGeneratedVoucher, setLastGeneratedVoucher] = useState(null);

  const fetchVouchers = async () => {
    if (!getAuthToken()) return;
    setVouchersLoading(true);
    setVouchersError(null);
    try {
      const res = await listVouchersAdmin({ page: voucherPage, pageSize: 50 });
      if (Array.isArray(res)) {
        setVouchers(res);
      } else if (res && Array.isArray(res.items)) {
        setVouchers(res.items);
      } else {
        setVouchers([]);
      }
    } catch (err) {
      setVouchersError(err.message || 'Failed to load vouchers from server.');
      setVouchers([]);
    } finally {
      setVouchersLoading(false);
    }
  };

  const handleGenerateVoucher = async () => {
    setGeneratingVoucher(true);
    try {
      const res = await issueVouchersAdmin({
        count: 1,
        valueDays: Number(newVoucherDays),
        planCode: newVoucherPlan,
        targetTenantId: newVoucherTarget?.trim() || null,
      });

      const generatedCode = Array.isArray(res)
        ? res[0]
        : res?.codes?.[0] || res?.code;
      if (generatedCode) {
        const newVoucher = {
          code: generatedCode,
          valueDays: Number(newVoucherDays),
          status: 'Issued',
          planCode: newVoucherPlan,
          targetTenant: newVoucherTarget?.trim() || 'Unrestricted (Any tenant)',
          createdAt: new Date().toISOString(),
        };
        setLastGeneratedVoucher(newVoucher);
        showNotification(`Issued voucher ${generatedCode}.`);
        fetchVouchers();
      } else {
        showNotification('Voucher issued on server.');
        fetchVouchers();
      }
    } catch (err) {
      showNotification(`Failed to issue voucher: ${err.message || 'Retry'}`);
    } finally {
      setGeneratingVoucher(false);
    }
  };

  const handleCopyWhatsAppMessage = (voucher) => {
    const msg =
      `Hello! Your Jolinx Business OS subscription voucher is ready.\n\n` +
      `Voucher Code: *${voucher.code}*\n` +
      `Duration: *${voucher.valueDays} days (${voucher.planCode || 'Pro'})*\n\n` +
      `Open the Jolinx app and enter this code under Billing & Subscription to activate your workspace immediately.`;
    navigator.clipboard.writeText(msg);
    showNotification('Copied voucher message to clipboard.');
  };

  // ── Payment Accounts State (Live Database Data) ───────────────────
  const [paymentAccounts, setPaymentAccounts] = useState({
    mpesaTill: '',
    airtelMoney: '',
    bankName: '',
    bankAccountNumber: '',
    bankAccountName: '',
    whatsAppContact: '',
    notes: '',
  });
  const [paymentLoading, setPaymentLoading] = useState(false);
  const [paymentSaving, setPaymentSaving] = useState(false);
  const [paymentError, setPaymentError] = useState(null);

  const fetchPaymentAccounts = async () => {
    if (!getAuthToken()) return;
    setPaymentLoading(true);
    setPaymentError(null);
    try {
      const res = await getPaymentInstructionsAdmin();
      if (res) {
        setPaymentAccounts({
          mpesaTill: res.mpesaTill || '',
          airtelMoney: res.airtelMoney || '',
          bankName: res.bankName || '',
          bankAccountNumber: res.bankAccountNumber || '',
          bankAccountName: res.bankAccountName || '',
          whatsAppContact: res.whatsAppContact || '',
          notes: res.notes || '',
        });
      }
    } catch (err) {
      setPaymentError(
        err.message || 'Failed to load payment instructions from server.'
      );
    } finally {
      setPaymentLoading(false);
    }
  };

  const handleSavePaymentAccounts = async () => {
    setPaymentSaving(true);
    try {
      await updatePaymentInstructionsAdmin(paymentAccounts);
      showNotification(
        'Saved payment instructions. All client apps will display the updated details.'
      );
    } catch (err) {
      showNotification(`Failed to save: ${err.message || 'Retry'}`);
    } finally {
      setPaymentSaving(false);
    }
  };

  useEffect(() => {
    if (!authToken) return;
    if (activeTab === 'packages') {
      fetchPackages();
    } else if (activeTab === 'vouchers') {
      fetchVouchers();
      if (packages.length === 0) fetchPackages();
    } else if (activeTab === 'payment') {
      fetchPaymentAccounts();
    }
  }, [authToken, activeTab]);

  const apiHost = (() => {
    try {
      return new URL(getApiBaseUrl()).host;
    } catch {
      return getApiBaseUrl();
    }
  })();

  const isStaging =
    apiHost.includes('staging') ||
    window.location.hostname.includes('staging') ||
    window.location.hostname === 'localhost';

  // ─────────────────────────────────────────────────────────────────
  // SIGN-IN GATE (T4: Official AWS Console-style Sign-In)
  // ─────────────────────────────────────────────────────────────────
  if (!authToken || !currentOperator) {
    return (
      <div className="min-h-screen bg-[#F2F3F3] flex flex-col justify-between font-sans text-[#16191F]">
        {/* Top Squid Ink Bar */}
        <header className="bg-[#232F3E] text-white h-12 px-5 flex items-center justify-between border-b border-[#3C495A]">
          <div className="flex items-center gap-2.5">
            <div className="w-3 h-5 bg-[#FF9900] rounded-[2px]" />
            <span className="font-bold text-[15px] tracking-tight">
              Jolinx Console
            </span>
            <span className="text-[11px] text-[#D5DBDB] border-l border-[#3C495A] pl-2.5">
              Platform Administration
            </span>
          </div>
          <div className="flex items-center gap-2">
            <span className="px-2 py-0.5 rounded-[2px] bg-[#FF9900] text-[#16191F] text-[11px] font-bold uppercase">
              {isStaging ? 'Staging' : 'Production'}
            </span>
          </div>
        </header>

        {/* Centered Sign-In Card */}
        <div className="flex-1 flex items-center justify-center p-4">
          <div className="bg-white border border-[#D5DBDB] rounded-[8px] shadow-sm max-w-md w-full p-6">
            <div className="border-b border-[#E9EBED] pb-3.5 mb-4">
              <h1 className="text-[20px] font-bold text-[#16191F]">
                Sign in to Jolinx Console
              </h1>
              <p className="text-[12px] text-[#5F6B7A] mt-0.5">
                Authenticate with your PlatformSuperAdmin or PlatformStaff credentials.
              </p>
            </div>

            {loginError && (
              <div className="mb-4">
                <Alert type="error" title="Authentication failed">
                  {loginError}
                </Alert>
              </div>
            )}

            <form onSubmit={handleLoginSubmit} className="space-y-4">
              <div>
                <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                  Operator email or username
                </label>
                <input
                  type="text"
                  required
                  autoFocus
                  placeholder="admin@acme.local"
                  value={loginEmail}
                  onChange={(e) => setLoginEmail(e.target.value)}
                  className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3] focus:ring-1 focus:ring-[#0972D3]"
                />
              </div>

              <div>
                <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                  Password
                </label>
                <input
                  type="password"
                  required
                  placeholder="••••••••"
                  value={loginPassword}
                  onChange={(e) => setLoginPassword(e.target.value)}
                  className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3] focus:ring-1 focus:ring-[#0972D3]"
                />
              </div>

              <div className="pt-1">
                <Button
                  type="submit"
                  variant="primary"
                  loading={loginLoading}
                  className="w-full py-2"
                >
                  Sign in
                </Button>
              </div>
            </form>

            {isStaging && (
              <div className="mt-5 pt-4 border-t border-[#E9EBED]">
                <div className="flex items-center justify-between text-[12px] text-[#5F6B7A]">
                  <span>Staging environment quick-fill:</span>
                  <button
                    type="button"
                    onClick={() => {
                      setLoginEmail('admin@acme.local');
                      setLoginPassword('Admin@12345');
                    }}
                    className="text-[#0972D3] hover:underline font-medium"
                  >
                    Fill default staging admin
                  </button>
                </div>
                <div className="mt-1.5 text-[11px] font-mono text-[#5F6B7A] truncate">
                  API: {apiHost}
                </div>
              </div>
            )}
          </div>
        </div>

        <footer className="py-3 px-5 text-center text-[11px] text-[#5F6B7A] border-t border-[#D5DBDB] bg-white">
          Jolinx Business OS · Multi-Tenant Control Plane · Authorized Platform Personnel Only
        </footer>
      </div>
    );
  }

  // Global search matching tenants
  const globalSearchMatches = globalQuery.trim()
    ? clients
        .filter((c) => {
          const q = globalQuery.toLowerCase();
          return (
            (c.name || '').toLowerCase().includes(q) ||
            (c.ownerPhone || c.phone || '').toLowerCase().includes(q) ||
            (c.ownerEmail || '').toLowerCase().includes(q) ||
            (c.tenantId || '').toLowerCase().includes(q)
          );
        })
        .slice(0, 8)
    : [];

  // Breadcrumb calculation
  const getBreadcrumbs = () => {
    const base = [
      {
        label: 'Console',
        onClick: () => {
          setActiveTab('clients');
          setSelectedTenant(null);
        },
      },
    ];
    if (activeTab === 'clients') {
      base.push({ label: 'Tenants' });
    } else if (activeTab === 'tenant-console' && selectedTenant) {
      base.push({
        label: 'Tenants',
        onClick: () => setActiveTab('clients'),
      });
      base.push({ label: selectedTenant.name || 'Tenant' });
    } else if (activeTab === 'packages') {
      base.push({ label: 'Billing' });
      base.push({ label: 'Plans & packages' });
    } else if (activeTab === 'vouchers') {
      base.push({ label: 'Billing' });
      base.push({ label: 'Vouchers' });
    } else if (activeTab === 'payment') {
      base.push({ label: 'Billing' });
      base.push({ label: 'Payment accounts' });
    } else if (activeTab === 'team') {
      base.push({ label: 'Platform' });
      base.push({ label: 'Team & IAM roles' });
    }
    return base;
  };

  // KPI Metrics Calculation
  const totalTenantsCount =
    fleetSummary?.totalTenants ?? clients.length ?? 0;
  const activePaidCount =
    fleetSummary?.activeSubscriptions ??
    clients.filter(
      (c) =>
        (c.status || '').toLowerCase() === 'active' ||
        (c.status || '').toLowerCase() === 'paid'
    ).length;
  const trialCount =
    fleetSummary?.trialSubscriptions ??
    clients.filter((c) => (c.status || '').toLowerCase() === 'trial').length;
  const overdueCount =
    fleetSummary?.overdueSubscriptions ??
    fleetSummary?.debtSubscriptions ??
    clients.filter(
      (c) =>
        (c.status || '').toLowerCase() === 'debt' ||
        (c.status || '').toLowerCase() === 'overdue'
    ).length;
  const estimatedMrr =
    fleetSummary?.estimatedMrr ?? fleetSummary?.mrr ?? 0;

  return (
    <div className="min-h-screen bg-[#F2F3F3] flex flex-col font-sans text-[#16191F]">
      {/* ── TOP GLOBAL NAVIGATION BAR (AWS Squid Ink #232F3E) ── */}
      <header className="bg-[#232F3E] text-white h-12 px-4 flex items-center justify-between gap-4 sticky top-0 z-40 border-b border-[#3C495A]">
        {/* Left: Brand & Mobile Menu Toggle */}
        <div className="flex items-center gap-3 shrink-0">
          <button
            type="button"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="lg:hidden p-1 text-[#D5DBDB] hover:text-white"
          >
            {mobileMenuOpen ? (
              <X className="w-5 h-5" />
            ) : (
              <Menu className="w-5 h-5" />
            )}
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('clients')}
            className="flex items-center gap-2 text-left"
          >
            <div className="w-2.5 h-5 bg-[#FF9900] rounded-[1px]" />
            <span className="font-bold text-[15px] tracking-tight text-white">
              Jolinx Console
            </span>
          </button>
        </div>

        {/* Center: Global Tenant Search (Ctrl+K) */}
        <div className="relative flex-1 max-w-xl">
          <div className="relative flex items-center">
            <Search className="w-3.5 h-3.5 text-[#879596] absolute left-3 pointer-events-none" />
            <input
              ref={globalSearchInputRef}
              type="text"
              placeholder="Search tenants by name, phone, email, or ID (Ctrl+K)"
              value={globalQuery}
              onFocus={() => setGlobalDropdownOpen(true)}
              onBlur={() => setTimeout(() => setGlobalDropdownOpen(false), 180)}
              onChange={(e) => {
                setGlobalQuery(e.target.value);
                setGlobalDropdownOpen(true);
              }}
              className="w-full bg-[#16191F] text-white placeholder-[#879596] text-[13px] pl-8 pr-16 py-1 rounded-[4px] border border-[#5F6B7A] focus:outline-none focus:border-[#0972D3] focus:ring-1 focus:ring-[#0972D3]"
            />
            <span className="hidden sm:inline-block absolute right-2.5 text-[10px] font-mono text-[#879596] border border-[#3C495A] px-1.5 py-0.2 rounded-[2px]">
              Ctrl+K
            </span>
          </div>

          {/* Global Search Results Popover */}
          {globalDropdownOpen && globalQuery.trim() && (
            <div className="absolute left-0 right-0 mt-1 bg-white text-[#16191F] border border-[#D5DBDB] rounded-[4px] shadow-lg overflow-hidden z-50">
              <div className="px-3 py-1.5 bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase text-[#5F6B7A]">
                Matching tenants ({globalSearchMatches.length})
              </div>
              {globalSearchMatches.length === 0 ? (
                <div className="px-4 py-4 text-[12px] text-[#5F6B7A]">
                  No tenants matching "{globalQuery}".
                </div>
              ) : (
                <div className="divide-y divide-[#E9EBED] max-h-72 overflow-y-auto">
                  {globalSearchMatches.map((t) => (
                    <button
                      key={t.tenantId}
                      type="button"
                      onMouseDown={() => {
                        setGlobalQuery('');
                        setGlobalDropdownOpen(false);
                        handleQuickEnterTenant(t, 'overview');
                      }}
                      className="w-full px-3.5 py-2 text-left hover:bg-[#F1F8FF] flex items-center justify-between gap-2 text-[13px]"
                    >
                      <div>
                        <div className="font-semibold text-[#0972D3]">
                          {t.name}
                        </div>
                        <div className="text-[11px] text-[#5F6B7A]">
                          {t.ownerPhone || t.phone || t.ownerEmail || t.tenantId}
                        </div>
                      </div>
                      <Badge color="blue">{t.planCode || 'Pro'}</Badge>
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Right: Environment Badge & Operator Identity */}
        <div className="flex items-center gap-3 shrink-0 text-[12px]">
          <span
            className={`px-2 py-0.5 rounded-[2px] font-bold uppercase text-[11px] ${
              isStaging
                ? 'bg-[#FF9900] text-[#16191F]'
                : 'bg-[#037F0C] text-white'
            }`}
            title={`Connected API: ${getApiBaseUrl()}`}
          >
            {isStaging ? 'Staging' : 'Prod'}
          </span>

          <div className="hidden md:flex items-center gap-2 border-l border-[#3C495A] pl-3 text-[#D5DBDB]">
            <Shield className="w-3.5 h-3.5 text-[#FF9900]" />
            <span className="font-medium text-white">
              {currentOperator?.email}
            </span>
            <span className="text-[11px] text-[#879596]">
              · {currentOperator?.platformRole || 'PlatformSuperAdmin'}
            </span>
          </div>

          <button
            type="button"
            onClick={handleLogout}
            title="Sign out"
            className="text-[#D5DBDB] hover:text-white px-2 py-1 rounded-[4px] hover:bg-[#314154] flex items-center gap-1 text-[12px]"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Sign out</span>
          </button>
        </div>
      </header>

      {/* ── BODY SHELL: LEFT SIDEBAR + MAIN CANVAS ── */}
      <div className="flex-1 flex min-h-0">
        {/* Left Navigation Sidebar */}
        <aside
          className={`${
            mobileMenuOpen ? 'block fixed inset-y-12 left-0 z-30' : 'hidden'
          } lg:block w-60 bg-white border-r border-[#D5DBDB] shrink-0 overflow-y-auto`}
        >
          <div className="py-4 px-3 space-y-5 text-[13px]">
            {/* Section: Tenants */}
            <div>
              <div className="px-2.5 mb-1.5 text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                Tenants
              </div>
              <ul className="space-y-0.5">
                {[
                  { id: 'all', label: 'All tenants' },
                  { id: 'trials', label: 'Trials expiring' },
                  { id: 'overdue', label: 'Overdue / debt' },
                  { id: 'at-risk', label: 'At risk' },
                ].map((item) => {
                  const active =
                    activeTab === 'clients' && savedView === item.id;
                  return (
                    <li key={item.id}>
                      <button
                        type="button"
                        onClick={() => {
                          handleSelectSavedView(item.id);
                          setMobileMenuOpen(false);
                        }}
                        className={`w-full text-left px-2.5 py-1.5 rounded-[4px] border-l-4 transition-colors ${
                          active
                            ? 'border-[#0972D3] bg-[#F1F8FF] text-[#0972D3] font-semibold'
                            : 'border-transparent text-[#16191F] hover:bg-[#F2F3F3]'
                        }`}
                      >
                        {item.label}
                      </button>
                    </li>
                  );
                })}

                {selectedTenant && (
                  <li className="pt-1">
                    <button
                      type="button"
                      onClick={() => {
                        setActiveTab('tenant-console');
                        setMobileMenuOpen(false);
                      }}
                      className={`w-full text-left px-2.5 py-1.5 rounded-[4px] border-l-4 truncate transition-colors ${
                        activeTab === 'tenant-console'
                          ? 'border-[#0972D3] bg-[#F1F8FF] text-[#0972D3] font-semibold'
                          : 'border-transparent text-[#5F6B7A] hover:bg-[#F2F3F3]'
                      }`}
                      title={selectedTenant.name}
                    >
                      ↳ {selectedTenant.name}
                    </button>
                  </li>
                )}
              </ul>
            </div>

            {/* Section: Billing */}
            <div>
              <div className="px-2.5 mb-1.5 text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                Billing & Catalog
              </div>
              <ul className="space-y-0.5">
                {[
                  { id: 'packages', label: 'Plans & packages' },
                  { id: 'vouchers', label: 'Vouchers' },
                  { id: 'payment', label: 'Payment accounts' },
                ].map((item) => {
                  const active = activeTab === item.id;
                  return (
                    <li key={item.id}>
                      <button
                        type="button"
                        onClick={() => {
                          setActiveTab(item.id);
                          setMobileMenuOpen(false);
                        }}
                        className={`w-full text-left px-2.5 py-1.5 rounded-[4px] border-l-4 transition-colors ${
                          active
                            ? 'border-[#0972D3] bg-[#F1F8FF] text-[#0972D3] font-semibold'
                            : 'border-transparent text-[#16191F] hover:bg-[#F2F3F3]'
                        }`}
                      >
                        {item.label}
                      </button>
                    </li>
                  );
                })}
              </ul>
            </div>

            {/* Section: Platform IAM */}
            {isSuperAdmin && (
              <div>
                <div className="px-2.5 mb-1.5 text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                  Platform Governance
                </div>
                <ul className="space-y-0.5">
                  <li>
                    <button
                      type="button"
                      onClick={() => {
                        setActiveTab('team');
                        setMobileMenuOpen(false);
                      }}
                      className={`w-full text-left px-2.5 py-1.5 rounded-[4px] border-l-4 transition-colors ${
                        activeTab === 'team'
                          ? 'border-[#0972D3] bg-[#F1F8FF] text-[#0972D3] font-semibold'
                          : 'border-transparent text-[#16191F] hover:bg-[#F2F3F3]'
                      }`}
                    >
                      Team & IAM roles
                    </button>
                  </li>
                </ul>
              </div>
            )}
          </div>
        </aside>

        {/* Main Content Workspace */}
        <main className="flex-1 min-w-0 p-5 max-w-[1440px]">
          <Breadcrumbs items={getBreadcrumbs()} />

          {bannerNotice && (
            <div className="mb-4">
              <Alert
                type="info"
                onDismiss={() => setBannerNotice(null)}
              >
                {bannerNotice}
              </Alert>
            </div>
          )}

          {/* ── VIEW 1: TENANTS DIRECTORY (FLEET) ── */}
          {activeTab === 'clients' && (
            <div className="space-y-4">
              <PageHeader
                title="Tenants"
                count={clients.length}
                subtitle="Monitor registered merchant organizations, subscription entitlements, operational health, and enter workspaces for support."
                actions={
                  <Button
                    icon={RefreshCw}
                    loading={fleetLoading}
                    onClick={fetchFleet}
                  >
                    Refresh
                  </Button>
                }
              />

              <KpiStrip
                metrics={[
                  {
                    label: 'Total registered tenants',
                    value: Number(totalTenantsCount).toLocaleString(),
                    sub: 'All provisioned workspaces',
                  },
                  {
                    label: 'Active paid subscriptions',
                    value: Number(activePaidCount).toLocaleString(),
                    sub: 'In good standing',
                  },
                  {
                    label: 'In trial period',
                    value: Number(trialCount).toLocaleString(),
                    sub: 'Onboarding & evaluation',
                  },
                  {
                    label: 'Overdue / expired',
                    value: Number(overdueCount).toLocaleString(),
                    sub:
                      estimatedMrr > 0
                        ? `Est. MRR: TZS ${Number(estimatedMrr).toLocaleString()}`
                        : 'Requires follow-up',
                  },
                ]}
              />

              {fleetError && (
                <Alert
                  type="error"
                  title="Failed to load tenants"
                  action={
                    <Button size="sm" onClick={fetchFleet}>
                      Retry
                    </Button>
                  }
                >
                  {fleetError}
                </Alert>
              )}

              <div className="grid grid-cols-1 xl:grid-cols-3 gap-4 items-start">
                {/* Tenants Table Container */}
                <div
                  className={
                    previewTenant ? 'xl:col-span-2' : 'xl:col-span-3'
                  }
                >
                  <Container
                    title="Tenant organizations"
                    count={clients.length}
                    noPadding
                  >
                    {/* Property Filter Bar */}
                    <div className="px-4 py-2.5 border-b border-[#E9EBED] bg-white flex flex-wrap items-center gap-2">
                      <div className="relative flex-1 min-w-[220px] max-w-md">
                        <Search className="w-3.5 h-3.5 text-[#5F6B7A] absolute left-2.5 top-1/2 -translate-y-1/2" />
                        <input
                          type="text"
                          placeholder="Filter tenants by name, phone, or email..."
                          value={clientSearch}
                          onChange={(e) => setClientSearch(e.target.value)}
                          className="w-full pl-8 pr-3 py-1 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
                        />
                      </div>

                      <select
                        value={statusFilter}
                        onChange={(e) => {
                          setStatusFilter(e.target.value);
                          setSavedView('custom');
                        }}
                        className="px-2.5 py-1 text-[12px] border border-[#879596] rounded-[4px] bg-white text-[#16191F]"
                      >
                        <option value="">Status: All</option>
                        <option value="Active">Status = Active</option>
                        <option value="Trial">Status = Trial</option>
                        <option value="Debt">Status = Overdue</option>
                      </select>

                      <select
                        value={healthFilter}
                        onChange={(e) => {
                          setHealthFilter(e.target.value);
                          setSavedView('custom');
                        }}
                        className="px-2.5 py-1 text-[12px] border border-[#879596] rounded-[4px] bg-white text-[#16191F]"
                      >
                        <option value="">Health: All</option>
                        <option value="Healthy">Health = Healthy</option>
                        <option value="AtRisk">Health = At Risk</option>
                        <option value="Inactive">Health = Inactive</option>
                      </select>

                      {(clientSearch || statusFilter || healthFilter) && (
                        <Button
                          variant="link"
                          size="sm"
                          onClick={() => {
                            setClientSearch('');
                            setStatusFilter('');
                            setHealthFilter('');
                            setSavedView('all');
                          }}
                        >
                          Clear filters
                        </Button>
                      )}
                    </div>

                    {/* Dense Tenants Table */}
                    <div className="overflow-x-auto">
                      <table className="w-full text-left border-collapse">
                        <thead>
                          <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                            <th className="py-2.5 px-3 w-8" />
                            <th className="py-2.5 px-4">Tenant name</th>
                            <th className="py-2.5 px-4">Owner contact</th>
                            <th className="py-2.5 px-4">Plan</th>
                            <th className="py-2.5 px-4">Status</th>
                            <th className="py-2.5 px-4">Health</th>
                            <th className="py-2.5 px-4 text-right">
                              Products / Sales
                            </th>
                            <th className="py-2.5 px-4 text-right">Actions</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-[#E9EBED] text-[13px]">
                          {fleetLoading ? (
                            <tr>
                              <td
                                colSpan={8}
                                className="py-12 text-center text-[#5F6B7A]"
                              >
                                <RefreshCw className="w-4 h-4 animate-spin inline mr-2 text-[#0972D3]" />
                                Loading tenants from database...
                              </td>
                            </tr>
                          ) : clients.length === 0 ? (
                            <tr>
                              <td
                                colSpan={8}
                                className="py-12 text-center text-[#5F6B7A]"
                              >
                                No tenants match the current filter criteria.
                              </td>
                            </tr>
                          ) : (
                            clients.map((client) => {
                              const st = (client.status || '').toLowerCase();
                              const isSelected =
                                previewTenant?.tenantId === client.tenantId;

                              return (
                                <tr
                                  key={client.tenantId}
                                  onClick={() => setPreviewTenant(client)}
                                  className={`cursor-pointer transition-colors ${
                                    isSelected
                                      ? 'bg-[#F1F8FF]'
                                      : 'hover:bg-[#F1F8FF]/50'
                                  }`}
                                >
                                  <td className="py-2.5 px-3 text-center">
                                    <input
                                      type="radio"
                                      name="selectedTenantRow"
                                      checked={isSelected}
                                      onChange={() => setPreviewTenant(client)}
                                      className="text-[#0972D3] focus:ring-[#0972D3]"
                                    />
                                  </td>
                                  <td className="py-2.5 px-4">
                                    <button
                                      type="button"
                                      onClick={(e) => {
                                        e.stopPropagation();
                                        promptEnterTenant(client, 'overview');
                                      }}
                                      className="font-semibold text-[#0972D3] hover:underline text-left"
                                    >
                                      {client.name}
                                    </button>
                                    <div className="text-[11px] font-mono text-[#5F6B7A]">
                                      {client.tenantId?.slice(0, 8)}...
                                    </div>
                                  </td>
                                  <td className="py-2.5 px-4 text-[#16191F]">
                                    <div>
                                      {client.ownerPhone ||
                                        client.phone ||
                                        '—'}
                                    </div>
                                    <div className="text-[11px] text-[#5F6B7A]">
                                      {client.ownerEmail || client.ownerName || ''}
                                    </div>
                                  </td>
                                  <td className="py-2.5 px-4">
                                    <Badge color="blue">
                                      {client.planCode || 'Pro'}
                                    </Badge>
                                  </td>
                                  <td className="py-2.5 px-4">
                                    {st === 'active' || st === 'paid' ? (
                                      <StatusIndicator type="success">
                                        Active
                                      </StatusIndicator>
                                    ) : st === 'trial' ? (
                                      <StatusIndicator type="info">
                                        Trial · {client.trialDaysLeft ?? 0}d
                                      </StatusIndicator>
                                    ) : (
                                      <StatusIndicator type="error">
                                        Overdue
                                      </StatusIndicator>
                                    )}
                                  </td>
                                  <td className="py-2.5 px-4">
                                    {(client.health || '').toLowerCase() ===
                                    'atrisk' ? (
                                      <StatusIndicator type="warning">
                                        At risk
                                      </StatusIndicator>
                                    ) : (
                                      <span className="text-[12px] text-[#5F6B7A]">
                                        {client.health || 'Healthy'}
                                      </span>
                                    )}
                                  </td>
                                  <td className="py-2.5 px-4 text-right tabular-nums text-[12px] text-[#5F6B7A]">
                                    <span className="font-semibold text-[#16191F]">
                                      {client.productCount ??
                                        client.totalProducts ??
                                        0}
                                    </span>{' '}
                                    items ·{' '}
                                    <span className="font-semibold text-[#16191F]">
                                      {client.salesCount30d ??
                                        client.totalSales ??
                                        0}
                                    </span>{' '}
                                    sales
                                  </td>
                                  <td
                                    className="py-2.5 px-4 text-right whitespace-nowrap space-x-2"
                                    onClick={(e) => e.stopPropagation()}
                                  >
                                    <Button
                                      variant="link"
                                      size="sm"
                                      onClick={() =>
                                        promptEnterTenant(client, 'overview')
                                      }
                                    >
                                      Enter tenant
                                    </Button>
                                    <Button
                                      size="sm"
                                      onClick={() =>
                                        handleQuickExtendTrial(
                                          client.tenantId,
                                          14
                                        )
                                      }
                                    >
                                      +14d
                                    </Button>
                                  </td>
                                </tr>
                              );
                            })
                          )}
                        </tbody>
                      </table>
                    </div>
                  </Container>
                </div>

                {/* Split-Panel Tenant Quick Inspector */}
                {previewTenant && (
                  <div className="xl:col-span-1">
                    <Container
                      title={previewTenant.name}
                      description="Quick resource summary"
                      actions={
                        <button
                          type="button"
                          onClick={() => setPreviewTenant(null)}
                          className="text-[#5F6B7A] hover:text-[#16191F] p-1"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      }
                      footer={
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <div className="flex items-center gap-1.5">
                            <Button
                              size="sm"
                              onClick={() =>
                                handleQuickExtendTrial(
                                  previewTenant.tenantId,
                                  14
                                )
                              }
                            >
                              +14d trial
                            </Button>
                            <Button
                              size="sm"
                              onClick={() =>
                                handleQuickActivate(
                                  previewTenant.tenantId,
                                  1,
                                  previewTenant.planCode || 'Pro'
                                )
                              }
                            >
                              Activate 1m
                            </Button>
                          </div>
                          <Button
                            size="sm"
                            variant="primary"
                            onClick={() =>
                              promptEnterTenant(previewTenant, 'overview')
                            }
                          >
                            Enter workspace →
                          </Button>
                        </div>
                      }
                    >
                      <div className="space-y-3 text-[13px]">
                        <div>
                          <div className="text-[11px] font-semibold uppercase text-[#5F6B7A]">
                            Tenant ID
                          </div>
                          <div className="font-mono text-[12px] text-[#16191F] break-all">
                            {previewTenant.tenantId}
                          </div>
                        </div>
                        <div className="grid grid-cols-2 gap-3 pt-2 border-t border-[#E9EBED]">
                          <div>
                            <div className="text-[11px] text-[#5F6B7A]">
                              Owner phone
                            </div>
                            <div className="font-medium">
                              {previewTenant.ownerPhone ||
                                previewTenant.phone ||
                                '—'}
                            </div>
                          </div>
                          <div>
                            <div className="text-[11px] text-[#5F6B7A]">
                              Plan & status
                            </div>
                            <div className="font-medium">
                              {previewTenant.planCode || 'Pro'} ·{' '}
                              {previewTenant.status || 'Active'}
                            </div>
                          </div>
                        </div>

                        <div className="pt-2 border-t border-[#E9EBED]">
                          <div className="text-[11px] font-semibold uppercase text-[#5F6B7A] mb-2">
                            Direct jump to table
                          </div>
                          <div className="flex flex-wrap gap-1.5">
                            {[
                              { id: 'products', label: 'Products' },
                              { id: 'sales', label: 'Sales' },
                              { id: 'invoices', label: 'Invoices' },
                              { id: 'cash', label: 'Cash sessions' },
                              { id: 'subscription', label: 'Subscription' },
                            ].map((t) => (
                              <Button
                                key={t.id}
                                size="sm"
                                onClick={() =>
                                  handleQuickEnterTenant(previewTenant, t.id)
                                }
                              >
                                {t.label}
                              </Button>
                            ))}
                          </div>
                        </div>
                      </div>
                    </Container>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* ── VIEW 2: TENANT DETAIL CONSOLE (SUPPORT MODE) ── */}
          {activeTab === 'tenant-console' && selectedTenant && (
            <TenantDetailConsole
              tenant={selectedTenant}
              supportReason={supportReason}
              initialSubTab={tenantSubTab}
              onSubTabChange={setTenantSubTab}
              onBack={() => setActiveTab('clients')}
              onNotification={showNotification}
            />
          )}

          {/* ── VIEW 3: PLATFORM TEAM & IAM ROLES ── */}
          {activeTab === 'team' && isSuperAdmin && (
            <PlatformTeamManager
              currentOperator={currentOperator}
              onNotification={showNotification}
            />
          )}

          {/* ── VIEW 4: PLANS & PACKAGES ── */}
          {activeTab === 'packages' && (
            <div className="space-y-4">
              <PageHeader
                title="Plans & modular packages"
                count={packages.length}
                subtitle="Configure subscription tiers, monthly pricing, resource quotas, and feature flags. Changes propagate to client apps immediately."
                actions={
                  <>
                    <Button
                      icon={RefreshCw}
                      loading={packagesLoading}
                      onClick={fetchPackages}
                    >
                      Refresh
                    </Button>
                    <Button
                      variant="primary"
                      icon={Plus}
                      onClick={() => setShowAddPackageModal(true)}
                    >
                      Create plan
                    </Button>
                  </>
                }
              />

              {packagesError && (
                <Alert
                  type="error"
                  title="Could not load subscription plans"
                  action={
                    <Button size="sm" onClick={fetchPackages}>
                      Retry
                    </Button>
                  }
                >
                  {packagesError}
                </Alert>
              )}

              <Container
                title="Configured plans"
                count={packages.length}
                noPadding
              >
                <div className="overflow-x-auto">
                  <table className="w-full text-left border-collapse">
                    <thead>
                      <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                        <th className="py-2.5 px-4">Plan code</th>
                        <th className="py-2.5 px-4">Display name</th>
                        <th className="py-2.5 px-4">Type</th>
                        <th className="py-2.5 px-4 text-right">Monthly price</th>
                        <th className="py-2.5 px-4">Enabled features</th>
                        <th className="py-2.5 px-4">Status</th>
                        <th className="py-2.5 px-4 text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[#E9EBED] text-[13px]">
                      {packagesLoading ? (
                        <tr>
                          <td
                            colSpan={7}
                            className="py-10 text-center text-[#5F6B7A]"
                          >
                            <RefreshCw className="w-4 h-4 animate-spin inline mr-2 text-[#0972D3]" />
                            Loading plans from database...
                          </td>
                        </tr>
                      ) : packages.length === 0 ? (
                        <tr>
                          <td
                            colSpan={7}
                            className="py-10 text-center text-[#5F6B7A]"
                          >
                            No subscription plans configured yet. Click "Create plan" to add one.
                          </td>
                        </tr>
                      ) : (
                        packages.map((pkg) => {
                          const featureKeys = pkg.featureKeys || [];
                          return (
                            <tr
                              key={pkg.code}
                              className="hover:bg-[#F1F8FF]/50 transition-colors"
                            >
                              <td className="py-2.5 px-4 font-mono text-[12px] font-semibold text-[#16191F]">
                                {pkg.code}
                              </td>
                              <td className="py-2.5 px-4 font-medium text-[#16191F]">
                                {pkg.name}
                              </td>
                              <td className="py-2.5 px-4">
                                <Badge color={pkg.isPackage ? 'amber' : 'blue'}>
                                  {pkg.isPackage ? 'Add-on package' : 'Base plan'}
                                </Badge>
                              </td>
                              <td className="py-2.5 px-4 text-right tabular-nums font-semibold text-[#16191F]">
                                {Number(pkg.monthlyPrice || 0).toLocaleString()}{' '}
                                {pkg.currency || 'TZS'}
                              </td>
                              <td className="py-2.5 px-4">
                                <div className="flex flex-wrap gap-1 max-w-md">
                                  {featureKeys.map((fk) => (
                                    <Badge key={fk}>{fk}</Badge>
                                  ))}
                                </div>
                              </td>
                              <td className="py-2.5 px-4">
                                {pkg.isActive === false ? (
                                  <StatusIndicator type="pending">
                                    Inactive
                                  </StatusIndicator>
                                ) : (
                                  <StatusIndicator type="success">
                                    Active
                                  </StatusIndicator>
                                )}
                              </td>
                              <td className="py-2.5 px-4 text-right">
                                <Button
                                  variant="link"
                                  size="sm"
                                  onClick={() =>
                                    setEditingPackage({
                                      ...pkg,
                                      featureKeys: [...featureKeys],
                                    })
                                  }
                                >
                                  Edit plan
                                </Button>
                              </td>
                            </tr>
                          );
                        })
                      )}
                    </tbody>
                  </table>
                </div>
              </Container>
            </div>
          )}

          {/* ── VIEW 5: VOUCHER MACHINE ── */}
          {activeTab === 'vouchers' && (
            <div className="space-y-4">
              <PageHeader
                title="Subscription vouchers"
                count={vouchers.length}
                subtitle="Generate CSPRNG Luhn-32 validated prepaid activation codes and inspect redemption history."
                actions={
                  <Button
                    icon={RefreshCw}
                    loading={vouchersLoading}
                    onClick={fetchVouchers}
                  >
                    Refresh
                  </Button>
                }
              />

              <Container
                title="Issue new voucher"
                description="Codes are cryptographically generated and stored on the server."
              >
                <div className="grid grid-cols-1 sm:grid-cols-4 gap-3 items-end">
                  <div>
                    <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                      Validity duration
                    </label>
                    <select
                      value={newVoucherDays}
                      onChange={(e) => setNewVoucherDays(e.target.value)}
                      className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] bg-white"
                    >
                      <option value="30">30 days (1 month)</option>
                      <option value="90">90 days (3 months)</option>
                      <option value="180">180 days (6 months)</option>
                      <option value="365">365 days (1 year)</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                      Target plan
                    </label>
                    <select
                      value={newVoucherPlan}
                      onChange={(e) => setNewVoucherPlan(e.target.value)}
                      className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] bg-white"
                    >
                      {packages.length > 0 ? (
                        packages.map((p) => (
                          <option key={p.code} value={p.code}>
                            {p.name} ({Number(p.monthlyPrice || 0).toLocaleString()}{' '}
                            {p.currency || 'TZS'})
                          </option>
                        ))
                      ) : (
                        <>
                          <option value="Starter">Starter</option>
                          <option value="Pro">Pro</option>
                          <option value="Scale">Scale</option>
                          <option value="invoice-manager">
                            Invoice Manager Add-on
                          </option>
                        </>
                      )}
                    </select>
                  </div>

                  <div>
                    <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                      Restrict to tenant ID (optional)
                    </label>
                    <input
                      type="text"
                      placeholder="Leave blank for any tenant"
                      value={newVoucherTarget}
                      onChange={(e) => setNewVoucherTarget(e.target.value)}
                      className="w-full px-3 py-1.5 text-[13px] font-mono border border-[#879596] rounded-[4px]"
                    />
                  </div>

                  <div>
                    <Button
                      variant="primary"
                      loading={generatingVoucher}
                      onClick={handleGenerateVoucher}
                      className="w-full"
                    >
                      Issue voucher
                    </Button>
                  </div>
                </div>

                {lastGeneratedVoucher && (
                  <div className="mt-4 pt-4 border-t border-[#E9EBED] flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-[#F1F8FF] p-3.5 rounded-[4px] border border-[#99CBE4]">
                    <div>
                      <div className="text-[11px] font-bold uppercase text-[#0972D3]">
                        Newly issued voucher code
                      </div>
                      <div className="text-[20px] font-bold font-mono text-[#16191F] tracking-wider">
                        {lastGeneratedVoucher.code}
                      </div>
                      <div className="text-[12px] text-[#5F6B7A]">
                        {lastGeneratedVoucher.valueDays} days · Plan:{' '}
                        {lastGeneratedVoucher.planCode} · Target:{' '}
                        {lastGeneratedVoucher.targetTenant}
                      </div>
                    </div>
                    <Button
                      icon={Copy}
                      onClick={() =>
                        handleCopyWhatsAppMessage(lastGeneratedVoucher)
                      }
                    >
                      Copy WhatsApp message
                    </Button>
                  </div>
                )}
              </Container>

              {vouchersError && (
                <Alert
                  type="error"
                  title="Could not load vouchers"
                  action={
                    <Button size="sm" onClick={fetchVouchers}>
                      Retry
                    </Button>
                  }
                >
                  {vouchersError}
                </Alert>
              )}

              <Container
                title="Issued vouchers history"
                count={vouchers.length}
                noPadding
              >
                <div className="overflow-x-auto">
                  <table className="w-full text-left border-collapse">
                    <thead>
                      <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                        <th className="py-2.5 px-4">Voucher code</th>
                        <th className="py-2.5 px-4">Plan</th>
                        <th className="py-2.5 px-4 text-right">Value (days)</th>
                        <th className="py-2.5 px-4">Target / Redeemed by</th>
                        <th className="py-2.5 px-4">Created at</th>
                        <th className="py-2.5 px-4">Status</th>
                        <th className="py-2.5 px-4 text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[#E9EBED] text-[13px]">
                      {vouchersLoading ? (
                        <tr>
                          <td
                            colSpan={7}
                            className="py-10 text-center text-[#5F6B7A]"
                          >
                            <RefreshCw className="w-4 h-4 animate-spin inline mr-2 text-[#0972D3]" />
                            Loading vouchers...
                          </td>
                        </tr>
                      ) : vouchers.length === 0 ? (
                        <tr>
                          <td
                            colSpan={7}
                            className="py-10 text-center text-[#5F6B7A]"
                          >
                            No vouchers issued yet.
                          </td>
                        </tr>
                      ) : (
                        vouchers.map((v) => {
                          const isIssued =
                            v.status === 'Issued' || v.status === 0;
                          const isRedeemed =
                            v.status === 'Redeemed' || v.status === 1;
                          return (
                            <tr
                              key={v.id || v.code}
                              className="hover:bg-[#F1F8FF]/50 transition-colors"
                            >
                              <td className="py-2 px-4 font-mono font-bold text-[#16191F]">
                                {v.code}
                              </td>
                              <td className="py-2 px-4">
                                <Badge color="blue">
                                  {v.planCode || 'All'}
                                </Badge>
                              </td>
                              <td className="py-2 px-4 text-right tabular-nums font-medium">
                                {v.valueDays}d
                              </td>
                              <td className="py-2 px-4 font-mono text-[12px] text-[#5F6B7A]">
                                {v.redeemedByTenantId
                                  ? `Redeemed: ${v.redeemedByTenantId.slice(
                                      0,
                                      8
                                    )}...`
                                  : v.targetTenantId
                                  ? `Locked: ${v.targetTenantId.slice(0, 8)}...`
                                  : 'Unrestricted'}
                              </td>
                              <td className="py-2 px-4 text-[#5F6B7A]">
                                {v.createdAt
                                  ? new Date(v.createdAt).toLocaleDateString()
                                  : '—'}
                              </td>
                              <td className="py-2 px-4">
                                {isIssued ? (
                                  <StatusIndicator type="info">
                                    Issued
                                  </StatusIndicator>
                                ) : isRedeemed ? (
                                  <StatusIndicator type="success">
                                    Redeemed
                                  </StatusIndicator>
                                ) : (
                                  <StatusIndicator type="pending">
                                    {String(v.status)}
                                  </StatusIndicator>
                                )}
                              </td>
                              <td className="py-2 px-4 text-right">
                                <Button
                                  variant="link"
                                  size="sm"
                                  onClick={() => handleCopyWhatsAppMessage(v)}
                                >
                                  Copy message
                                </Button>
                              </td>
                            </tr>
                          );
                        })
                      )}
                    </tbody>
                  </table>
                </div>
              </Container>
            </div>
          )}

          {/* ── VIEW 6: PAYMENT ACCOUNTS ── */}
          {activeTab === 'payment' && (
            <div className="space-y-4 max-w-3xl">
              <PageHeader
                title="Payment instructions & accounts"
                subtitle="Configure the mobile money till numbers, bank account details, and support contacts displayed inside tenant apps."
                actions={
                  <Button
                    icon={RefreshCw}
                    loading={paymentLoading}
                    onClick={fetchPaymentAccounts}
                  >
                    Refresh
                  </Button>
                }
              />

              {paymentError && (
                <Alert
                  type="error"
                  title="Could not load payment instructions"
                  action={
                    <Button size="sm" onClick={fetchPaymentAccounts}>
                      Retry
                    </Button>
                  }
                >
                  {paymentError}
                </Alert>
              )}

              <Container
                title="Collection accounts"
                description="Published live to all tenant mobile and desktop applications."
                footer={
                  <div className="flex justify-end">
                    <Button
                      variant="primary"
                      loading={paymentSaving}
                      onClick={handleSavePaymentAccounts}
                    >
                      Save & publish instructions
                    </Button>
                  </div>
                }
              >
                {paymentLoading ? (
                  <div className="py-8 text-center text-[#5F6B7A]">
                    <RefreshCw className="w-4 h-4 animate-spin inline mr-2 text-[#0972D3]" />
                    Loading payment accounts...
                  </div>
                ) : (
                  <div className="space-y-4">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                          M-Pesa Lipa Namba / Till
                        </label>
                        <input
                          type="text"
                          placeholder="e.g. 5523412"
                          value={paymentAccounts.mpesaTill}
                          onChange={(e) =>
                            setPaymentAccounts({
                              ...paymentAccounts,
                              mpesaTill: e.target.value,
                            })
                          }
                          className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
                        />
                      </div>

                      <div>
                        <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                          Airtel Money / Mixx by Yas
                        </label>
                        <input
                          type="text"
                          placeholder="e.g. 0788 000 111"
                          value={paymentAccounts.airtelMoney}
                          onChange={(e) =>
                            setPaymentAccounts({
                              ...paymentAccounts,
                              airtelMoney: e.target.value,
                            })
                          }
                          className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
                        />
                      </div>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                          Bank name
                        </label>
                        <input
                          type="text"
                          placeholder="e.g. CRDB Bank"
                          value={paymentAccounts.bankName}
                          onChange={(e) =>
                            setPaymentAccounts({
                              ...paymentAccounts,
                              bankName: e.target.value,
                            })
                          }
                          className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
                        />
                      </div>

                      <div>
                        <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                          Bank account number
                        </label>
                        <input
                          type="text"
                          placeholder="e.g. 0152 4899 2100"
                          value={paymentAccounts.bankAccountNumber}
                          onChange={(e) =>
                            setPaymentAccounts({
                              ...paymentAccounts,
                              bankAccountNumber: e.target.value,
                            })
                          }
                          className="w-full px-3 py-1.5 text-[13px] font-mono border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
                        />
                      </div>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                          Account beneficiary name
                        </label>
                        <input
                          type="text"
                          placeholder="e.g. Jolinx Technologies Ltd"
                          value={paymentAccounts.bankAccountName}
                          onChange={(e) =>
                            setPaymentAccounts({
                              ...paymentAccounts,
                              bankAccountName: e.target.value,
                            })
                          }
                          className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
                        />
                      </div>

                      <div>
                        <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                          Billing support WhatsApp number
                        </label>
                        <input
                          type="text"
                          placeholder="e.g. +255 754 000 000"
                          value={paymentAccounts.whatsAppContact}
                          onChange={(e) =>
                            setPaymentAccounts({
                              ...paymentAccounts,
                              whatsAppContact: e.target.value,
                            })
                          }
                          className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                        Customer payment guidance notes
                      </label>
                      <textarea
                        rows={3}
                        placeholder="Instructions shown to merchants on the subscription renewal screen..."
                        value={paymentAccounts.notes}
                        onChange={(e) =>
                          setPaymentAccounts({
                            ...paymentAccounts,
                            notes: e.target.value,
                          })
                        }
                        className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
                      />
                    </div>
                  </div>
                )}
              </Container>
            </div>
          )}
        </main>
      </div>

      {/* ── MODAL: ENTER TENANT SUPPORT REASON ── */}
      <Modal
        open={Boolean(enterModalTenant)}
        onClose={() => setEnterModalTenant(null)}
        title={`Enter tenant workspace — ${
          enterModalTenant?.tenant?.name || ''
        }`}
        size="sm"
        footer={
          <>
            <Button onClick={() => setEnterModalTenant(null)}>Cancel</Button>
            <Button variant="primary" onClick={confirmEnterTenant}>
              Enter support mode
            </Button>
          </>
        }
      >
        <form onSubmit={confirmEnterTenant} className="space-y-3.5">
          <p className="text-[12px] text-[#5F6B7A]">
            Entering a tenant workspace activates audited Support Mode. Provide a brief reason for the platform audit log.
          </p>
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Support reason
            </label>
            <input
              type="text"
              required
              autoFocus
              value={enterReasonInput}
              onChange={(e) => setEnterReasonInput(e.target.value)}
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
            />
          </div>
        </form>
      </Modal>

      {/* ── MODAL: EDIT PLAN ── */}
      <Modal
        open={Boolean(editingPackage)}
        onClose={() => setEditingPackage(null)}
        title={`Edit plan — ${editingPackage?.name || ''}`}
        size="md"
        footer={
          <>
            <Button onClick={() => setEditingPackage(null)}>Cancel</Button>
            <Button
              variant="primary"
              loading={savingPackage}
              onClick={handleSavePackageEdit}
            >
              Save changes
            </Button>
          </>
        }
      >
        {editingPackage && (
          <div className="space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                  Display name
                </label>
                <input
                  type="text"
                  value={editingPackage.name}
                  onChange={(e) =>
                    setEditingPackage({
                      ...editingPackage,
                      name: e.target.value,
                    })
                  }
                  className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px]"
                />
              </div>
              <div>
                <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                  Monthly price (TZS)
                </label>
                <input
                  type="number"
                  value={editingPackage.monthlyPrice}
                  onChange={(e) =>
                    setEditingPackage({
                      ...editingPackage,
                      monthlyPrice: Number(e.target.value),
                    })
                  }
                  className="w-full px-3 py-1.5 text-[13px] tabular-nums border border-[#879596] rounded-[4px]"
                />
              </div>
            </div>

            <div>
              <label className="block text-[12px] font-semibold text-[#16191F] mb-1.5">
                Included feature flags
              </label>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 border border-[#D5DBDB] rounded-[4px] p-3 max-h-60 overflow-y-auto bg-[#FAFAFA]">
                {ALL_AVAILABLE_FEATURES.map((feat) => {
                  const isChecked = (
                    editingPackage.featureKeys || []
                  ).includes(feat.key);
                  return (
                    <label
                      key={feat.key}
                      className="flex items-start gap-2 p-1.5 rounded-[4px] cursor-pointer hover:bg-white text-[12px]"
                    >
                      <input
                        type="checkbox"
                        checked={isChecked}
                        onChange={(e) => {
                          const current = editingPackage.featureKeys || [];
                          setEditingPackage({
                            ...editingPackage,
                            featureKeys: e.target.checked
                              ? [...current, feat.key]
                              : current.filter((k) => k !== feat.key),
                          });
                        }}
                        className="mt-0.5 text-[#0972D3]"
                      />
                      <div>
                        <div className="font-semibold text-[#16191F]">
                          {feat.name}
                        </div>
                        <div className="text-[11px] text-[#5F6B7A]">
                          {feat.desc}
                        </div>
                      </div>
                    </label>
                  );
                })}
              </div>
            </div>
          </div>
        )}
      </Modal>

      {/* ── MODAL: CREATE PLAN ── */}
      <Modal
        open={showAddPackageModal}
        onClose={() => setShowAddPackageModal(false)}
        title="Create subscription plan"
        size="sm"
        footer={null}
      >
        <form onSubmit={handleCreatePackage} className="space-y-3.5">
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Plan code
            </label>
            <input
              name="code"
              type="text"
              required
              placeholder="e.g. enterprise-tier"
              className="w-full px-3 py-1.5 text-[13px] font-mono border border-[#879596] rounded-[4px]"
            />
          </div>
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Display name
            </label>
            <input
              name="name"
              type="text"
              required
              placeholder="e.g. Enterprise Multi-Branch"
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px]"
            />
          </div>
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Monthly price (TZS)
            </label>
            <input
              name="monthlyPrice"
              type="number"
              required
              placeholder="85000"
              className="w-full px-3 py-1.5 text-[13px] tabular-nums border border-[#879596] rounded-[4px]"
            />
          </div>
          <label className="flex items-center gap-2 text-[12px] text-[#16191F] cursor-pointer pt-1">
            <input
              name="isPackage"
              type="checkbox"
              defaultChecked={false}
              className="text-[#0972D3]"
            />
            <span>Modular add-on package (instead of base subscription plan)</span>
          </label>
          <div className="pt-3 border-t border-[#E9EBED] flex justify-end gap-2">
            <Button onClick={() => setShowAddPackageModal(false)}>
              Cancel
            </Button>
            <Button type="submit" variant="primary" loading={creatingPackage}>
              Create plan
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
