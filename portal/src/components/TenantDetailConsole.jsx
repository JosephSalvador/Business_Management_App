import React, { useState, useEffect } from 'react';
import {
  ArrowLeft,
  Store,
  Phone,
  MessageCircle,
  ExternalLink,
  ShieldCheck,
  CheckCircle,
  Clock,
  AlertTriangle,
  Package,
  Receipt,
  FileText,
  Wallet,
  Settings,
  Sparkles,
  Calendar,
  Layers,
  Copy,
  Check
} from 'lucide-react';
import OmniProductsTable from './OmniProductsTable';
import OmniSalesTable from './OmniSalesTable';
import OmniInvoicesTable from './OmniInvoicesTable';
import OmniCashSessionsTable from './OmniCashSessionsTable';
import {
  getTenantAdminDetail,
  impersonateTenant,
  extendTenantTrial,
  directActivateTenant,
  updateTenantFeatures
} from '../services/api';

const ALL_FEATURES_LIST = [
  { key: 'pos.enabled', name: 'Point of Sale (POS)', desc: 'Mauzo ya cashier na kutoa risiti' },
  { key: 'inventory.enabled', name: 'Inventory & Stoo', desc: 'Usimamizi wa stoo na rekodi za bidhaa' },
  { key: 'invoicing.enabled', name: 'Invoicing & Ankara', desc: 'Kutoa ankara (invoices) na delivery notes' },
  { key: 'credit.enabled', name: 'Daftari la Madeni (Credit)', desc: 'Kukopesha wateja na vikumbusho' },
  { key: 'purchasing.enabled', name: 'Manunuzi & Wasambazaji', desc: 'LPO na ankara za wasambazaji' },
  { key: 'finance.enabled', name: 'Sajili za Pesa (Cashbook)', desc: 'Kusimamia sanduku la pesa na droo' },
  { key: 'crm.enabled', name: 'Wateja (CRM)', desc: 'Orodha ya wateja na mawasiliano' },
  { key: 'reports.enabled', name: 'Ripoti & Export', desc: 'Ripoti za mauzo, faida na stoo' },
  { key: 'multi-branch.enabled', name: 'Matawi Mengi (Branches)', desc: 'Kusimamia maduka zaidi ya moja' },
];

