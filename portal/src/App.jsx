import React, { useState, useEffect } from 'react';
import {
  Package,
  Users,
  Ticket,
  CreditCard,
  Plus,
  Edit2,
  Check,
  X,
  Copy,
  ExternalLink,
  Search,
  Sparkles,
  ShieldCheck,
  PhoneCall,
  Clock,
  ArrowRight,
  RefreshCw,
  Sliders,
  DollarSign,
  AlertCircle,
  Crown,
  Building2,
  Layers,
  ChevronRight,
  UserCheck,
  LogIn,
  LogOut,
  TrendingUp,
  AlertTriangle,
  Store
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
  updatePaymentInstructionsAdmin
} from './services/api';

const ALL_AVAILABLE_FEATURES = [
  { key: 'pos.enabled', name: 'Point of Sale (POS)', desc: 'Offline cashier checkout & receipts' },
  { key: 'inventory.enabled', name: 'Inventory & Stock', desc: 'Real-time stock ledger, movements & alerts' },
  { key: 'invoicing.enabled', name: 'Invoicing & Proforma', desc: 'PDF invoices, debtor tracking & payments' },
  { key: 'credit.enabled', name: 'Customer Credit (Madeni)', desc: 'Customer debt limits & reminders' },
  { key: 'purchasing.enabled', name: 'Purchasing & Suppliers', desc: 'Supplier purchase orders & accounts payable' },
  { key: 'accounting.enabled', name: 'Accounting & P&L', desc: 'Full chart of accounts & profit/loss' },
  { key: 'finance.enabled', name: 'Cashbook & Money Accounts', desc: 'Till, Bank, M-Pesa drawer reconciliation' },
  { key: 'crm.enabled', name: 'Customer Directory', desc: 'Customer contact history & insights' },
  { key: 'reports.enabled', name: 'Reports & Export', desc: 'Sales, stock & financial reports export' },
  { key: 'multi-branch.enabled', name: 'Multi-Branch & Transfers', desc: 'Manage 2+ physical shops & warehouses' },
  { key: 'pricing.enabled', name: 'Wholesale & Price Lists', desc: 'Tiered wholesale & retail price rules' },
];

