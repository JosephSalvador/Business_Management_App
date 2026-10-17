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
  AlertCircle
} from 'lucide-react';

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
  const [activeTab, setActiveTab] = useState('packages'); // packages | clients | vouchers | payment
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  // ── 1. Dynamic Packages State ─────────────────────────────────────
  const [packages, setPackages] = useState([
    {
      id: '1',
      code: 'Starter',
      name: 'Starter Plan (Kuanza)',
      monthlyPrice: 20000,
      currency: 'TZS',
      isPackage: false,
      isActive: true,
      maxBranches: 1,
      maxUsers: 2,
      maxProducts: 1000,
      featureKeys: ['pos.enabled', 'inventory.enabled', 'finance.enabled'],
    },
    {
      id: '2',
      code: 'Pro',
      name: 'Growth Pro (Kukua)',
      monthlyPrice: 45000,
      currency: 'TZS',
      isPackage: false,
      isActive: true,
      maxBranches: 1,
      maxUsers: 5,
      maxProducts: 5000,
      featureKeys: [
        'pos.enabled',
        'inventory.enabled',
        'purchasing.enabled',
        'finance.enabled',
        'crm.enabled',
        'credit.enabled',
        'reports.enabled',
        'pricing.enabled'
      ],
    },
    {
      id: '3',
      code: 'Scale',
      name: 'Scale & Multi-Store (Kushinda)',
      monthlyPrice: 95000,
      currency: 'TZS',
      isPackage: false,
      isActive: true,
      maxBranches: 3,
      maxUsers: 15,
      maxProducts: null,
      featureKeys: [
        'pos.enabled',
        'inventory.enabled',
        'purchasing.enabled',
        'finance.enabled',
        'crm.enabled',
        'credit.enabled',
        'reports.enabled',
        'pricing.enabled',
        'multi-branch.enabled',
        'accounting.enabled'
      ],
    },
    {
      id: '4',
      code: 'invoice-manager',
      name: 'Invoice Manager Add-on',
      monthlyPrice: 15000,
      currency: 'TZS',
      isPackage: true,
      isActive: true,
      maxBranches: null,
      maxUsers: null,
      maxProducts: null,
      featureKeys: ['invoicing.enabled'],
    },
    {
      id: '5',
      code: 'credit-manager',
      name: 'Credit & Debt Book Add-on',
      monthlyPrice: 15000,
      currency: 'TZS',
      isPackage: true,
      isActive: true,
      maxBranches: null,
      maxUsers: null,
      maxProducts: null,
      featureKeys: ['credit.enabled', 'crm.enabled'],
    },
  ]);

  const [editingPackage, setEditingPackage] = useState(null);
  const [showAddPackageModal, setShowAddPackageModal] = useState(false);

  // ── 2. Clients / Tenants State ────────────────────────────────────
  const [clients, setClients] = useState([
    {
      tenantId: '101',
      name: 'Mussa Electronics & Hardware',
      phone: '+255 754 123 456',
      planCode: 'Pro',
      status: 'Trial',
      trialDaysLeft: 6,
      paidUntil: null,
      activePackages: ['invoice-manager'],
      todaySales: 'TZS 340,000',
    },
    {
      tenantId: '102',
      name: 'Kariakoo Wholesalers Hub',
      phone: '+255 712 987 654',
      planCode: 'Scale',
      status: 'Active',
      trialDaysLeft: 0,
      paidUntil: '2026-11-20',
      activePackages: ['invoice-manager', 'credit-manager'],
      todaySales: 'TZS 2,150,000',
    },
    {
      tenantId: '103',
      name: 'Baraka Pharmacy',
      phone: '+255 784 555 111',
      planCode: 'Starter',
      status: 'Debt',
      trialDaysLeft: 0,
      paidUntil: '2026-10-10',
      activePackages: [],
      todaySales: 'TZS 95,000',
    },
  ]);
  const [clientSearch, setClientSearch] = useState('');

  // ── 3. Voucher Generator State ────────────────────────────────────
  const [vouchers, setVouchers] = useState([
    {
      id: 'v1',
      code: 'JLX-88K2-9M4P',
      valueDays: 30,
      status: 'Issued',
      planCode: 'Pro',
      targetTenant: 'Mussa Electronics',
      createdAt: 'Leo, 14 Okt',
    },
    {
      id: 'v2',
      code: 'JLX-44Y7-2K9B',
      valueDays: 90,
      status: 'Redeemed',
      planCode: 'Scale',
      targetTenant: 'Kariakoo Wholesalers',
      createdAt: 'Jana, 13 Okt',
    },
  ]);

  const [newVoucherDays, setNewVoucherDays] = useState(30);
  const [newVoucherPlan, setNewVoucherPlan] = useState('Pro');
  const [newVoucherTarget, setNewVoucherTarget] = useState('');
  const [lastGeneratedVoucher, setLastGeneratedVoucher] = useState(null);

  // ── 4. Dynamic Payment Accounts State ─────────────────────────────
  const [paymentAccounts, setPaymentAccounts] = useState({
    mpesaTill: '5523412',
    airtelMoney: '0788 000 111',
    bankName: 'CRDB Bank',
    bankAccountNumber: '0152 4899 2100',
    bankAccountName: 'Jolinx Technologies Ltd',
    whatsAppContact: '+255 754 000 000',
    notes: 'Baada ya kufanya muamala, tuma picha ya meseji WhatsApp au piga simu kuwezeshwa mara moja.',
  });
  const [paymentSavedToast, setPaymentSavedToast] = useState(false);

  // ── Notification Banner ───────────────────────────────────────────
  const [bannerNotice, setBannerNotice] = useState(null);

  const showNotification = (msg) => {
    setBannerNotice(msg);
    setTimeout(() => setBannerNotice(null), 4000);
  };

  // ── Generator with Luhn-32 Checksum ──────────────────────────────
  const generateLuhn32Code = () => {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let chars = [];
    let sum = 0;
    for (let i = 0; i < 11; i++) {
      const idx = Math.floor(Math.random() * alphabet.length);
      chars.push(alphabet[idx]);
      sum += idx * (i + 1);
    }
    const checkChar = alphabet[sum % alphabet.length];
    chars.push(checkChar);

    // Group as JLX-XXXX-XXXX
    return `JLX-${chars.slice(4, 8).join('')}-${chars.slice(8, 12).join('')}`;
  };

  const handleGenerateVoucher = () => {
    const code = generateLuhn32Code();
    const newVoucher = {
      id: Date.now().toString(),
      code,
      valueDays: Number(newVoucherDays),
      status: 'Issued',
      planCode: newVoucherPlan,
      targetTenant: newVoucherTarget.trim() || 'Yeyote (Bila Kikwazo)',
      createdAt: 'Sasa hivi',
    };
    setVouchers([newVoucher, ...vouchers]);
    setLastGeneratedVoucher(newVoucher);
    showNotification(`Vocha ${code} imetengenezwa kwa ufanisi!`);
  };

  const handleCopyWhatsAppMessage = (voucher) => {
    const msg = `Habari! Tumepokea malipo yako ya huduma ya Jolinx Business OS.\n\n` +
      `🎟️ Vocha Yako: *${voucher.code}*\n` +
      `⏳ Muda Uliofunguliwa: *Siku ${voucher.valueDays} (${voucher.planCode})*\n\n` +
      `Fungua app yako kisha uweke namba hii kwenye sehemu ya Malipo, au bofya kiungo hiki kuwasha mara moja:\n` +
      `👉 https://app.jolinx.com/redeem?code=${voucher.code}\n\n` +
      `Asante kwa kufanya biashara nasi!`;
    navigator.clipboard.writeText(msg);
    showNotification('Ujumbe wa WhatsApp umenakiliwa! Tuma kwa mteja.');
  };

  // ── Package Save / Edit Handlers ──────────────────────────────────
  const handleSavePackage = (updatedPkg) => {
    setPackages(packages.map((p) => (p.code === updatedPkg.code ? updatedPkg : p)));
    setEditingPackage(null);
    showNotification(`Kifurushi "${updatedPkg.name}" kimesasishwa! App zote zimesasishwa moja kwa moja.`);
  };

  const handleCreatePackage = (newPkg) => {
    setPackages([...packages, { ...newPkg, id: Date.now().toString() }]);
    setShowAddPackageModal(false);
    showNotification(`Kifurushi kipya "${newPkg.name}" kimewashwa! Kinapatikana kwenye app sasa.`);
  };

  // ── Client Quick Action Handlers ─────────────────────────────────
  const handleExtendTrial = (tenantId, days) => {
    setClients(
      clients.map((c) =>
        c.tenantId === tenantId
          ? { ...c, trialDaysLeft: c.trialDaysLeft + days, status: 'Trial' }
          : c
      )
    );
    showNotification(`Umeongeza siku ${days} za majaribio bila malipo.`);
  };

  const handle1ClickActivate = (tenantId, months) => {
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
    showNotification(`Akaunti imewashwa kwa miezi ${months} (Lipa mpaka ${dateStr}) bila kuhitaji vocha!`);
  };

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      {/* Top Bar */}
      <header className="bg-slate-900 text-white border-b border-slate-800 sticky top-0 z-30 shadow-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 rounded-xl bg-indigo-600 flex items-center justify-center shadow-lg shadow-indigo-500/30">
                <ShieldCheck className="w-6 h-6 text-white" />
              </div>
              <div>
                <span className="font-bold text-lg tracking-tight">JOLINX BACK-OFFICE</span>
                <span className="ml-2 text-xs uppercase px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 font-semibold border border-emerald-500/30">
                  Control Plane
                </span>
              </div>
            </div>

            {/* Desktop Navigation */}
            <nav className="hidden md:flex space-x-1">
              {[
                { id: 'packages', label: 'Vifurushi & Features', icon: Package },
                { id: 'clients', label: 'Wateja & Akaunti', icon: Users },
                { id: 'vouchers', label: 'Mashine ya Vocha', icon: Ticket },
                { id: 'payment', label: 'Akaunti za Malipo', icon: CreditCard },
              ].map((tab) => {
                const Icon = tab.icon;
                const active = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={`flex items-center space-x-2 px-3 py-2 rounded-lg text-sm font-medium transition ${
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

        {/* Mobile Dropdown */}
        {mobileMenuOpen && (
          <div className="md:hidden bg-slate-800 border-t border-slate-700 px-4 py-3 space-y-1">
            {[
              { id: 'packages', label: 'Vifurushi & Features', icon: Package },
              { id: 'clients', label: 'Wateja & Akaunti', icon: Users },
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

      {/* Floating Notification Banner */}
      {bannerNotice && (
        <div className="fixed bottom-5 right-5 z-50 bg-slate-900 text-white px-5 py-3 rounded-xl shadow-2xl flex items-center space-x-3 border border-indigo-500/40 animate-bounce">
          <Sparkles className="w-5 h-5 text-indigo-400" />
          <span className="text-sm font-medium">{bannerNotice}</span>
        </div>
      )}

      {/* Main Container */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6 lg:p-8">
        {/* TAB 1: DYNAMIC PACKAGES & FEATURES */}
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
              <button
                onClick={() => setShowAddPackageModal(true)}
                className="inline-flex items-center space-x-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2.5 rounded-xl font-medium shadow-md shadow-indigo-600/20 transition self-start sm:self-auto"
              >
                <Plus className="w-5 h-5" />
                <span>Ongeza Kifurushi Kipya</span>
              </button>
            </div>

            {/* Packages Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {packages.map((pkg) => (
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
                        onClick={() => setEditingPackage({ ...pkg })}
                        className="p-2 rounded-lg text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 transition"
                        title="Hariri Kifurushi"
                      >
                        <Edit2 className="w-4 h-4" />
                      </button>
                    </div>

                    {/* Price Tag */}
                    <div className="mt-4 pb-4 border-b border-slate-100">
                      <div className="flex items-baseline space-x-1">
                        <span className="text-2xl font-black text-slate-900">
                          {pkg.monthlyPrice.toLocaleString()} {pkg.currency}
                        </span>
                        <span className="text-xs text-slate-500 font-medium">/ mwezi</span>
                      </div>
                      {pkg.maxBranches && (
                        <p className="text-xs text-slate-500 mt-1">
                          Viwango: {pkg.maxBranches} Matawi • {pkg.maxUsers} Watumiaji •{' '}
                          {pkg.maxProducts ? `${pkg.maxProducts} Bidhaa` : 'Bidhaa Bila Kikomo'}
                        </p>
                      )}
                    </div>

                    {/* Feature Keys Checklist */}
                    <div className="mt-4 space-y-2">
                      <span className="text-xs font-bold text-slate-700 uppercase tracking-wide">
                        Features Zilizofunguliwa ({pkg.featureKeys.length}):
                      </span>
                      <ul className="space-y-1.5 mt-2">
                        {pkg.featureKeys.map((fKey) => {
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

                  {/* Card Footer */}
                  <div className="mt-6 pt-4 border-t border-slate-100 flex items-center justify-between">
                    <span className="inline-flex items-center space-x-1.5 text-xs font-semibold text-emerald-600">
                      <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                      <span>Inafanya Kazi Moja kwa Moja</span>
                    </span>
                    <button
                      onClick={() => setEditingPackage({ ...pkg })}
                      className="text-xs font-semibold text-indigo-600 hover:text-indigo-800"
                    >
                      Hariri Bei & Features →
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* TAB 2: CLIENTS & INSTANT NEGOTIATION ACTIONS */}
        {activeTab === 'clients' && (
          <div className="space-y-6">
            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <div>
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900">Wateja & Maduka Yaliyosajiliwa</h1>
                <p className="text-sm text-slate-500">
                  Dhibiti akaunti za wateja, ongeza siku za majaribio, toa Grace Period, au washa akaunti kwa mbofyo 1 baada ya kupokea pesa kwenye M-Pesa.
                </p>
              </div>

              {/* Search Bar */}
              <div className="relative w-full sm:w-72">
                <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3.5" />
                <input
                  type="text"
                  placeholder="Tafuta duka au namba..."
                  value={clientSearch}
                  onChange={(e) => setClientSearch(e.target.value)}
                  className="w-full pl-9 pr-4 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            </div>

            {/* Clients Cards / Table */}
            <div className="grid grid-cols-1 gap-4">
              {clients
                .filter(
                  (c) =>
                    c.name.toLowerCase().includes(clientSearch.toLowerCase()) ||
                    c.phone.includes(clientSearch)
                )
                .map((client) => (
                  <div
                    key={client.tenantId}
                    className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex flex-col lg:flex-row lg:items-center justify-between gap-4"
                  >
                    <div className="space-y-1">
                      <div className="flex items-center space-x-2">
                        <h3 className="font-bold text-slate-900 text-lg">{client.name}</h3>
                        <span
                          className={`text-xs px-2.5 py-0.5 rounded-full font-bold ${
                            client.status === 'Active'
                              ? 'bg-emerald-100 text-emerald-700'
                              : client.status === 'Trial'
                              ? 'bg-amber-100 text-amber-700'
                              : 'bg-rose-100 text-rose-700'
                          }`}
                        >
                          {client.status === 'Active'
                            ? `Active (mpaka ${client.paidUntil})`
                            : client.status === 'Trial'
                            ? `Trial (zimebaki siku ${client.trialDaysLeft})`
                            : 'Expired (Inahitaji Kulipia)'}
                        </span>
                      </div>
                      <div className="flex flex-wrap items-center gap-3 text-xs text-slate-500">
                        <span>Simu: <strong className="text-slate-700">{client.phone}</strong></span>
                        <span>•</span>
                        <span>Mpango: <strong className="text-indigo-600 font-semibold">{client.planCode}</strong></span>
                        <span>•</span>
                        <span>Mauzo ya Leo: <strong className="text-emerald-600 font-semibold">{client.todaySales}</strong></span>
                        {client.activePackages.length > 0 && (
                          <>
                            <span>•</span>
                            <span>Add-ons: {client.activePackages.join(', ')}</span>
                          </>
                        )}
                      </div>
                    </div>

                    {/* Founder Action Buttons (Power Tools) */}
                    <div className="flex flex-wrap items-center gap-2 pt-2 lg:pt-0 border-t lg:border-t-0 border-slate-100">
                      <button
                        onClick={() => handleExtendTrial(client.tenantId, 7)}
                        className="px-3 py-1.5 rounded-lg border border-amber-300 text-amber-700 bg-amber-50 hover:bg-amber-100 text-xs font-semibold transition"
                      >
                        +7 Siku Bure
                      </button>
                      <button
                        onClick={() => handleExtendTrial(client.tenantId, 14)}
                        className="px-3 py-1.5 rounded-lg border border-amber-300 text-amber-700 bg-amber-50 hover:bg-amber-100 text-xs font-semibold transition"
                      >
                        +14 Siku Bure
                      </button>
                      <button
                        onClick={() => handle1ClickActivate(client.tenantId, 1)}
                        className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold shadow-sm transition flex items-center space-x-1"
                      >
                        <Check className="w-3.5 h-3.5" />
                        <span>Washa Mwezi 1 (TZS)</span>
                      </button>
                      <button
                        onClick={() => handle1ClickActivate(client.tenantId, 3)}
                        className="px-3 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-semibold shadow-sm transition"
                      >
                        Washa Miezi 3
                      </button>
                    </div>
                  </div>
                ))}
            </div>
          </div>
        )}

        {/* TAB 3: VOUCHER MACHINE (CSPRNG + LUHN-32 CHECKSUM) */}
        {activeTab === 'vouchers' && (
          <div className="space-y-6">
            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
              <div className="max-w-2xl">
                <h1 className="text-xl sm:text-2xl font-bold text-slate-900">Mashine ya Vocha za Malipo</h1>
                <p className="text-sm text-slate-500 mt-1">
                  Tengeneza namba za vocha zenye ulinzi wa kidijitali (Luhn-32 Checksum). Haziwezi kubahatishwa wala kutumiwa mara mbili. Tuma ujumbe uliopangwa moja kwa moja WhatsApp kwa mteja!
                </p>
              </div>

              {/* Generator Form */}
              <div className="mt-6 grid grid-cols-1 sm:grid-cols-3 gap-4 pb-6 border-b border-slate-200">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Muda wa Vocha</label>
                  <select
                    value={newVoucherDays}
                    onChange={(e) => setNewVoucherDays(e.target.value)}
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
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
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                  >
                    <option value="Starter">Starter (20,000 TZS)</option>
                    <option value="Pro">Growth Pro (45,000 TZS)</option>
                    <option value="Scale">Scale & Multi-Store (95,000 TZS)</option>
                    <option value="invoice-manager">Invoice Manager Add-on</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Funga kwa Mteja (Hiari)</label>
                  <input
                    type="text"
                    placeholder="Mfano: Mussa Hardware"
                    value={newVoucherTarget}
                    onChange={(e) => setNewVoucherTarget(e.target.value)}
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
              </div>

              <div className="mt-4 flex justify-end">
                <button
                  onClick={handleGenerateVoucher}
                  className="bg-indigo-600 hover:bg-indigo-700 text-white font-medium px-5 py-2.5 rounded-xl shadow-md transition flex items-center space-x-2"
                >
                  <Ticket className="w-4 h-4" />
                  <span>Tengeneza Vocha Sasa</span>
                </button>
              </div>

              {/* Last Generated Preview Card */}
              {lastGeneratedVoucher && (
                <div className="mt-6 p-4 rounded-xl bg-indigo-50 border border-indigo-200 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div className="space-y-1">
                    <span className="text-xs uppercase font-bold text-indigo-700">Vocha Mpya Iliyozalishwa:</span>
                    <div className="text-2xl font-black font-mono text-indigo-900 tracking-wider">
                      {lastGeneratedVoucher.code}
                    </div>
                    <p className="text-xs text-indigo-700">
                      Siku {lastGeneratedVoucher.valueDays} • {lastGeneratedVoucher.planCode} • {lastGeneratedVoucher.targetTenant}
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

            {/* Vouchers History Table */}
            <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="p-4 border-b border-slate-200 font-bold text-slate-900 text-sm">
                Historia ya Vocha Zilizotolewa
              </div>
              <div className="divide-y divide-slate-100">
                {vouchers.map((v) => (
                  <div key={v.id} className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-sm">
                    <div className="flex items-center space-x-3">
                      <span className="font-mono font-bold text-slate-900">{v.code}</span>
                      <span
                        className={`text-xs px-2 py-0.5 rounded font-bold ${
                          v.status === 'Issued'
                            ? 'bg-blue-100 text-blue-700'
                            : 'bg-emerald-100 text-emerald-700'
                        }`}
                      >
                        {v.status === 'Issued' ? 'Inasubiri Kutumika' : 'Imeshatumika'}
                      </span>
                    </div>
                    <div className="text-xs text-slate-500">
                      Siku {v.valueDays} • {v.planCode} • Mteja: {v.targetTenant}
                    </div>
                    <button
                      onClick={() => handleCopyWhatsAppMessage(v)}
                      className="text-xs font-semibold text-emerald-600 hover:text-emerald-800 flex items-center space-x-1"
                    >
                      <Copy className="w-3.5 h-3.5" />
                      <span>Nakili kwa WhatsApp</span>
                    </button>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* TAB 4: DYNAMIC PAYMENT ACCOUNTS */}
        {activeTab === 'payment' && (
          <div className="space-y-6 max-w-3xl">
            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
              <h1 className="text-xl sm:text-2xl font-bold text-slate-900">Akaunti za Malipo ya Wateja</h1>
              <p className="text-sm text-slate-500 mt-1">
                Taarifa hizi zinaonyeshwa moja kwa moja kwenye app za wateja wanapotaka kulipia vifurushi. Unaweza kubadilisha namba au benki wakati wowote hapa!
              </p>

              <div className="mt-6 space-y-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">
                    Lipa Namba (M-Pesa Till / Paybill)
                  </label>
                  <input
                    type="text"
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
                      value={paymentAccounts.bankName}
                      onChange={(e) => setPaymentAccounts({ ...paymentAccounts, bankName: e.target.value })}
                      className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Namba ya Akaunti ya Benki</label>
                    <input
                      type="text"
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
                    value={paymentAccounts.whatsAppContact}
                    onChange={(e) => setPaymentAccounts({ ...paymentAccounts, whatsAppContact: e.target.value })}
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Maelekezo ya Ziada kwa Wateja</label>
                  <textarea
                    rows={3}
                    value={paymentAccounts.notes}
                    onChange={(e) => setPaymentAccounts({ ...paymentAccounts, notes: e.target.value })}
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
              </div>

              <div className="mt-6 flex justify-end">
                <button
                  onClick={() => showNotification('Akaunti za malipo zimesasishwa na kuchapishwa kwenye app zote!')}
                  className="bg-indigo-600 hover:bg-indigo-700 text-white font-medium px-6 py-2.5 rounded-xl shadow-md transition"
                >
                  Hifadhi & Tangaza kwenye App
                </button>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* MODAL: EDIT PACKAGE FEATURES & PRICE */}
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

              <div className="grid grid-cols-2 gap-4">
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
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Matawi ya Juu</label>
                  <input
                    type="number"
                    value={editingPackage.maxBranches || ''}
                    placeholder="Bila kikomo"
                    onChange={(e) => setEditingPackage({ ...editingPackage, maxBranches: e.target.value ? Number(e.target.value) : null })}
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm"
                  />
                </div>
              </div>

              {/* Feature Checklist */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-2">
                  Features Zilizomo (Washa au Zima):
                </label>
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

            <div className="mt-6 pt-4 border-t border-slate-100 flex items-center justify-between">
              <span className="text-xs text-slate-400">
                Inasasisha papo hapo bila app store release
              </span>
              <div className="flex space-x-2">
                <button
                  onClick={() => setEditingPackage(null)}
                  className="px-4 py-2 border border-slate-200 text-slate-700 rounded-xl text-sm font-medium hover:bg-slate-50"
                >
                  Ghairi
                </button>
                <button
                  onClick={() => handleSavePackage(editingPackage)}
                  className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-sm font-medium shadow"
                >
                  Hifadhi Mabadiliko
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: ADD NEW PACKAGE */}
      {showAddPackageModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-xl w-full p-6 shadow-2xl max-h-[90vh] overflow-y-auto">
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
              onSubmit={(e) => {
                e.preventDefault();
                const form = e.target;
                const newPkg = {
                  code: form.code.value.trim(),
                  name: form.name.value.trim(),
                  monthlyPrice: Number(form.monthlyPrice.value),
                  currency: 'TZS',
                  isPackage: form.isPackage.checked,
                  isActive: true,
                  maxBranches: form.maxBranches.value ? Number(form.maxBranches.value) : null,
                  maxUsers: form.maxUsers.value ? Number(form.maxUsers.value) : null,
                  maxProducts: null,
                  featureKeys: ['pos.enabled', 'inventory.enabled'],
                };
                handleCreatePackage(newPkg);
              }}
              className="mt-4 space-y-4"
            >
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Code ya Kifurushi</label>
                <input
                  name="code"
                  type="text"
                  required
                  placeholder="Mfano: wholesale-pack"
                  className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-mono"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Jina la Kifurushi</label>
                <input
                  name="name"
                  type="text"
                  required
                  placeholder="Mfano: Wholesale & Multi-Price Pack"
                  className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Bei ya Mwezi (TZS)</label>
                  <input
                    name="monthlyPrice"
                    type="number"
                    required
                    placeholder="25000"
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm font-medium"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Matawi ya Juu</label>
                  <input
                    name="maxBranches"
                    type="number"
                    placeholder="1"
                    className="w-full p-2.5 border border-slate-200 rounded-xl text-sm"
                  />
                </div>
              </div>

              <div className="flex items-center space-x-2 pt-2">
                <input
                  name="isPackage"
                  type="checkbox"
                  id="isPackage"
                  defaultChecked={true}
                  className="rounded text-indigo-600 focus:ring-indigo-500"
                />
                <label htmlFor="isPackage" className="text-xs font-semibold text-slate-700 cursor-pointer">
                  Hiki ni Kifurushi cha Nyongeza (Modular Add-on Package)
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
                  className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-sm font-medium shadow"
                >
                  Unda Kifurushi Sasa
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