export default function TenantDetailConsole({ tenant, onBack, onNotification }) {
  const [activeSubTab, setActiveSubTab] = useState('overview'); // overview | sales | products | invoices | cash | settings
  const [detail, setDetail] = useState(tenant);
  const [loading, setLoading] = useState(false);

  // Impersonation Support Mode State
  const [supportTokenModal, setSupportTokenModal] = useState(null);
  const [copiedToken, setCopiedToken] = useState(false);

  // Extend Trial & Direct Activate State
  const [extendDays, setExtendDays] = useState(14);
  const [activateMonths, setActivateMonths] = useState(1);
  const [activatePlan, setActivatePlan] = useState('Pro');

  const fetchDetail = async () => {
    if (!tenant || !tenant.tenantId) return;
    setLoading(true);
    try {
      const res = await getTenantAdminDetail(tenant.tenantId);
      if (res) {
        setDetail(res);
      }
    } catch {
      // Keep initial tenant prop
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDetail();
  }, [tenant.tenantId]);

  const handleLaunchSupportSession = async () => {
    try {
      const res = await impersonateTenant(tenant.tenantId, 'Support assistance from backoffice portal');
      if (res && res.token) {
        setSupportTokenModal(res);
        onNotification?.(`Support session imetengenezwa kwa ${tenant.name}!`);
      } else {
        // Fallback demo support token
        setSupportTokenModal({
          token: `support_demo_jwt_token_${tenant.tenantId}_${Date.now()}`,
          tenantId: tenant.tenantId,
          tenantName: tenant.name,
          clientAppUrl: 'https://jolinx.co.tz/app'
        });
      }
    } catch (err) {
      onNotification?.(`Hitilafu ya Support Session: ${err.message || 'Jaribu tena'}`);
    }
  };

  const handleExtendTrial = async () => {
    try {
      await extendTenantTrial(tenant.tenantId, Number(extendDays));
      setDetail(prev => ({
        ...prev,
        trialDaysLeft: (prev.trialDaysLeft || 0) + Number(extendDays),
        status: 'Trial'
      }));
      onNotification?.(`Umeongeza siku ${extendDays} za majaribio bure kwa ${tenant.name}!`);
    } catch (err) {
      onNotification?.(`Hitilafu kuongeza siku: ${err.message || 'Jaribu tena'}`);
    }
  };

  const handleDirectActivate = async () => {
    try {
      await directActivateTenant(tenant.tenantId, Number(activateMonths), activatePlan);
      const today = new Date();
      today.setDate(today.getDate() + activateMonths * 30);
      const dateStr = today.toISOString().split('T')[0];

      setDetail(prev => ({
        ...prev,
        status: 'Active',
        planCode: activatePlan,
        trialDaysLeft: 0,
        paidUntil: dateStr
      }));
      onNotification?.(`Duka limewashwa kwa miezi ${activateMonths} (${activatePlan})!`);
    } catch (err) {
      onNotification?.(`Hitilafu kuwasha akaunti: ${err.message || 'Jaribu tena'}`);
    }
  };

  const handleToggleFeature = async (featureKey) => {
    const currentFeatures = detail.features || {};
    const newFeatures = {
      ...currentFeatures,
      [featureKey]: !currentFeatures[featureKey]
    };
    try {
      await updateTenantFeatures(tenant.tenantId, newFeatures);
      setDetail(prev => ({ ...prev, features: newFeatures }));
      onNotification?.(`Feature "${featureKey}" imebadilishwa!`);
    } catch (err) {
      onNotification?.(`Hitilafu kubadili feature: ${err.message || 'Jaribu tena'}`);
    }
  };

  const cleanPhone = (detail.phone || '').replace(/[^0-9]/g, '');

  return (
    <div className="space-y-6">
      {/* Top Navigation & Workspace Header */}
      <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <button
            onClick={onBack}
            className="p-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 transition flex items-center justify-center"
            title="Rudi kwenye Orodha ya Maduka"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
                {detail.name || 'Duka la Mteja'}
              </h1>
              <span className="text-xs uppercase px-2.5 py-0.5 rounded-full font-bold bg-indigo-100 text-indigo-700 border border-indigo-200">
                {detail.planCode || 'Pro'}
              </span>
              <span
                className={`text-xs px-2.5 py-0.5 rounded-full font-bold ${
                  detail.status === 'Active'
                    ? 'bg-emerald-100 text-emerald-800'
                    : detail.status === 'Trial'
                    ? 'bg-blue-100 text-blue-800'
                    : 'bg-rose-100 text-rose-800'
                }`}
              >
                {detail.status || 'Active'}
              </span>
            </div>
            <div className="text-xs text-slate-400 mt-1 font-mono flex items-center gap-2">
              <span>ID: {detail.tenantId}</span>
              {detail.category && <span>• {detail.category}</span>}
              {detail.phone && <span>• {detail.phone}</span>}
            </div>
          </div>
        </div>

        {/* Top Direct Action Buttons */}
        <div className="flex items-center gap-2 flex-wrap self-end md:self-auto">
          {detail.phone && (
            <a
              href={`https://wa.me/${cleanPhone}`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-emerald-50 text-emerald-700 border border-emerald-200 text-xs font-semibold hover:bg-emerald-100 transition shadow-sm"
            >
              <MessageCircle className="w-4 h-4 text-emerald-600" />
              <span>WhatsApp</span>
            </a>
          )}

          {detail.phone && (
            <a
              href={`tel:${detail.phone}`}
              className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-100 text-slate-700 text-xs font-semibold hover:bg-slate-200 transition"
            >
              <Phone className="w-4 h-4" />
              <span>Piga Simu</span>
            </a>
          )}

          <button
            onClick={handleLaunchSupportSession}
            className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-xs font-bold shadow-md shadow-indigo-600/20 transition"
          >
            <ExternalLink className="w-4 h-4" />
            <span>🚀 Fungua Kwenye App (Support Login)</span>
          </button>
        </div>
      </div>

      {/* Onboarding Milestones Tracker & Health Banner */}
      <div className="bg-slate-900 text-white p-5 rounded-2xl shadow-lg border border-slate-800 space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Sparkles className="w-5 h-5 text-amber-400" />
            <h3 className="font-bold text-sm tracking-wide">
              Hatua za Ukuaji wa Duka (Onboarding Milestones)
            </h3>
          </div>
          <div className="text-xs text-slate-300">
            Kiwango cha Afya: <strong className="text-emerald-400">{detail.healthStatus || 'Nzuri Sana (Good)'}</strong>
          </div>
        </div>

        {/* 5-Step Milestones Pipeline */}
        <div className="grid grid-cols-2 sm:grid-cols-5 gap-2 pt-1">
          {[
            { step: '1. Usajili', done: true, desc: 'Akaunti imefunguliwa' },
            { step: '2. Bidhaa', done: (detail.totalProducts || 0) > 0, desc: `${detail.totalProducts || 0} Bidhaa stoo` },
            { step: '3. Mauzo POS', done: (detail.salesCount30Days || 0) > 0, desc: `${detail.salesCount30Days || 0} Risiti` },
            { step: '4. Ankara/Invoices', done: (detail.invoicesCount || 0) > 0, desc: `${detail.invoicesCount || 0} Ankara` },
            { step: '5. Kifurushi', done: detail.status === 'Active', desc: detail.status === 'Active' ? 'Amelipia' : 'Bado Trial' }
          ].map((m, idx) => (
            <div
              key={idx}
              className={`p-3 rounded-xl border transition ${
                m.done
                  ? 'bg-slate-800/90 border-emerald-500/40 text-emerald-300'
                  : 'bg-slate-800/40 border-slate-700 text-slate-400'
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-white">{m.step}</span>
                {m.done ? (
                  <CheckCircle className="w-4 h-4 text-emerald-400" />
                ) : (
                  <Clock className="w-4 h-4 text-slate-500" />
                )}
              </div>
              <p className="text-[11px] text-slate-400 mt-1">{m.desc}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Sub Tabs Navigation */}
      <div className="border-b border-slate-200">
        <nav className="flex space-x-2 sm:space-x-4 overflow-x-auto pb-1">
          {[
            { id: 'overview', label: 'Muhtasari', icon: Store },
            { id: 'sales', label: 'Mauzo ya POS', icon: Receipt },
            { id: 'products', label: 'Bidhaa & Stoo', icon: Package },
            { id: 'invoices', label: 'Ankara (Invoices)', icon: FileText },
            { id: 'cash', label: 'Sajili za Pesa', icon: Wallet },
            { id: 'settings', label: 'Vifurushi & Mipangilio', icon: Settings },
          ].map((tab) => {
            const Icon = tab.icon;
            const active = activeSubTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveSubTab(tab.id)}
                className={`flex items-center space-x-2 py-3 px-3.5 border-b-2 font-semibold text-sm transition whitespace-nowrap ${
                  active
                    ? 'border-indigo-600 text-indigo-600'
                    : 'border-transparent text-slate-500 hover:text-slate-800 hover:border-slate-300'
                }`}
              >
                <Icon className="w-4 h-4" />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </nav>
      </div>

      {/* TAB CONTENT: OVERVIEW */}
      {activeSubTab === 'overview' && (
        <div className="space-y-6">
          {/* Quick Metric Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
              <span className="text-xs font-bold uppercase text-slate-400">Mauzo ya Leo</span>
              <div className="text-xl font-extrabold text-slate-900 mt-1">
                {detail.todaySales || 'TZS 0'}
              </div>
              <span className="text-xs text-emerald-600 font-medium">Katika duka hili</span>
            </div>

            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
              <span className="text-xs font-bold uppercase text-slate-400">Mauzo Siku 30 Zilizopita</span>
              <div className="text-xl font-extrabold text-indigo-600 mt-1">
                TZS {Number(detail.totalGmv30Days || 0).toLocaleString()}
              </div>
              <span className="text-xs text-slate-400 font-medium">{detail.salesCount30Days || 0} jumla ya risiti</span>
            </div>

            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
              <span className="text-xs font-bold uppercase text-slate-400">Bidhaa Stoo</span>
              <div className="text-xl font-extrabold text-slate-900 mt-1">
                {detail.totalProducts || 0} Aina
              </div>
              <span className="text-xs text-amber-600 font-medium">
                {detail.lowStockProducts || 0} zenye stoo ndogo
              </span>
            </div>

            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
              <span className="text-xs font-bold uppercase text-slate-400">Hali ya Malipo</span>
              <div className="text-xl font-extrabold text-slate-900 mt-1">
                {detail.status === 'Active' ? 'Amelipia' : `Siku ${detail.trialDaysLeft || 0} zimebaki`}
              </div>
              <span className="text-xs text-slate-400 font-medium">
                {detail.paidUntil ? `Mpaka ${detail.paidUntil}` : 'Majaribio (Trial)'}
              </span>
            </div>
          </div>

          {/* Quick Support & Subscription Controls */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Direct Activation Card */}
            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm space-y-4">
              <div className="flex items-center gap-2 text-indigo-700">
                <ShieldCheck className="w-5 h-5" />
                <h3 className="font-bold text-base text-slate-900">Washa Akaunti Moja kwa Moja (1-Click Activate)</h3>
              </div>
              <p className="text-xs text-slate-500">
                Mteja akilipa kwa Cash, Benki au M-Pesa kwako, washa akaunti yake papo hapo bila kumuomba kuingiza vocha:
              </p>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">Muda wa Kufungua</label>
                  <select
                    value={activateMonths}
                    onChange={(e) => setActivateMonths(Number(e.target.value))}
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white"
                  >
                    <option value={1}>Mwezi 1</option>
                    <option value={3}>Miezi 3</option>
                    <option value={6}>Miezi 6</option>
                    <option value={12}>Mwaka 1 (Miezi 12)</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">Kifurushi (Plan)</label>
                  <select
                    value={activatePlan}
                    onChange={(e) => setActivatePlan(e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white"
                  >
                    <option value="Starter">Starter Plan</option>
                    <option value="Pro">Growth Pro</option>
                    <option value="Scale">Scale Multi-Store</option>
                  </select>
                </div>
              </div>

              <button
                onClick={handleDirectActivate}
                className="w-full py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-bold shadow-md shadow-emerald-600/20 transition"
              >
                Washa Akaunti Sasa
              </button>
            </div>

            {/* Extend Free Trial Card */}
            <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm space-y-4">
              <div className="flex items-center gap-2 text-blue-700">
                <Clock className="w-5 h-5" />
                <h3 className="font-bold text-base text-slate-900">Ongeza Siku za Bure za Majaribio (Extend Trial)</h3>
              </div>
              <p className="text-xs text-slate-500">
                Mpe mteja siku za ziada za kujaribu app ili kumsaidia kuanzisha duka lake vizuri:
              </p>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">Idadi ya Siku za Bure</label>
                <div className="flex gap-2">
                  {[7, 14, 30].map((d) => (
                    <button
                      key={d}
                      type="button"
                      onClick={() => setExtendDays(d)}
                      className={`flex-1 py-2 rounded-lg text-xs font-bold border transition ${
                        extendDays === d
                          ? 'bg-blue-600 text-white border-blue-600'
                          : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100'
                      }`}
                    >
                      +{d} Siku
                    </button>
                  ))}
                </div>
              </div>

              <button
                onClick={handleExtendTrial}
                className="w-full py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-sm font-bold shadow-md shadow-blue-600/20 transition"
              >
                Ongeza Siku {extendDays} za Majaribio
              </button>
            </div>
          </div>
        </div>
      )}

      {/* TAB CONTENT: SALES TABLE */}
      {activeSubTab === 'sales' && (
        <OmniSalesTable
          tenantId={tenant.tenantId}
          tenantName={tenant.name}
          onNotification={onNotification}
        />
      )}

      {/* TAB CONTENT: PRODUCTS TABLE */}
      {activeSubTab === 'products' && (
        <OmniProductsTable
          tenantId={tenant.tenantId}
          tenantName={tenant.name}
          onNotification={onNotification}
        />
      )}

      {/* TAB CONTENT: INVOICES TABLE */}
      {activeSubTab === 'invoices' && (
        <OmniInvoicesTable
          tenantId={tenant.tenantId}
          tenantName={tenant.name}
          onNotification={onNotification}
        />
      )}

      {/* TAB CONTENT: CASH SESSIONS TABLE */}
      {activeSubTab === 'cash' && (
        <OmniCashSessionsTable
          tenantId={tenant.tenantId}
          tenantName={tenant.name}
          onNotification={onNotification}
        />
      )}

      {/* TAB CONTENT: SETTINGS & FEATURES */}
      {activeSubTab === 'settings' && (
        <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm space-y-6">
          <div>
            <h3 className="font-bold text-lg text-slate-900">Usimamizi wa Features za Duka Hili</h3>
            <p className="text-xs text-slate-500">
              Unaweza kuwasha au kuzima moduli mahususi kwa mteja huyu bila kujali kifurushi chake cha msingi:
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {ALL_FEATURES_LIST.map((feat) => {
              const isEnabled = detail.features ? !!detail.features[feat.key] : true;
              return (
                <div
                  key={feat.key}
                  className="p-4 rounded-xl border border-slate-200 hover:border-slate-300 flex items-start justify-between gap-3 bg-slate-50/50"
                >
                  <div>
                    <h4 className="font-bold text-slate-900 text-sm">{feat.name}</h4>
                    <p className="text-xs text-slate-500 mt-0.5">{feat.desc}</p>
                    <span className="text-[10px] font-mono text-slate-400 mt-1 block">{feat.key}</span>
                  </div>

                  <button
                    onClick={() => handleToggleFeature(feat.key)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-bold transition shadow-sm ${
                      isEnabled
                        ? 'bg-emerald-600 text-white hover:bg-emerald-700'
                        : 'bg-slate-200 text-slate-600 hover:bg-slate-300'
                    }`}
                  >
                    {isEnabled ? 'Imewashwa' : 'Imezimwa'}
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Support Mode Impersonation Modal */}
      {supportTokenModal && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-indigo-200 space-y-4">
            <div className="flex items-center gap-2 text-indigo-600">
              <ShieldCheck className="w-6 h-6" />
              <h3 className="font-bold text-lg text-slate-900">Kipindi cha Msaada (Support Session)</h3>
            </div>
            <p className="text-sm text-slate-600">
              Ufunguo huu wa muda mfupi (Support Token - 45 min) unakuwezesha kuingia moja kwa moja kwenye app ya mteja <strong className="text-slate-900">{supportTokenModal.tenantName}</strong> ili kumsaidia:
            </p>

            <div className="bg-slate-900 text-slate-100 p-3 rounded-xl font-mono text-xs break-all select-all border border-slate-800">
              {supportTokenModal.token}
            </div>

            <div className="flex items-center justify-between pt-2">
              <button
                onClick={() => {
                  navigator.clipboard.writeText(supportTokenModal.token);
                  setCopiedToken(true);
                  setTimeout(() => setCopiedToken(false), 3000);
                }}
                className="inline-flex items-center gap-1.5 px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg text-xs font-semibold transition"
              >
                {copiedToken ? <Check className="w-4 h-4 text-emerald-600" /> : <Copy className="w-4 h-4" />}
                <span>{copiedToken ? 'Imenakiliwa!' : 'Nakili Token'}</span>
              </button>

              <div className="flex gap-2">
                <button
                  onClick={() => setSupportTokenModal(null)}
                  className="px-4 py-2 border border-slate-300 rounded-lg text-xs font-medium text-slate-600 hover:bg-slate-50"
                >
                  Funga
                </button>
                <a
                  href={`${supportTokenModal.clientAppUrl || 'https://jolinx.co.tz/app'}?support_token=${supportTokenModal.token}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-xs font-bold shadow-md transition"
                >
                  <ExternalLink className="w-3.5 h-3.5" />
                  <span>Fungua App Kwenye Tab Mpya</span>
                </a>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