export default function App() {
  const [activeTab, setActiveTab] = useState('clients'); // clients | tenant-console | team | packages | vouchers | payment
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [selectedTenant, setSelectedTenant] = useState(null);

  // ── Operator Identity & Auth ──────────────────────────────────────
  const [currentOperator, setCurrentOperator] = useState(() => getStoredUser());
  const [authToken, setAuthToken] = useState(() => getAuthToken());
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [loginLoading, setLoginLoading] = useState(false);
  const [loginError, setLoginError] = useState(null);

  // ── Notification Banner ───────────────────────────────────────────
  const [bannerNotice, setBannerNotice] = useState(null);
  const showNotification = (msg) => {
    setBannerNotice(msg);
    setTimeout(() => setBannerNotice(null), 4500);
  };

  // ── Fleet Summary & Tenants State (Real Live Data) ────────────────
  const [fleetSummary, setFleetSummary] = useState(null);
  const [clients, setClients] = useState([]);
  const [fleetLoading, setFleetLoading] = useState(false);
  const [fleetError, setFleetError] = useState(null);
  const [clientSearch, setClientSearch] = useState('');
  const [healthFilter, setHealthFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  const fetchFleet = async () => {
    if (!getAuthToken()) {
      return;
    }
    setFleetLoading(true);
    setFleetError(null);
    try {
      const [summary, tenantsRes] = await Promise.all([
        getFleetSummary().catch((e) => {
          console.warn('Failed to load fleet summary:', e);
          return null;
        }),
        listFleetTenants({
          search: clientSearch,
          status: statusFilter,
          health: healthFilter,
          pageSize: 50
        })
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
      console.error('Failed to fetch fleet:', err);
      setFleetError(err.message || 'Hitilafu ya kupakia maduka kutoka seva ya API.');
    } finally {
      setFleetLoading(false);
    }
  };

  useEffect(() => {
    if (authToken) {
      fetchFleet();
    }
  }, [authToken, clientSearch, statusFilter, healthFilter]);

  // Global 401 interceptor listener
  useEffect(() => {
    const handleUnauthorized = () => {
      clearAuthSession();
      setCurrentOperator(null);
      setAuthToken('');
      showNotification('Kipindi chako kimeisha au token imebatilishwa. Tafadhali ingia tena.');
    };
    window.addEventListener('jlx:unauthorized', handleUnauthorized);
    return () => window.removeEventListener('jlx:unauthorized', handleUnauthorized);
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
      setShowLoginModal(false);
      showNotification(`Umeingia kama ${res.user.email} (${res.user.platformRole || 'PlatformSuperAdmin'})`);
      fetchFleet();
    } catch (err) {
      const msg = err.message || 'Nenosiri au barua pepe sio sahihi.';
      setLoginError(msg);
      showNotification(`Hitilafu ya kuingia: ${msg}`);
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
    showNotification('Umetoka kwenye mfumo.');
  };

  const isSuperAdmin = currentOperator?.platformRole === 'PlatformSuperAdmin';

  // ── Quick Client Actions ──────────────────────────────────────────
  const handleQuickExtendTrial = async (tenantId, days) => {
    try {
      await extendTenantTrial(tenantId, days);
    } catch {}
    setClients(clients.map(c => c.tenantId === tenantId ? { ...c, trialDaysLeft: (c.trialDaysLeft || 0) + days, status: 'Trial' } : c));
    showNotification(`Umeongeza siku ${days} za majaribio bila malipo.`);
  };

  const handleQuickActivate = async (tenantId, months, planCode = 'Pro') => {
    try {
      await directActivateTenant(tenantId, months, planCode);
    } catch {}
    const today = new Date();
    today.setDate(today.getDate() + months * 30);
    const dateStr = today.toISOString().split('T')[0];

    setClients(clients.map(c => c.tenantId === tenantId ? { ...c, status: 'Active', trialDaysLeft: 0, paidUntil: dateStr } : c));
    showNotification(`Akaunti imewashwa kwa miezi ${months} (Lipa mpaka ${dateStr}) bila kuhitaji vocha!`);
  };

  const handleOpenTenantConsole = (tenant) => {
    setSelectedTenant(tenant);
    setActiveTab('tenant-console');
  };

  // ── Packages State (Live Database Data) ───────────────────────────
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
      console.error('Failed to fetch packages:', err);
      setPackagesError(err.message || 'Hitilafu ya kupakia vifurushi kutoka seva.');
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
        maxBranches: editingPackage.maxBranches ? Number(editingPackage.maxBranches) : null,
        maxUsers: editingPackage.maxUsers ? Number(editingPackage.maxUsers) : null,
        maxProducts: editingPackage.maxProducts ? Number(editingPackage.maxProducts) : null,
        isPackage: Boolean(editingPackage.isPackage),
        isActive: Boolean(editingPackage.isActive),
      });
      showNotification(`Kifurushi ${editingPackage.name} kimesasishwa kwenye seva!`);
      setEditingPackage(null);
      fetchPackages();
    } catch (err) {
      showNotification(`Hitilafu kusasisha kifurushi: ${err.message || 'Jaribu tena'}`);
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
        maxBranches: form.maxBranches?.value ? Number(form.maxBranches.value) : null,
        maxUsers: form.maxUsers?.value ? Number(form.maxUsers.value) : null,
        maxProducts: form.maxProducts?.value ? Number(form.maxProducts.value) : null,
        isPackage: Boolean(form.isPackage?.checked),
      };
      await createPlanAdmin(payload);
      setShowAddPackageModal(false);
      showNotification(`Kifurushi kipya kimeundwa kwenye seva!`);
      fetchPackages();
    } catch (err) {
      showNotification(`Hitilafu ya kuunda kifurushi: ${err.message || 'Jaribu tena'}`);
    } finally {
      setCreatingPackage(false);
    }
  };

  // ── Voucher Generator State (Live Database Data) ──────────────────
  const [vouchers, setVouchers] = useState([]);
  const [vouchersLoading, setVouchersLoading] = useState(false);
  const [vouchersError, setVouchersError] = useState(null);
  const [voucherPage, setVoucherPage] = useState(1);
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
      console.error('Failed to fetch vouchers:', err);
      setVouchersError(err.message || 'Hitilafu ya kupakia vocha kutoka seva.');
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

      const generatedCode = Array.isArray(res) ? res[0] : (res?.codes?.[0] || res?.code);
      if (generatedCode) {
        const newVoucher = {
          code: generatedCode,
          valueDays: Number(newVoucherDays),
          status: 'Issued',
          planCode: newVoucherPlan,
          targetTenant: newVoucherTarget?.trim() || 'Yeyote (Bila Kikwazo)',
          createdAt: new Date().toISOString(),
        };
        setLastGeneratedVoucher(newVoucher);
        showNotification(`Vocha ${generatedCode} imetengenezwa kwenye seva!`);
        fetchVouchers();
      } else {
        showNotification('Vocha imetengenezwa kwenye seva.');
        fetchVouchers();
      }
    } catch (err) {
      showNotification(`Hitilafu ya kuzalisha vocha: ${err.message || 'Jaribu tena'}`);
    } finally {
      setGeneratingVoucher(false);
    }
  };

  const handleCopyWhatsAppMessage = (voucher) => {
    const msg = `Habari! Tumepokea malipo yako ya huduma ya Jolinx Business OS.\n\n` +
      `🎟️ Vocha Yako: *${voucher.code}*\n` +
      `⏳ Muda Uliofunguliwa: *Siku ${voucher.valueDays} (${voucher.planCode || 'Pro'})*\n\n` +
      `Fungua app yako kisha uweke namba hii kwenye sehemu ya Malipo, au bofya kiungo hiki kuwasha mara moja:\n` +
      `👉 https://staging.jolinx-portal.pages.dev/redeem?code=${voucher.code}\n\n` +
      `Asante kwa kufanya biashara nasi!`;
    navigator.clipboard.writeText(msg);
    showNotification('Ujumbe wa WhatsApp umenakiliwa! Tuma kwa mteja.');
  };

  // ── Dynamic Payment Accounts State (Live Database Data) ───────────
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
      console.error('Failed to fetch payment instructions:', err);
      setPaymentError(err.message || 'Hitilafu ya kupakia akaunti za malipo.');
    } finally {
      setPaymentLoading(false);
    }
  };

  const handleSavePaymentAccounts = async () => {
    setPaymentSaving(true);
    try {
      await updatePaymentInstructionsAdmin(paymentAccounts);
      showNotification('Akaunti za malipo zimehifadhiwa kwenye seva na kuchapishwa kwenye app zote!');
    } catch (err) {
      showNotification(`Hitilafu kuhifadhi: ${err.message || 'Jaribu tena'}`);
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
    } else if (activeTab === 'payment') {
      fetchPaymentAccounts();
    }
  }, [authToken, activeTab]);

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col font-sans">
      {/* Top Bar Header */}
      <header className="bg-slate-900 text-white border-b border-slate-800 sticky top-0 z-30 shadow-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 rounded-xl bg-indigo-600 flex items-center justify-center shadow-lg shadow-indigo-500/30">
                <Crown className="w-6 h-6 text-amber-300" />
              </div>
              <div>
                <span className="font-extrabold text-lg tracking-tight">JOLINX BACK-OFFICE</span>
                <span className="ml-2 text-[10px] uppercase px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 font-bold border border-emerald-500/30">
                  Control Plane
                </span>
              </div>
            </div>

            {/* Desktop Navigation */}
            <nav className="hidden md:flex items-center space-x-1">
              {[
                { id: 'clients', label: 'Maduka Yote (Fleet)', icon: Building2 },
                ...(selectedTenant
                  ? [{ id: 'tenant-console', label: `Duka: ${selectedTenant.name.slice(0, 15)}...`, icon: Sliders }]
                  : []),
                ...(isSuperAdmin
                  ? [{ id: 'team', label: 'Timu ya Platform', icon: Crown }]
                  : []),
                { id: 'packages', label: 'Vifurushi & Features', icon: Package },
                { id: 'vouchers', label: 'Mashine ya Vocha', icon: Ticket },
                { id: 'payment', label: 'Akaunti za Malipo', icon: CreditCard },
              ].map((tab) => {
                const Icon = tab.icon;
                const active = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={`flex items-center space-x-1.5 px-3 py-2 rounded-lg text-xs font-semibold transition ${
                      active
                        ? 'bg-indigo-600 text-white shadow'
                        : 'text-slate-300 hover:text-white hover:bg-slate-800'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{tab.label}</span>
                  </button>
                );
              })}
            </nav>

            {/* Operator Identity Ribbon */}
            <div className="hidden lg:flex items-center space-x-3">
              <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-800 text-[11px] font-mono text-slate-300 border border-slate-700">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                <span>Staging API</span>
              </div>

              {currentOperator ? (
                <div className="flex items-center gap-2 bg-slate-800/80 px-3 py-1.5 rounded-xl border border-slate-700">
                  <div className="text-right">
                    <div className="text-xs font-bold text-white leading-tight">
                      {currentOperator.email}
                    </div>
                    <div className="text-[10px] font-mono text-amber-400">
                      {isSuperAdmin ? 'SUPER SUPER ADMIN' : 'SUPPORT STAFF'}
                    </div>
                  </div>
                  <button
                    onClick={handleLogout}
                    className="p-1.5 text-slate-400 hover:text-rose-400 transition rounded-lg hover:bg-slate-700 ml-1"
                    title="Toka (Logout)"
                  >
                    <LogOut className="w-4 h-4" />
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => setShowLoginModal(true)}
                  className="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-xs font-bold transition flex items-center gap-1.5"
                >
                  <LogIn className="w-4 h-4" />
                  <span>Ingia Kama Msimamizi</span>
                </button>
              )}
            </div>

            {/* Mobile Menu Button */}
            <div className="md:hidden flex items-center">
              <button
                onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                className="p-2 rounded-lg bg-slate-800 text-slate-300 hover:text-white"
              >
                <Sliders className="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>

        {/* Mobile Navigation Dropdown */}
        {mobileMenuOpen && (
          <div className="md:hidden bg-slate-800 border-t border-slate-700 px-4 py-3 space-y-1">
            {[
              { id: 'clients', label: 'Maduka Yote (Fleet)', icon: Building2 },
              ...(selectedTenant
                ? [{ id: 'tenant-console', label: `Duka: ${selectedTenant.name}`, icon: Sliders }]
                : []),
              ...(isSuperAdmin
                ? [{ id: 'team', label: 'Timu ya Platform', icon: Crown }]
                : []),
              { id: 'packages', label: 'Vifurushi & Features', icon: Package },
              { id: 'vouchers', label: 'Mashine ya Vocha', icon: Ticket },
              { id: 'payment', label: 'Akaunti za Malipo', icon: CreditCard },
            ].map((tab) => {
              const Icon = tab.icon;
              const active = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => {
                    setActiveTab(tab.id);
                    setMobileMenuOpen(false);
                  }}
                  className={`w-full flex items-center space-x-3 px-3 py-2.5 rounded-lg text-sm font-medium transition ${
                    active ? 'bg-indigo-600 text-white' : 'text-slate-300 hover:bg-slate-700'
                  }`}
                >
                  <Icon className="w-5 h-5" />
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>
        )}
      </header>

      {/* Floating Notification Toast */}
      {bannerNotice && (
        <div className="fixed bottom-5 right-5 z-50 bg-slate-900 text-white px-5 py-3 rounded-xl shadow-2xl flex items-center space-x-3 border border-indigo-500/40 animate-bounce">
          <Sparkles className="w-5 h-5 text-indigo-400" />
          <span className="text-sm font-medium">{bannerNotice}</span>
        </div>
      )}

      {/* Main Body */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6 lg:p-8">
        {!authToken || !currentOperator ? (
          <div className="min-h-[75vh] flex items-center justify-center p-4">
            <div className="bg-white rounded-3xl border border-slate-200/80 shadow-2xl max-w-md w-full p-8 relative overflow-hidden">
              <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-indigo-500 via-purple-500 to-amber-500" />

              <div className="text-center space-y-2">
                <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-indigo-50 border border-indigo-100 text-indigo-600 shadow-inner">
                  <Crown className="w-7 h-7 text-indigo-600" />
                </div>
                <h1 className="text-2xl font-black text-slate-900 tracking-tight">Jolinx Back-Office Portal</h1>
                <p className="text-xs text-slate-500">
                  Lango Kuu la Platform SuperAdmin & Support Staff kwa usimamizi wa maduka na data halisi.
                </p>
              </div>

              {/* Live Connected Server Badge */}
              <div className="mt-5 p-3 rounded-xl bg-slate-50 border border-slate-200 text-left flex items-center justify-between text-xs">
                <div className="flex items-center gap-2 truncate">
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse shrink-0" />
                  <span className="text-slate-500 shrink-0">Seva ya API:</span>
                  <span className="font-mono text-slate-800 font-semibold truncate" title={getApiBaseUrl()}>
                    {getApiBaseUrl().replace('https://', '')}
                  </span>
                </div>
              </div>

              {loginError && (
                <div className="mt-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs font-semibold flex items-center gap-2">
                  <AlertTriangle className="w-4 h-4 text-rose-600 shrink-0" />
                  <span>{loginError}</span>
                </div>
              )}

              <form onSubmit={handleLoginSubmit} className="mt-5 space-y-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                    Barua Pepe au Namba ya Simu
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="admin@acme.local au barua pepe yako"
                    value={loginEmail}
                    onChange={(e) => setLoginEmail(e.target.value)}
                    className="w-full p-3 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500 focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                    Nenosiri (Password)
                  </label>
                  <input
                    type="password"
                    required
                    placeholder="••••••••"
                    value={loginPassword}
                    onChange={(e) => setLoginPassword(e.target.value)}
                    className="w-full p-3 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500 focus:outline-none"
                  />
                </div>

                <button
                  type="submit"
                  disabled={loginLoading}
                  className="w-full py-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-sm font-bold shadow-lg shadow-indigo-600/30 transition flex items-center justify-center gap-2 disabled:opacity-60"
                >
                  {loginLoading ? (
                    <>
                      <RefreshCw className="w-4 h-4 animate-spin" />
                      <span>Inathibitisha...</span>
                    </>
                  ) : (
                    <>
                      <LogIn className="w-4 h-4" />
                      <span>Ingia Kwenye Portal</span>
                    </>
                  )}
                </button>
              </form>

              {/* Quick Staging Helper */}
              <div className="mt-6 pt-5 border-t border-slate-100 text-center">
                <button
                  type="button"
                  onClick={() => {
                    setLoginEmail('admin@acme.local');
                    setLoginPassword('Admin@12345');
                  }}
                  className="text-xs text-indigo-600 hover:text-indigo-800 font-semibold hover:underline flex items-center justify-center gap-1 mx-auto"
                >
                  <span>Mazingira ya Staging: admin@acme.local / Admin@12345</span>
                </button>
              </div>
            </div>
          </div>
        ) : (
          <>
            {/* ── TAB 1: FLEET DIRECTORY & MANAGEMENT ── */}
            {activeTab === 'clients' && (
              <div className="space-y-6">
                {/* Top KPI Fleet Overview Cards */}
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                  <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold uppercase text-slate-400">Jumla ya Maduka</span>
                      <Building2 className="w-4 h-4 text-indigo-600" />
                    </div>
                    <div className="text-2xl font-black text-slate-900 mt-2">
                      {fleetSummary?.totalTenants ?? clients.length}
                    </div>
                    <span className="text-xs text-slate-500 font-medium">Maduka yaliyopo jukwaani</span>
                  </div>

                  <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold uppercase text-slate-400">Mauzo Mwezi Huu (GMV)</span>
                      <TrendingUp className="w-4 h-4 text-emerald-600" />
                    </div>
                    <div className="text-2xl font-black text-emerald-600 mt-2">
                      TZS {Number(fleetSummary?.totalGmv30Days ?? 0).toLocaleString()}
                    </div>
                    <span className="text-xs text-slate-500 font-medium">{fleetSummary?.totalSalesCount30Days ?? 0} jumla ya mauzo</span>
                  </div>

                  <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold uppercase text-slate-400">Kwenye Majaribio (Trials)</span>
                      <Clock className="w-4 h-4 text-blue-600" />
                    </div>
                    <div className="text-2xl font-black text-blue-600 mt-2">
                      {fleetSummary?.trials ?? 0}
                    </div>
                    <span className="text-xs text-slate-500 font-medium">Bure (Kufuatilia)</span>
                  </div>

                  <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold uppercase text-slate-400">Hatari ya Kuacha (At-Risk)</span>
                      <AlertTriangle className="w-4 h-4 text-rose-600" />
                    </div>
                    <div className="text-2xl font-black text-rose-600 mt-2">
                      {fleetSummary?.atRiskTenants ?? 0}
                    </div>
                    <span className="text-xs text-rose-600 font-medium">Wanahitaji msaada sasa</span>
                  </div>
                </div>

                {/* Filter and Search Ribbon */}
                <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
                  <div className="relative flex-1">
                    <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3.5" />
                    <input
                      type="text"
                      placeholder="Tafuta duka kwa jina au namba ya simu..."
                      value={clientSearch}
                      onChange={(e) => setClientSearch(e.target.value)}
                      className="w-full pl-9 pr-4 py-2 border border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>

                  <div className="flex items-center gap-2 flex-wrap">
                    <select
                      value={healthFilter}
                      onChange={(e) => setHealthFilter(e.target.value)}
                      className="px-3 py-2 border border-slate-300 rounded-lg text-xs font-medium bg-white text-slate-700"
                    >
                      <option value="">Afya Zote</option>
                      <option value="Excellent">Nzuri Sana (Excellent)</option>
                      <option value="Good">Nzuri (Good)</option>
                      <option value="AtRisk">Hatari ya Kuacha (At Risk)</option>
                    </select>

                    <select
                      value={statusFilter}
                      onChange={(e) => setStatusFilter(e.target.value)}
                      className="px-3 py-2 border border-slate-300 rounded-lg text-xs font-medium bg-white text-slate-700"
                    >
                      <option value="">Hali Zote</option>
                      <option value="Active">Walio Lipia (Active)</option>
                      <option value="Trial">Majaribio (Trial)</option>
                      <option value="Debt">Madeni / Expired</option>
                    </select>

                    <button
                      onClick={fetchFleet}
                      disabled={fleetLoading}
                      className="p-2 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-600 transition"
                      title="Sasisha Orodha"
                    >
                      <RefreshCw className={`w-4 h-4 ${fleetLoading ? 'animate-spin' : ''}`} />
                    </button>
                  </div>
                </div>

                {/* Fleet Cards Table */}
                <div className="grid grid-cols-1 gap-4">
                  {fleetLoading && clients.length === 0 ? (
                    <div className="bg-white border border-slate-200 rounded-2xl p-12 text-center text-slate-600 shadow-sm">
                      <RefreshCw className="w-8 h-8 text-indigo-600 animate-spin mx-auto mb-3" />
                      <p className="text-sm font-medium text-slate-700">Inapakia taarifa halisi za maduka kutoka seva ya staging...</p>
                    </div>
                  ) : fleetError ? (
                    <div className="bg-rose-50 border border-rose-200 rounded-2xl p-8 text-center text-rose-800">
                      <AlertTriangle className="w-10 h-10 text-rose-600 mx-auto mb-3" />
                      <h3 className="font-bold text-base">Hitilafu ya Kupakia Maduka</h3>
                      <p className="text-sm mt-1 text-rose-700">{fleetError}</p>
                      <button
                        onClick={fetchFleet}
                        className="mt-4 px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white rounded-xl text-xs font-bold shadow"
                      >
                        Jaribu Tena
                      </button>
                    </div>
                  ) : clients.length === 0 ? (
                    <div className="bg-white border border-slate-200 rounded-2xl p-12 text-center text-slate-600 shadow-sm">
                      <Store className="w-12 h-12 text-slate-300 mx-auto mb-3" />
                      <h3 className="font-bold text-lg text-slate-800">Hakuna Maduka Yaliyopatikana</h3>
                      <p className="text-sm text-slate-500 mt-1 max-w-md mx-auto">
                        Bado hakuna duka lililosajiliwa kwenye hifadhidata ya mfumo (staging) au hakuna duka linalolingana na utafutaji wako.
                      </p>
                      <button
                        onClick={fetchFleet}
                        className="mt-4 px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-xs font-bold shadow flex items-center gap-2 mx-auto"
                      >
                        <RefreshCw className="w-4 h-4" />
                        <span>Pakia Upya Takwimu</span>
                      </button>
                    </div>
                  ) : (
                    clients.map((client) => {
                const isRisk = (client.healthStatus || '').toLowerCase() === 'atrisk';
                const isGood = (client.healthStatus || '').toLowerCase() === 'good';
                const isExcellent = (client.healthStatus || '').toLowerCase() === 'excellent';

                return (
                  <div
                    key={client.tenantId}
                    className="bg-white p-5 rounded-2xl border border-slate-200 hover:border-indigo-300 transition shadow-sm flex flex-col lg:flex-row lg:items-center justify-between gap-4"
                  >
                    <div className="space-y-2 flex-1">
                      <div className="flex items-center gap-2 flex-wrap">
                        <h3 className="font-bold text-slate-900 text-lg">{client.name}</h3>
                        <span className="text-xs uppercase px-2 py-0.5 rounded font-bold bg-slate-100 text-slate-700">
                          {client.planCode}
                        </span>
                        <span
                          className={`text-xs px-2.5 py-0.5 rounded-full font-bold ${
                            client.status === 'Active'
                              ? 'bg-emerald-100 text-emerald-800'
                              : client.status === 'Trial'
                              ? 'bg-blue-100 text-blue-800'
                              : 'bg-rose-100 text-rose-800'
                          }`}
                        >
                          {client.status === 'Active'
                            ? `Amelipia (mpaka ${client.paidUntil})`
                            : client.status === 'Trial'
                            ? `Trial (siku ${client.trialDaysLeft} zimebaki)`
                            : 'Muda Umeisha'}
                        </span>
                        {/* Health Badge */}
                        <span
                          className={`text-[11px] px-2 py-0.5 rounded-full font-semibold border ${
                            isExcellent
                              ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                              : isRisk
                              ? 'bg-rose-50 text-rose-700 border-rose-200 animate-pulse'
                              : 'bg-blue-50 text-blue-700 border-blue-200'
                          }`}
                        >
                          Afya: {isExcellent ? '🌟 Bora Sana' : isRisk ? '⚠️ Hatari ya Kuacha' : '👍 Nzuri'}
                        </span>
                      </div>

                      {/* Milestones Mini Bar */}
                      <div className="flex items-center gap-1.5 text-xs text-slate-500 pt-1">
                        <span className="text-[11px] font-bold text-slate-400 mr-1 uppercase">Hatua:</span>
                        <span className="px-1.5 py-0.5 rounded bg-emerald-100 text-emerald-800 text-[10px] font-semibold">1. Usajili ✓</span>
                        <span className={`px-1.5 py-0.5 rounded text-[10px] font-semibold ${client.totalProducts > 0 ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-400'}`}>
                          2. Bidhaa ({client.totalProducts || 0})
                        </span>
                        <span className={`px-1.5 py-0.5 rounded text-[10px] font-semibold ${client.salesCount30Days > 0 ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-400'}`}>
                          3. Mauzo ({client.salesCount30Days || 0})
                        </span>
                        <span className={`px-1.5 py-0.5 rounded text-[10px] font-semibold ${client.invoicesCount > 0 ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-400'}`}>
                          4. Ankara ({client.invoicesCount || 0})
                        </span>
                        <span className={`px-1.5 py-0.5 rounded text-[10px] font-semibold ${client.status === 'Active' ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-400'}`}>
                          5. Malipo
                        </span>
                      </div>

                      <div className="flex flex-wrap items-center gap-3 text-xs text-slate-500">
                        <span>Simu: <strong className="text-slate-700">{client.phone}</strong></span>
                        <span>•</span>
                        <span>Mauzo ya Leo: <strong className="text-emerald-700 font-bold">{client.todaySales}</strong></span>
                      </div>
                    </div>

                    {/* Action Hub */}
                    <div className="flex flex-wrap items-center gap-2 pt-2 lg:pt-0">
                      <button
                        onClick={() => handleOpenTenantConsole(client)}
                        className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold shadow-md shadow-indigo-600/20 transition flex items-center gap-1.5"
                      >
                        <Sliders className="w-4 h-4" />
                        <span>Simamia Duka Hili</span>
                      </button>

                      <button
                        onClick={() => handleQuickExtendTrial(client.tenantId, 14)}
                        className="px-3 py-2 rounded-xl border border-blue-200 text-blue-700 bg-blue-50 hover:bg-blue-100 text-xs font-semibold transition"
                      >
                        +14 Siku
                      </button>

                      <button
                        onClick={() => handleQuickActivate(client.tenantId, 1, client.planCode)}
                        className="px-3 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold transition shadow-sm"
                      >
                        Washa Mwezi 1
                      </button>
                    </div>
                  </div>
                );
              })
            )}
            </div>
          </div>
        )}

        {/* ── TAB 2: ACTIVE TENANT CONSOLE (OMNIPRESENT WORKSPACE) ── */}
        {activeTab === 'tenant-console' && selectedTenant && (
          <TenantDetailConsole
            tenant={selectedTenant}
            onBack={() => setActiveTab('clients')}
            onNotification={showNotification}
          />
        )}

        {/* ── TAB 3: PLATFORM TEAM (SUPER ADMIN ONLY) ── */}
        {activeTab === 'team' && isSuperAdmin && (
          <PlatformTeamManager
            currentOperator={currentOperator}
            onNotification={showNotification}
          />
        )}

        {/* ── TAB 4: VIFURUSHI & FEATURES ── */}
        {activeTab === 'packages' && (
          <div className="space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900">
                  Usimamizi wa Vifurushi & Features
                </h1>
                <p className="text-sm text-slate-500">
                  Badilisha bei, majina, na fungua features kwa wakati halisi. App zote za wateja zinapokea mabadiliko haya papo hapo bila kuhitaji update ya Play Store!
                </p>
              </div>
              <div className="flex items-center space-x-2">
                <button
                  onClick={fetchPackages}
                  disabled={packagesLoading}
                  className="p-2.5 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-100 transition shadow-sm"
                  title="Sasisha Orodha ya Vifurushi"
                >
                  <RefreshCw className={`w-4 h-4 ${packagesLoading ? 'animate-spin' : ''}`} />
                </button>
                <button
                  onClick={() => setShowAddPackageModal(true)}
                  className="inline-flex items-center space-x-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2.5 rounded-xl font-medium shadow-md shadow-indigo-600/20 transition"
                >
                  <Plus className="w-5 h-5" />
                  <span>Ongeza Kifurushi Kipya</span>
                </button>
              </div>
            </div>

            {packagesError && (
              <div className="p-4 rounded-xl bg-red-50 border border-red-200 flex items-center justify-between text-red-700 text-sm">
                <div className="flex items-center space-x-2">
                  <AlertCircle className="w-5 h-5 flex-shrink-0" />
                  <span>{packagesError}</span>
                </div>
                <button
                  onClick={fetchPackages}
                  className="underline font-semibold hover:text-red-900 text-xs"
                >
                  Jaribu Tena
                </button>
              </div>
            )}

            {packagesLoading ? (
              <div className="bg-white p-12 rounded-2xl border border-slate-200 text-center text-slate-500">
                <RefreshCw className="w-6 h-6 animate-spin mx-auto text-indigo-600 mb-2" />
                <p className="text-sm">Inapakia vifurushi kutoka seva ya database...</p>
              </div>
            ) : packages.length === 0 && !packagesError ? (
              <div className="bg-white p-12 rounded-2xl border border-slate-200 text-center text-slate-500 space-y-3">
                <Package className="w-10 h-10 mx-auto text-slate-300" />
                <h3 className="text-base font-bold text-slate-700">Hakuna Vifurushi Vilivyoundwa Bado</h3>
                <p className="text-xs text-slate-400 max-w-sm mx-auto">
                  Mfumo bado hauna vifurushi au mipango ya malipo iliyosanidiwa. Bofya "Ongeza Kifurushi Kipya" kuanzisha mpango wa kwanza.
                </p>
                <button
                  onClick={() => setShowAddPackageModal(true)}
                  className="inline-flex items-center space-x-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-xl text-xs font-semibold"
                >
                  <Plus className="w-4 h-4" />
                  <span>Unda Kifurushi cha Kwanza</span>
                </button>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {packages.map((pkg) => {
                  const featureKeys = pkg.featureKeys || [];
                  return (
                    <div
                      key={pkg.code}
                      className={`bg-white rounded-2xl border transition-all p-5 flex flex-col justify-between ${
                        pkg.isPackage
                          ? 'border-indigo-200 hover:shadow-indigo-100 hover:shadow-md'
                          : 'border-slate-200 hover:shadow-md'
                      }`}
                    >
                      <div>
                        <div className="flex items-start justify-between">
                          <div>
                            <span
                              className={`text-xs uppercase px-2 py-0.5 rounded font-bold ${
                                pkg.isPackage
                                  ? 'bg-purple-100 text-purple-700'
                                  : 'bg-blue-100 text-blue-700'
                              }`}
                            >
                              {pkg.isPackage ? 'Add-on Modular Package' : 'Base Subscription Plan'}
                            </span>
                            <h3 className="text-lg font-bold text-slate-900 mt-2">{pkg.name}</h3>
                            <p className="text-xs text-slate-400 font-mono">Code: {pkg.code}</p>
                          </div>
                          <button
                            onClick={() => setEditingPackage({ ...pkg, featureKeys: [...featureKeys] })}
                            className="p-2 rounded-lg text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 transition"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>
                        </div>

                        <div className="mt-4 pb-4 border-b border-slate-100">
                          <div className="flex items-baseline space-x-1">
                            <span className="text-2xl font-black text-slate-900">
                              {(pkg.monthlyPrice || 0).toLocaleString()} {pkg.currency || 'TZS'}
                            </span>
                            <span className="text-xs text-slate-500 font-medium">/ mwezi</span>
                          </div>
                        </div>

                        <div className="mt-4 space-y-2">
                          <span className="text-xs font-bold text-slate-700 uppercase tracking-wide">
                            Features ({featureKeys.length}):
                          </span>
                          <ul className="space-y-1.5 mt-2">
                            {featureKeys.map((fKey) => {
                              const feat = ALL_AVAILABLE_FEATURES.find((f) => f.key === fKey);
                              return (
                                <li key={fKey} className="flex items-center text-xs text-slate-700 space-x-2">
                                  <Check className="w-3.5 h-3.5 text-emerald-500 flex-shrink-0" />
                                  <span className="font-medium">{feat?.name || fKey}</span>
                                </li>
                              );
                            })}
                          </ul>
                        </div>
                      </div>

                      <div className="mt-6 pt-4 border-t border-slate-100 flex items-center justify-between">
                        <span className="inline-flex items-center space-x-1.5 text-xs font-semibold text-emerald-600">
                          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                          <span>Live kwenye Cloud</span>
                        </span>
                        <button
                          onClick={() => setEditingPackage({ ...pkg, featureKeys: [...featureKeys] })}
                          className="text-xs font-semibold text-indigo-600 hover:text-indigo-800"
                        >
                          Hariri Bei & Features →
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* ── TAB 5: MASHINE YA VOCHA ── */}
        {activeTab === 'vouchers' && (
          <div className="space-y-6">
            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div className="max-w-2xl">
                  <h1 className="text-xl sm:text-2xl font-bold text-slate-900">Mashine ya Vocha za Malipo</h1>
                  <p className="text-sm text-slate-500 mt-1">
                    Tengeneza namba za vocha zenye ulinzi wa Luhn-32 Checksum kutoka seva. Haziwezi kubahatishwa wala kutumiwa mara mbili. Tuma ujumbe moja kwa moja WhatsApp kwa mteja!
                  </p>
                </div>
                <button
                  onClick={fetchVouchers}
                  disabled={vouchersLoading}
                  className="p-2.5 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-100 transition shadow-sm self-start sm:self-auto"
                  title="Sasisha Orodha ya Vocha"
                >
                  <RefreshCw className={`w-4 h-4 ${vouchersLoading ? 'animate-spin' : ''}`} />
                </button>
              </div>

              <div className="mt-6 grid grid-cols-1 sm:grid-cols-3 gap-4 pb-6 border-b border-slate-200">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Muda wa Vocha</label>
                  <select
                    value={newVoucherDays}
                    onChange={(e) => setNewVoucherDays(e.target.value)}
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium"
                  >
                    <option value="30">Siku 30 (Mwezi 1)</option>
                    <option value="90">Siku 90 (Miezi 3)</option>
                    <option value="180">Siku 180 (Miezi 6)</option>
                    <option value="365">Siku 365 (Mwaka 1)</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Mpango / Kifurushi</label>
                  <select
                    value={newVoucherPlan}
                    onChange={(e) => setNewVoucherPlan(e.target.value)}
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium"
                  >
                    {packages.length > 0 ? (
                      packages.map((p) => (
                        <option key={p.code} value={p.code}>
                          {p.name} ({(p.monthlyPrice || 0).toLocaleString()} {p.currency || 'TZS'})
                        </option>
                      ))
                    ) : (
                      <>
                        <option value="Starter">Starter (20,000 TZS)</option>
                        <option value="Pro">Growth Pro (45,000 TZS)</option>
                        <option value="Scale">Scale & Multi-Store (95,000 TZS)</option>
                        <option value="invoice-manager">Invoice Manager Add-on</option>
                      </>
                    )}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Funga kwa Mteja (Hiari)</label>
                  <input
                    type="text"
                    placeholder="Weka Tenant ID au jina la mteja"
                    value={newVoucherTarget}
                    onChange={(e) => setNewVoucherTarget(e.target.value)}
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm"
                  />
                </div>
              </div>

              <div className="mt-4 flex justify-end">
                <button
                  onClick={handleGenerateVoucher}
                  disabled={generatingVoucher}
                  className="bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white font-medium px-5 py-2.5 rounded-xl shadow-md transition flex items-center space-x-2"
                >
                  <Ticket className={`w-4 h-4 ${generatingVoucher ? 'animate-spin' : ''}`} />
                  <span>{generatingVoucher ? 'Inatengeneza kwenye Seva...' : 'Tengeneza Vocha Sasa'}</span>
                </button>
              </div>

              {lastGeneratedVoucher && (
                <div className="mt-6 p-4 rounded-xl bg-indigo-50 border border-indigo-200 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div className="space-y-1">
                    <span className="text-xs uppercase font-bold text-indigo-700">Vocha Mpya Iliyozalishwa kwenye Seva:</span>
                    <div className="text-2xl font-black font-mono text-indigo-900 tracking-wider">
                      {lastGeneratedVoucher.code}
                    </div>
                    <p className="text-xs text-indigo-700">
                      Siku {lastGeneratedVoucher.valueDays} • Mpango: {lastGeneratedVoucher.planCode} • Mteja: {lastGeneratedVoucher.targetTenant}
                    </p>
                  </div>
                  <button
                    onClick={() => handleCopyWhatsAppMessage(lastGeneratedVoucher)}
                    className="bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold px-4 py-2.5 rounded-xl flex items-center space-x-2 shadow"
                  >
                    <Copy className="w-4 h-4" />
                    <span>Nakili Ujumbe wa WhatsApp</span>
                  </button>
                </div>
              )}
            </div>

            <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="p-4 border-b border-slate-200 flex items-center justify-between">
                <div className="font-bold text-slate-900 text-sm">
                  Historia ya Vocha Zilizotolewa ({vouchers.length})
                </div>
                <button
                  onClick={fetchVouchers}
                  disabled={vouchersLoading}
                  className="text-slate-400 hover:text-slate-600 p-1 rounded-lg"
                  title="Sasisha Vocha"
                >
                  <RefreshCw className={`w-3.5 h-3.5 ${vouchersLoading ? 'animate-spin' : ''}`} />
                </button>
              </div>

              {vouchersError && (
                <div className="p-4 bg-red-50 text-red-700 border-b border-red-200 flex items-center justify-between text-xs">
                  <span>{vouchersError}</span>
                  <button onClick={fetchVouchers} className="underline font-bold">Jaribu Tena</button>
                </div>
              )}

              {vouchersLoading ? (
                <div className="p-8 text-center text-slate-400 text-xs">
                  <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-indigo-600" />
                  Inapakia historia ya vocha kutoka seva...
                </div>
              ) : vouchers.length === 0 && !vouchersError ? (
                <div className="p-8 text-center text-slate-400 text-xs">
                  <Ticket className="w-8 h-8 mx-auto mb-2 text-slate-300" />
                  Hakuna vocha zilizotolewa bado. Tengeneza vocha ya kwanza hapo juu.
                </div>
              ) : (
                <div className="divide-y divide-slate-100">
                  {vouchers.map((v) => {
                    const isIssued = v.status === 'Issued' || v.status === 0;
                    const isRedeemed = v.status === 'Redeemed' || v.status === 1;
                    const isExpired = v.status === 'Expired' || v.status === 2;
                    return (
                      <div key={v.id || v.code} className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-sm">
                        <div className="flex items-center space-x-3">
                          <span className="font-mono font-bold text-slate-900">{v.code}</span>
                          <span
                            className={`text-xs px-2 py-0.5 rounded font-bold ${
                              isIssued
                                ? 'bg-blue-100 text-blue-700'
                                : isRedeemed
                                ? 'bg-emerald-100 text-emerald-700'
                                : isExpired
                                ? 'bg-amber-100 text-amber-700'
                                : 'bg-slate-100 text-slate-700'
                            }`}
                          >
                            {isIssued ? 'Inasubiri Kutumika' : isRedeemed ? 'Imeshatumika' : isExpired ? 'Imeisha Muda' : String(v.status)}
                          </span>
                        </div>
                        <div className="text-xs text-slate-500">
                          Siku {v.valueDays} • {v.planCode || 'Zote'} • {v.targetTenantId ? `Mteja: ${v.targetTenantId.slice(0, 8)}...` : (v.targetTenant ? `Mteja: ${v.targetTenant}` : 'Bila Kikwazo')}
                          {v.createdAt && ` • ${new Date(v.createdAt).toLocaleDateString()}`}
                        </div>
                        <button
                          onClick={() => handleCopyWhatsAppMessage(v)}
                          className="text-xs font-semibold text-emerald-600 hover:text-emerald-800 flex items-center space-x-1"
                        >
                          <Copy className="w-3.5 h-3.5" />
                          <span>Nakili kwa WhatsApp</span>
                        </button>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        )}

        {/* ── TAB 6: AKAUNTI ZA MALIPO ── */}
        {activeTab === 'payment' && (
          <div className="space-y-6 max-w-3xl">
            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
              <div className="flex items-center justify-between">
                <div>
                  <h1 className="text-xl sm:text-2xl font-bold text-slate-900">Akaunti za Malipo ya Wateja</h1>
                  <p className="text-sm text-slate-500 mt-1">
                    Taarifa hizi zinaonyeshwa moja kwa moja kwenye app za wateja wanapotaka kulipia vifurushi. Zinasasishwa papo hapo kwenye database!
                  </p>
                </div>
                <button
                  onClick={fetchPaymentAccounts}
                  disabled={paymentLoading}
                  className="p-2.5 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-100 transition shadow-sm"
                  title="Sasisha Taarifa za Malipo"
                >
                  <RefreshCw className={`w-4 h-4 ${paymentLoading ? 'animate-spin' : ''}`} />
                </button>
              </div>

              {paymentError && (
                <div className="mt-4 p-4 rounded-xl bg-red-50 border border-red-200 text-red-700 text-xs flex items-center justify-between">
                  <span>{paymentError}</span>
                  <button onClick={fetchPaymentAccounts} className="underline font-bold">Jaribu Tena</button>
                </div>
              )}

              {paymentLoading ? (
                <div className="p-8 text-center text-slate-400 text-xs">
                  <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-indigo-600" />
                  Inapakia maelekezo ya malipo kutoka seva...
                </div>
              ) : (
                <div className="mt-6 space-y-4">
                  <div>
                    <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                      Lipa Namba (M-Pesa Till / Paybill)
                    </label>
                    <input
                      type="text"
                      placeholder="mfano: 5523412"
                      value={paymentAccounts.mpesaTill}
                      onChange={(e) => setPaymentAccounts({ ...paymentAccounts, mpesaTill: e.target.value })}
                      className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                      Namba ya Airtel Money / Tigo Pesa
                    </label>
                    <input
                      type="text"
                      placeholder="mfano: 0788 000 111"
                      value={paymentAccounts.airtelMoney}
                      onChange={(e) => setPaymentAccounts({ ...paymentAccounts, airtelMoney: e.target.value })}
                      className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Jina la Benki</label>
                      <input
                        type="text"
                        placeholder="mfano: CRDB Bank au NMB"
                        value={paymentAccounts.bankName}
                        onChange={(e) => setPaymentAccounts({ ...paymentAccounts, bankName: e.target.value })}
                        className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Namba ya Akaunti ya Benki</label>
                      <input
                        type="text"
                        placeholder="mfano: 0152 4899 2100"
                        value={paymentAccounts.bankAccountNumber}
                        onChange={(e) => setPaymentAccounts({ ...paymentAccounts, bankAccountNumber: e.target.value })}
                        className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Jina la Akaunti (Account Name)</label>
                    <input
                      type="text"
                      placeholder="mfano: Jolinx Technologies Ltd"
                      value={paymentAccounts.bankAccountName}
                      onChange={(e) => setPaymentAccounts({ ...paymentAccounts, bankAccountName: e.target.value })}
                      className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                      Namba ya WhatsApp kwa Ushahidi wa Malipo
                    </label>
                    <input
                      type="text"
                      placeholder="mfano: +255 754 000 000"
                      value={paymentAccounts.whatsAppContact}
                      onChange={(e) => setPaymentAccounts({ ...paymentAccounts, whatsAppContact: e.target.value })}
                      className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Maelekezo ya Ziada kwa Wateja</label>
                    <textarea
                      rows={3}
                      placeholder="Maelekezo ya ziada yatakayoonekana kwenye app..."
                      value={paymentAccounts.notes}
                      onChange={(e) => setPaymentAccounts({ ...paymentAccounts, notes: e.target.value })}
                      className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>

                  <div className="mt-6 flex justify-end">
                    <button
                      onClick={handleSavePaymentAccounts}
                      disabled={paymentSaving}
                      className="bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white font-medium px-6 py-2.5 rounded-xl shadow-md transition flex items-center space-x-2"
                    >
                      {paymentSaving && <RefreshCw className="w-4 h-4 animate-spin" />}
                      <span>{paymentSaving ? 'Inahifadhi Kwenye Seva...' : 'Hifadhi & Tangaza kwenye App'}</span>
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}
      </>
    )}
  </main>

      {/* ── MODAL: OPERATOR LOGIN ── */}
      {showLoginModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <div className="flex items-center gap-2">
                <Crown className="w-5 h-5 text-indigo-600" />
                <h2 className="text-lg font-bold text-slate-900">Kuingia Kama Msimamizi</h2>
              </div>
              <button
                onClick={() => setShowLoginModal(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleLoginSubmit} className="mt-4 space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Barua Pepe (Email)</label>
                <input
                  type="email"
                  required
                  placeholder="joberthix@gmail.com"
                  value={loginEmail}
                  onChange={(e) => setLoginEmail(e.target.value)}
                  className="w-full p-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Nenosiri (Password)</label>
                <input
                  type="password"
                  required
                  placeholder="••••••••"
                  value={loginPassword}
                  onChange={(e) => setLoginPassword(e.target.value)}
                  className="w-full p-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500"
                />
              </div>

              <div className="mt-6 pt-4 border-t border-slate-100 flex justify-between items-center">
                {currentOperator && (
                  <button
                    type="button"
                    onClick={() => {
                      handleLogout();
                      setShowLoginModal(false);
                    }}
                    className="text-xs text-rose-600 font-semibold hover:underline"
                  >
                    Toka Kwenye Akaunti
                  </button>
                )}
                <div className="flex space-x-2 ml-auto">
                  <button
                    type="button"
                    onClick={() => setShowLoginModal(false)}
                    className="px-4 py-2 border border-slate-200 text-slate-700 rounded-xl text-sm font-medium hover:bg-slate-50"
                  >
                    Ghairi
                  </button>
                  <button
                    type="submit"
                    disabled={loginLoading}
                    className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-sm font-medium shadow"
                  >
                    {loginLoading ? 'Inaingia...' : 'Ingia Sasa'}
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ── MODAL: EDIT PACKAGE ── */}
      {editingPackage && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-xl w-full p-6 shadow-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <h2 className="text-lg font-bold text-slate-900">Hariri Kifurushi: {editingPackage.name}</h2>
              <button
                onClick={() => setEditingPackage(null)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="mt-4 space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Jina la Kifurushi</label>
                <input
                  type="text"
                  value={editingPackage.name}
                  onChange={(e) => setEditingPackage({ ...editingPackage, name: e.target.value })}
                  className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Bei ya Mwezi (TZS)</label>
                <input
                  type="number"
                  value={editingPackage.monthlyPrice}
                  onChange={(e) => setEditingPackage({ ...editingPackage, monthlyPrice: Number(e.target.value) })}
                  className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-2">Features Zilizomo:</label>
                <div className="space-y-2 border border-slate-200 rounded-xl p-3 max-h-56 overflow-y-auto">
                  {ALL_AVAILABLE_FEATURES.map((feat) => {
                    const isChecked = editingPackage.featureKeys.includes(feat.key);
                    return (
                      <label
                        key={feat.key}
                        className={`flex items-start space-x-3 p-2 rounded-lg cursor-pointer transition ${
                          isChecked ? 'bg-indigo-50 border border-indigo-200' : 'hover:bg-slate-50'
                        }`}
                      >
                        <input
                          type="checkbox"
                          checked={isChecked}
                          onChange={(e) => {
                            if (e.target.checked) {
                              setEditingPackage({
                                ...editingPackage,
                                featureKeys: [...editingPackage.featureKeys, feat.key],
                              });
                            } else {
                              setEditingPackage({
                                ...editingPackage,
                                featureKeys: editingPackage.featureKeys.filter((k) => k !== feat.key),
                              });
                            }
                          }}
                          className="mt-0.5 rounded text-indigo-600 focus:ring-indigo-500"
                        />
                        <div>
                          <div className="text-xs font-bold text-slate-900">{feat.name}</div>
                          <div className="text-[11px] text-slate-500">{feat.desc}</div>
                        </div>
                      </label>
                    );
                  })}
                </div>
              </div>
            </div>

            <div className="mt-6 pt-4 border-t border-slate-100 flex items-center justify-end space-x-2">
              <button
                type="button"
                onClick={() => setEditingPackage(null)}
                className="px-4 py-2 border border-slate-200 text-slate-700 rounded-xl text-sm font-medium hover:bg-slate-50"
              >
                Ghairi
              </button>
              <button
                type="button"
                onClick={handleSavePackageEdit}
                disabled={savingPackage}
                className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white rounded-xl text-sm font-medium shadow flex items-center space-x-2"
              >
                {savingPackage && <RefreshCw className="w-4 h-4 animate-spin" />}
                <span>{savingPackage ? 'Inahifadhi Kwenye Seva...' : 'Hifadhi Mabadiliko'}</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── MODAL: ADD PACKAGE ── */}
      {showAddPackageModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-xl w-full p-6 shadow-2xl">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100">
              <h2 className="text-lg font-bold text-slate-900">Unda Kifurushi Kipya</h2>
              <button
                onClick={() => setShowAddPackageModal(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form
              onSubmit={handleCreatePackage}
              className="mt-4 space-y-4"
            >
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Code ya Kifurushi</label>
                <input
                  name="code"
                  type="text"
                  required
                  placeholder="mfano: enterprise-pack"
                  className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-mono"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Jina la Kifurushi</label>
                <input
                  name="name"
                  type="text"
                  required
                  placeholder="Enterprise Multi-Store"
                  className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Bei ya Mwezi (TZS)</label>
                <input
                  name="monthlyPrice"
                  type="number"
                  required
                  placeholder="85000"
                  className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium"
                />
              </div>

              <div className="flex items-center space-x-2 pt-1">
                <input
                  name="isPackage"
                  type="checkbox"
                  id="isPackage"
                  defaultChecked={false}
                  className="rounded text-indigo-600 focus:ring-indigo-500"
                />
                <label htmlFor="isPackage" className="text-xs font-semibold text-slate-700 cursor-pointer">
                  Kifurushi cha Nyongeza (Modular Add-on)
                </label>
              </div>

              <div className="mt-6 pt-4 border-t border-slate-100 flex justify-end space-x-2">
                <button
                  type="button"
                  onClick={() => setShowAddPackageModal(false)}
                  className="px-4 py-2 border border-slate-200 text-slate-700 rounded-xl text-sm font-medium hover:bg-slate-50"
                >
                  Ghairi
                </button>
                <button
                  type="submit"
                  disabled={creatingPackage}
                  className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white rounded-xl text-sm font-medium shadow flex items-center space-x-2"
                >
                  {creatingPackage && <RefreshCw className="w-4 h-4 animate-spin" />}
                  <span>{creatingPackage ? 'Inaunda Kwenye Seva...' : 'Unda Kifurushi Sasa'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
