import React, { useState, useEffect } from 'react';
import {
  ExternalLink,
  RefreshCw,
  Copy,
  Check,
  AlertTriangle,
  ShieldAlert,
  KeyRound,
  Lock,
  Unlock,
  LogOut,
  CheckCircle2,
  Circle,
  Tag,
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
  updateTenantFeatures,
  listTenantUsers,
  resetTenantUserPassword,
  toggleTenantUserStatus,
  forceLogoutTenantUser,
  updateTenantStatus,
  updateTenantOnboarding,
} from '../services/api';
import {
  Container,
  PageHeader,
  Button,
  StatusIndicator,
  Badge,
  Tabs,
  Modal,
  KeyValueGrid,
  KpiStrip,
} from '../ui/primitives';

const ALL_FEATURES_LIST = [
  {
    key: 'pos.enabled',
    name: 'Point of Sale (POS)',
    desc: 'Cashier checkout, barcode scanning, and thermal receipts.',
  },
  {
    key: 'inventory.enabled',
    name: 'Inventory & Stock Control',
    desc: 'Stock ledger, warehouse balances, and low-stock alerts.',
  },
  {
    key: 'invoicing.enabled',
    name: 'Invoicing & Delivery Notes',
    desc: 'Proforma invoices, B2B billing, and PDF generation.',
  },
  {
    key: 'credit.enabled',
    name: 'Customer Credit & Debt Book',
    desc: 'Credit sales, customer balances, and repayment tracking.',
  },
  {
    key: 'purchasing.enabled',
    name: 'Purchasing & Suppliers',
    desc: 'Purchase orders, supplier directory, and stock receiving.',
  },
  {
    key: 'finance.enabled',
    name: 'Cashbook & Money Accounts',
    desc: 'Cash drawer shifts, bank/mobile money accounts, and expenses.',
  },
  {
    key: 'crm.enabled',
    name: 'Customer Directory (CRM)',
    desc: 'Customer profiles, purchase history, and contact management.',
  },
  {
    key: 'reports.enabled',
    name: 'Analytics & Reports',
    desc: 'Sales summaries, profit margins, and CSV/PDF exports.',
  },
  {
    key: 'multi-branch.enabled',
    name: 'Multi-Branch Operations',
    desc: 'Manage multiple shops, warehouses, and inter-branch transfers.',
  },
];

export default function TenantDetailConsole({
  tenant,
  supportReason,
  initialSubTab = 'overview',
  onSubTabChange,
  onBack,
  onNotification,
}) {
  const [activeSubTab, setActiveSubTab] = useState(initialSubTab);
  const [detail, setDetail] = useState(tenant);
  const [loading, setLoading] = useState(false);

  // Impersonation Support Mode Modal
  const [supportTokenModal, setSupportTokenModal] = useState(null);
  const [copiedToken, setCopiedToken] = useState(false);
  const [launchingSupport, setLaunchingSupport] = useState(false);

  // Quick Trial & Activation Modal
  const [extendModalOpen, setExtendModalOpen] = useState(false);
  const [extendDays, setExtendDays] = useState(14);
  const [extending, setExtending] = useState(false);

  const [activateModalOpen, setActivateModalOpen] = useState(false);
  const [activateMonths, setActivateMonths] = useState(1);
  const [activatePlan, setActivatePlan] = useState(tenant?.planCode || 'Pro');
  const [activating, setActivating] = useState(false);

  // Feature Overrides
  const [featureOverrides, setFeatureOverrides] = useState({
    'pos.enabled': true,
    'inventory.enabled': true,
    'invoicing.enabled': true,
    'credit.enabled': true,
    'purchasing.enabled': true,
    'finance.enabled': true,
    'crm.enabled': true,
    'reports.enabled': true,
    'multi-branch.enabled': false,
  });
  const [savingFeatures, setSavingFeatures] = useState(false);

  // Suspend / Reactivate Tenant
  const [suspendModalOpen, setSuspendModalOpen] = useState(false);
  const [suspendReason, setSuspendReason] = useState('');
  const [updatingTenantStatus, setUpdatingTenantStatus] = useState(false);

  // Onboarding Checklist, 35,000 TZS Training Paid & Tags
  const [tagsInput, setTagsInput] = useState(tenant?.tags || '');
  const [trainingPaidInput, setTrainingPaidInput] = useState(Boolean(tenant?.trainingPaid));
  const [savingOnboarding, setSavingOnboarding] = useState(false);

  // Tenant Users & Security
  const [tenantUsers, setTenantUsers] = useState(tenant?.users || []);
  const [loadingUsers, setLoadingUsers] = useState(false);
  const [resetPwdUser, setResetPwdUser] = useState(null);
  const [newUserPassword, setNewUserPassword] = useState('');
  const [resettingPwd, setResettingPwd] = useState(false);
  const [userActionLoadingId, setUserActionLoadingId] = useState(null);

  useEffect(() => {
    setActiveSubTab(initialSubTab || 'overview');
  }, [initialSubTab]);

  const handleTabSwitch = (tabId) => {
    setActiveSubTab(tabId);
    onSubTabChange?.(tabId);
    if (tabId === 'users') {
      fetchUsers();
    }
  };

  const fetchDetail = async () => {
    if (!tenant?.tenantId) return;
    setLoading(true);
    try {
      const res = await getTenantAdminDetail(tenant.tenantId);
      if (res) {
        setDetail((prev) => ({ ...prev, ...res }));
        setTagsInput(res.tags || '');
        setTrainingPaidInput(Boolean(res.trainingPaid));
        if (Array.isArray(res.users)) {
          setTenantUsers(res.users);
        }
        if (res.features && typeof res.features === 'object') {
          setFeatureOverrides((prev) => ({ ...prev, ...res.features }));
        }
      }
    } catch {
      // Keep initial tenant summary
    } finally {
      setLoading(false);
    }
  };

  const fetchUsers = async () => {
    if (!tenant?.tenantId) return;
    setLoadingUsers(true);
    try {
      const res = await listTenantUsers(tenant.tenantId);
      if (Array.isArray(res)) {
        setTenantUsers(res);
      }
    } catch {
      // fallback to detail.users
    } finally {
      setLoadingUsers(false);
    }
  };

  useEffect(() => {
    setDetail(tenant);
    setTagsInput(tenant?.tags || '');
    setTrainingPaidInput(Boolean(tenant?.trainingPaid));
    setTenantUsers(tenant?.users || []);
    fetchDetail();
  }, [tenant?.tenantId]);

  const handleToggleTenantStatus = async (e) => {
    if (e) e.preventDefault();
    const nextActive = detail?.isActive === false;
    setUpdatingTenantStatus(true);
    try {
      await updateTenantStatus(tenant.tenantId, nextActive, suspendReason.trim());
      setDetail((prev) => ({ ...prev, isActive: nextActive }));
      setSuspendModalOpen(false);
      setSuspendReason('');
      onNotification?.(
        `${nextActive ? 'Reactivated' : 'Suspended'} tenant ${detail?.name}.`
      );
    } catch (err) {
      onNotification?.(`Failed to update tenant status: ${err.message || 'Please try again'}`);
    } finally {
      setUpdatingTenantStatus(false);
    }
  };

  const handleSaveOnboarding = async () => {
    setSavingOnboarding(true);
    try {
      await updateTenantOnboarding(tenant.tenantId, tagsInput, trainingPaidInput);
      setDetail((prev) => ({
        ...prev,
        tags: tagsInput.trim() || null,
        trainingPaid: trainingPaidInput,
      }));
      onNotification?.(`Saved onboarding & tags for ${detail?.name}.`);
    } catch (err) {
      onNotification?.(`Failed to save onboarding: ${err.message || 'Please try again'}`);
    } finally {
      setSavingOnboarding(false);
    }
  };

  const handleResetUserPassword = async (e) => {
    e.preventDefault();
    if (!resetPwdUser || !newUserPassword.trim()) return;
    setResettingPwd(true);
    try {
      await resetTenantUserPassword(tenant.tenantId, resetPwdUser.id, newUserPassword.trim());
      setResetPwdUser(null);
      setNewUserPassword('');
      onNotification?.(`Password reset & sessions revoked for ${resetPwdUser.email}.`);
    } catch (err) {
      onNotification?.(`Password reset failed: ${err.message || 'Please try again'}`);
    } finally {
      setResettingPwd(false);
    }
  };

  const handleToggleUserStatus = async (u) => {
    setUserActionLoadingId(u.id);
    try {
      const nextActive = !u.isActive;
      await toggleTenantUserStatus(tenant.tenantId, u.id, nextActive);
      setTenantUsers((prev) =>
        prev.map((item) => (item.id === u.id ? { ...item, isActive: nextActive, isLockedOut: false } : item))
      );
      onNotification?.(`${nextActive ? 'Unlocked' : 'Locked'} user ${u.email}.`);
    } catch (err) {
      onNotification?.(`Failed to update user: ${err.message || 'Please try again'}`);
    } finally {
      setUserActionLoadingId(null);
    }
  };

  const handleForceLogoutUser = async (u) => {
    setUserActionLoadingId(u.id);
    try {
      await forceLogoutTenantUser(tenant.tenantId, u.id);
      onNotification?.(`Revoked all active sessions for ${u.email}.`);
    } catch (err) {
      onNotification?.(`Failed to force sign-out: ${err.message || 'Please try again'}`);
    } finally {
      setUserActionLoadingId(null);
    }
  };

  const handleLaunchSupportSession = async () => {
    setLaunchingSupport(true);
    try {
      const res = await impersonateTenant(
        tenant.tenantId,
        supportReason || 'Platform Admin Support Session'
      );
      const token = res?.accessToken || res?.token;
      if (token) {
        setSupportTokenModal({
          token,
          tenantId: res.tenantId || tenant.tenantId,
          tenantName: res.tenantName || detail.name,
          clientAppUrl: res.launchUrl || 'https://app.jolinx.co.tz',
        });
        onNotification?.(`Generated audited support token for ${detail.name}.`);
      } else {
        throw new Error('Server did not return a support access token.');
      }
    } catch (err) {
      onNotification?.(
        `Support session failed: ${err.message || 'Please try again'}`
      );
    } finally {
      setLaunchingSupport(false);
    }
  };

  const handleExtendTrial = async (e) => {
    if (e) e.preventDefault();
    setExtending(true);
    try {
      await extendTenantTrial(tenant.tenantId, Number(extendDays));
      setDetail((prev) => ({
        ...prev,
        trialDaysLeft: (prev.trialDaysLeft || 0) + Number(extendDays),
        status: 'Trial',
      }));
      setExtendModalOpen(false);
      onNotification?.(
        `Extended trial by ${extendDays} days for ${detail.name}.`
      );
    } catch (err) {
      onNotification?.(
        `Failed to extend trial: ${err.message || 'Please try again'}`
      );
    } finally {
      setExtending(false);
    }
  };

  const handleDirectActivate = async (e) => {
    if (e) e.preventDefault();
    setActivating(true);
    try {
      await directActivateTenant(
        tenant.tenantId,
        Number(activateMonths),
        activatePlan
      );
      const expiry = new Date();
      expiry.setDate(expiry.getDate() + Number(activateMonths) * 30);
      const dateStr = expiry.toISOString().split('T')[0];

      setDetail((prev) => ({
        ...prev,
        status: 'Active',
        planCode: activatePlan,
        trialDaysLeft: 0,
        paidUntilUtc: expiry.toISOString(),
        paidUntil: dateStr,
      }));
      setActivateModalOpen(false);
      onNotification?.(
        `Activated ${activatePlan} plan for ${activateMonths} month(s) until ${dateStr}.`
      );
    } catch (err) {
      onNotification?.(
        `Activation failed: ${err.message || 'Please try again'}`
      );
    } finally {
      setActivating(false);
    }
  };

  const handleSaveFeatures = async () => {
    setSavingFeatures(true);
    try {
      await updateTenantFeatures(tenant.tenantId, featureOverrides);
      onNotification?.(`Saved module entitlements for ${detail.name}.`);
    } catch (err) {
      onNotification?.(
        `Failed to update features: ${err.message || 'Please try again'}`
      );
    } finally {
      setSavingFeatures(false);
    }
  };

  const renderStatusBadge = () => {
    const st = (detail?.status || '').toLowerCase();
    if (st === 'active' || st === 'paid') {
      return <StatusIndicator type="success">Active</StatusIndicator>;
    }
    if (st === 'trial') {
      return (
        <StatusIndicator type="info">
          Trial · {detail?.trialDaysLeft ?? 0}d left
        </StatusIndicator>
      );
    }
    if (st === 'debt' || st === 'overdue' || st === 'expired') {
      return <StatusIndicator type="error">Overdue</StatusIndicator>;
    }
    return <StatusIndicator type="pending">{detail?.status || 'Unknown'}</StatusIndicator>;
  };

  const subTabs = [
    { id: 'overview', label: 'Overview' },
    {
      id: 'products',
      label: 'Products',
      count: detail?.productCount ?? detail?.totalProducts,
    },
    {
      id: 'sales',
      label: 'Sales',
      count: detail?.salesCount30d ?? detail?.totalSales,
    },
    { id: 'invoices', label: 'Invoices' },
    { id: 'cash', label: 'Cash sessions' },
    {
      id: 'users',
      label: 'Users & security',
      count: detail?.userCount ?? tenantUsers.length,
    },
    { id: 'subscription', label: 'Subscription & quotas' },
  ];

  return (
    <div className="space-y-4">
      {/* Persistent Audited Support Mode Banner (AWS Switch Role / Stripe Act As style) */}
      <div className="bg-[#FFF4CC] border border-[#E0CA5C] rounded-[4px] px-4 py-2.5 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 text-[#16191F]">
        <div className="flex items-center gap-2 text-[13px]">
          <AlertTriangle className="w-4 h-4 text-[#8D6605] shrink-0" />
          <div>
            <span className="font-bold">Support mode:</span> You are inspecting tenant{' '}
            <span className="font-bold">{detail?.name}</span>. All actions are recorded in the platform audit log.
            {supportReason && (
              <span className="ml-2 text-[#533B04]">
                · <span className="font-semibold">Reason:</span> {supportReason}
              </span>
            )}
          </div>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <Button size="sm" onClick={onBack}>
            Exit tenant
          </Button>
        </div>
      </div>

      {/* Tenant Resource Header */}
      <PageHeader
        title={detail?.name || 'Tenant workspace'}
        badge={
          <div className="flex items-center gap-2 flex-wrap">
            {detail?.isActive === false ? (
              <StatusIndicator type="error">Suspended</StatusIndicator>
            ) : (
              renderStatusBadge()
            )}
            <Badge color="blue">{detail?.planCode || 'Pro'} plan</Badge>
            {detail?.trainingPaid && (
              <Badge color="green">Training Paid</Badge>
            )}
            {detail?.paidUntil && (
              <span className="text-[12px] text-[#5F6B7A]">
                Paid until {detail.paidUntil}
              </span>
            )}
          </div>
        }
        subtitle={`Tenant ID: ${detail?.tenantId || '—'} · Owner: ${
          detail?.ownerName || detail?.ownerEmail || '—'
        } (${detail?.ownerPhone || detail?.phone || 'No phone'})`}
        actions={
          <>
            <Button
              size="md"
              icon={RefreshCw}
              loading={loading}
              onClick={fetchDetail}
            >
              Refresh
            </Button>
            <Button
              size="md"
              variant={detail?.isActive === false ? 'default' : 'danger'}
              icon={ShieldAlert}
              onClick={() => setSuspendModalOpen(true)}
            >
              {detail?.isActive === false ? 'Reactivate' : 'Suspend'}
            </Button>
            <Button size="md" onClick={() => setExtendModalOpen(true)}>
              Extend trial
            </Button>
            <Button size="md" onClick={() => setActivateModalOpen(true)}>
              Activate plan
            </Button>
            <Button
              size="md"
              variant="primary"
              icon={ExternalLink}
              loading={launchingSupport}
              onClick={handleLaunchSupportSession}
            >
              Open in POS app
            </Button>
          </>
        }
      />

      {/* Horizontal Cloudscape Tabs */}
      <div className="bg-white border border-[#D5DBDB] rounded-[8px] shadow-sm overflow-hidden">
        <Tabs
          tabs={subTabs}
          activeId={activeSubTab}
          onChange={handleTabSwitch}
        />

        <div className="p-5 bg-[#F2F3F3]">
          {/* TAB: OVERVIEW */}
          {activeSubTab === 'overview' && (
            <div className="space-y-4">
              <KpiStrip
                metrics={[
                  {
                    label: 'Sales volume (30d)',
                    value: `TZS ${Number(
                      detail?.salesVolume30d ?? detail?.gmv30d ?? 0
                    ).toLocaleString()}`,
                    sub: `${detail?.salesCount30d ?? detail?.totalSales ?? 0} transactions`,
                  },
                  {
                    label: 'Catalog products',
                    value: Number(
                      detail?.productCount ?? detail?.totalProducts ?? 0
                    ).toLocaleString(),
                    sub: 'Active SKU records',
                  },
                  {
                    label: 'Branches & stores',
                    value: Number(
                      detail?.branchCount ?? detail?.branches?.length ?? 1
                    ).toLocaleString(),
                    sub: 'Configured locations',
                  },
                  {
                    label: 'Staff accounts',
                    value: Number(
                      detail?.userCount ?? detail?.users?.length ?? 1
                    ).toLocaleString(),
                    sub: 'Active operators',
                  },
                ]}
              />

              <Container title="Tenant details">
                <KeyValueGrid
                  columns={4}
                  items={[
                    {
                      label: 'Organization name',
                      value: detail?.name || '—',
                    },
                    {
                      label: 'Tenant ID',
                      value: (
                        <span className="font-mono text-[12px]">
                          {detail?.tenantId || '—'}
                        </span>
                      ),
                    },
                    {
                      label: 'Owner contact',
                      value: detail?.ownerPhone || detail?.phone || '—',
                      sub: detail?.ownerEmail || '',
                    },
                    {
                      label: 'Created date',
                      value: detail?.createdAt
                        ? new Date(detail.createdAt).toLocaleDateString()
                        : '—',
                    },
                    {
                      label: 'Subscription status',
                      value: renderStatusBadge(),
                    },
                    {
                      label: 'Current plan',
                      value: detail?.planCode || 'Pro',
                    },
                    {
                      label: 'Last activity',
                      value: detail?.lastActivityAt
                        ? new Date(detail.lastActivityAt).toLocaleString()
                        : detail?.lastActive || '—',
                    },
                    {
                      label: 'Health status',
                      value: detail?.health || 'Healthy',
                    },
                  ]}
                />
              </Container>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <Container
                  title="Branches"
                  count={(detail?.branches || []).length}
                  noPadding
                >
                  <table className="w-full text-left border-collapse text-[13px]">
                    <thead>
                      <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase text-[#5F6B7A]">
                        <th className="py-2 px-4">Branch name</th>
                        <th className="py-2 px-4">Location</th>
                        <th className="py-2 px-4">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[#E9EBED]">
                      {(detail?.branches || []).length === 0 ? (
                        <tr>
                          <td colSpan={3} className="py-6 text-center text-[#5F6B7A]">
                            Main branch active.
                          </td>
                        </tr>
                      ) : (
                        detail.branches.map((b, i) => (
                          <tr key={b.id || i}>
                            <td className="py-2 px-4 font-medium text-[#16191F]">
                              {b.name}
                            </td>
                            <td className="py-2 px-4 text-[#5F6B7A]">
                              {b.address || b.city || '—'}
                            </td>
                            <td className="py-2 px-4">
                              <StatusIndicator type="success">Active</StatusIndicator>
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </Container>

                <Container
                  title="Tenant users"
                  count={(detail?.users || []).length}
                  noPadding
                >
                  <table className="w-full text-left border-collapse text-[13px]">
                    <thead>
                      <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase text-[#5F6B7A]">
                        <th className="py-2 px-4">Name</th>
                        <th className="py-2 px-4">Email / Phone</th>
                        <th className="py-2 px-4">Role</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[#E9EBED]">
                      {(detail?.users || []).length === 0 ? (
                        <tr>
                          <td colSpan={3} className="py-6 text-center text-[#5F6B7A]">
                            {detail?.ownerEmail || detail?.ownerPhone || 'Owner account active'}
                          </td>
                        </tr>
                      ) : (
                        detail.users.map((u, i) => (
                          <tr key={u.id || i}>
                            <td className="py-2 px-4 font-medium text-[#16191F]">
                              {u.fullName || u.name || 'User'}
                            </td>
                            <td className="py-2 px-4 font-mono text-[12px] text-[#5F6B7A]">
                              {u.email || u.phone || '—'}
                            </td>
                            <td className="py-2 px-4">
                              <Badge>{u.role || 'Staff'}</Badge>
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </Container>
              </div>

              {/* Onboarding Checklist, 35,000 TZS Training Fee, Tags & Usage Quotas */}
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <Container
                  title="Onboarding checklist & tenant tags"
                  description="Track shop activation readiness, 35,000 TZS training & installation fee, and segmentation tags."
                >
                  <div className="space-y-4">
                    <div className="grid grid-cols-2 gap-2.5 text-[13px]">
                      {[
                        { label: 'Profile completed', ok: Boolean(detail?.hasProfileCompleted) },
                        { label: 'Catalog products (> 0)', ok: Boolean(detail?.hasProducts || (detail?.totalProducts || 0) > 0) },
                        { label: 'First sale recorded', ok: Boolean(detail?.hasSales || (detail?.salesCount30Days || 0) > 0) },
                        { label: '35,000 TZS Training Paid', ok: Boolean(detail?.trainingPaid) },
                      ].map((step) => (
                        <div
                          key={step.label}
                          className={`flex items-center gap-2 px-3 py-2 rounded-[4px] border ${
                            step.ok
                              ? 'bg-[#F2F8F0] border-[#B8E0B4] text-[#037F0C]'
                              : 'bg-[#FAFAFA] border-[#E9EBED] text-[#5F6B7A]'
                          }`}
                        >
                          {step.ok ? (
                            <CheckCircle2 className="w-4 h-4 shrink-0" />
                          ) : (
                            <Circle className="w-4 h-4 shrink-0" />
                          )}
                          <span className="font-medium">{step.label}</span>
                        </div>
                      ))}
                    </div>

                    <div className="pt-2 border-t border-[#E9EBED] space-y-3">
                      <label className="flex items-center justify-between gap-3 cursor-pointer p-2.5 rounded-[4px] border border-[#D5DBDB] bg-[#FAFAFA]">
                        <div>
                          <div className="text-[13px] font-semibold text-[#16191F]">
                            35,000 TZS Training & Installation Paid
                          </div>
                          <div className="text-[11px] text-[#5F6B7A]">
                            Mark once onboarding training and setup fee is settled.
                          </div>
                        </div>
                        <input
                          type="checkbox"
                          checked={trainingPaidInput}
                          onChange={(e) => setTrainingPaidInput(e.target.checked)}
                          className="w-4 h-4 accent-[#0972D3]"
                        />
                      </label>

                      <div>
                        <label className="flex items-center gap-1.5 text-[12px] font-semibold text-[#16191F] mb-1">
                          <Tag className="w-3.5 h-3.5 text-[#5F6B7A]" />
                          <span>Tenant tags (comma-separated)</span>
                        </label>
                        <div className="flex gap-2">
                          <input
                            type="text"
                            value={tagsInput}
                            onChange={(e) => setTagsInput(e.target.value)}
                            placeholder="e.g. VIP, Kariakoo, Needs-Training"
                            className="flex-1 px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] bg-white"
                          />
                          <Button
                            variant="primary"
                            size="md"
                            loading={savingOnboarding}
                            onClick={handleSaveOnboarding}
                          >
                            Save
                          </Button>
                        </div>
                      </div>
                    </div>
                  </div>
                </Container>

                <Container
                  title="Plan usage & quotas"
                  description={`Resource consumption against ${detail?.planCode || 'Pro'} plan limits.`}
                >
                  <div className="space-y-4">
                    {[
                      {
                        label: 'Catalog products',
                        used: detail?.totalProducts ?? 0,
                        max: detail?.maxProducts,
                      },
                      {
                        label: 'Active staff users',
                        used: detail?.userCount ?? tenantUsers.length ?? 1,
                        max: detail?.maxUsers,
                      },
                      {
                        label: 'Shop branches',
                        used: detail?.branchCount ?? (detail?.branches || []).length ?? 1,
                        max: detail?.maxBranches,
                      },
                    ].map((meter) => {
                      const limit = meter.max && meter.max > 0 ? meter.max : null;
                      const pct = limit ? Math.min(100, Math.round((meter.used / limit) * 100)) : 0;
                      const barColor =
                        pct >= 90 ? 'bg-[#D91515]' : pct >= 75 ? 'bg-[#D97706]' : 'bg-[#0972D3]';
                      return (
                        <div key={meter.label}>
                          <div className="flex items-center justify-between text-[13px] mb-1">
                            <span className="font-medium text-[#16191F]">{meter.label}</span>
                            <span className="font-mono text-[12px] text-[#5F6B7A]">
                              {meter.used} / {limit ?? 'Unlimited'}
                              {limit ? ` (${pct}%)` : ''}
                            </span>
                          </div>
                          <div className="w-full h-2 bg-[#E9EBED] rounded-full overflow-hidden">
                            <div
                              className={`h-full ${barColor} transition-all`}
                              style={{ width: `${limit ? pct : 12}%` }}
                            />
                          </div>
                        </div>
                      );
                    })}
                    <div className="pt-2 border-t border-[#E9EBED] text-[12px] text-[#5F6B7A] flex items-center justify-between">
                      <span>Last recorded activity</span>
                      <span className="font-mono text-[#16191F]">
                        {detail?.lastActivityAt
                          ? new Date(detail.lastActivityAt).toLocaleString()
                          : '—'}
                      </span>
                    </div>
                  </div>
                </Container>
              </div>
            </div>
          )}

          {/* TAB: PRODUCTS */}
          {activeSubTab === 'products' && (
            <OmniProductsTable
              tenantId={detail?.tenantId}
              tenantName={detail?.name}
              onNotification={onNotification}
            />
          )}

          {/* TAB: SALES */}
          {activeSubTab === 'sales' && (
            <OmniSalesTable
              tenantId={detail?.tenantId}
              onNotification={onNotification}
            />
          )}

          {/* TAB: INVOICES */}
          {activeSubTab === 'invoices' && (
            <OmniInvoicesTable
              tenantId={detail?.tenantId}
              onNotification={onNotification}
            />
          )}

          {/* TAB: CASH SESSIONS */}
          {activeSubTab === 'cash' && (
            <OmniCashSessionsTable tenantId={detail?.tenantId} />
          )}

          {/* TAB: USERS & SECURITY */}
          {activeSubTab === 'users' && (
            <Container
              title="Tenant users & access security"
              description="Manage tenant staff accounts, reset forgotten passwords, lock/unlock compromised accounts, or revoke active POS sessions."
              count={tenantUsers.length}
              noPadding
              actions={
                <Button size="sm" icon={RefreshCw} loading={loadingUsers} onClick={fetchUsers}>
                  Refresh
                </Button>
              }
            >
              <table className="w-full text-left border-collapse text-[13px]">
                <thead>
                  <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase text-[#5F6B7A]">
                    <th className="py-2.5 px-4">Name</th>
                    <th className="py-2.5 px-4">Email / Phone</th>
                    <th className="py-2.5 px-4">Role</th>
                    <th className="py-2.5 px-4">Status</th>
                    <th className="py-2.5 px-4 text-right">Security actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#E9EBED]">
                  {tenantUsers.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="py-8 text-center text-[#5F6B7A]">
                        {loadingUsers ? 'Loading tenant users...' : 'No users found for this tenant.'}
                      </td>
                    </tr>
                  ) : (
                    tenantUsers.map((u) => {
                      const busy = userActionLoadingId === u.id;
                      return (
                        <tr key={u.id} className="hover:bg-[#F9FAFB]">
                          <td className="py-2.5 px-4 font-semibold text-[#16191F]">
                            {u.fullName || 'User'}
                          </td>
                          <td className="py-2.5 px-4 font-mono text-[12px] text-[#5F6B7A]">
                            <div>{u.email || '—'}</div>
                            {u.phone && <div className="text-[11px]">{u.phone}</div>}
                          </td>
                          <td className="py-2.5 px-4">
                            <Badge color="blue">{u.role || 'Staff'}</Badge>
                          </td>
                          <td className="py-2.5 px-4">
                            {!u.isActive ? (
                              <StatusIndicator type="error">Locked / Disabled</StatusIndicator>
                            ) : u.isLockedOut ? (
                              <StatusIndicator type="warning">Temp Lockout</StatusIndicator>
                            ) : (
                              <StatusIndicator type="success">Active</StatusIndicator>
                            )}
                          </td>
                          <td className="py-2.5 px-4">
                            <div className="flex items-center justify-end gap-1.5 flex-wrap">
                              <Button
                                size="sm"
                                icon={KeyRound}
                                disabled={busy}
                                onClick={() => {
                                  setResetPwdUser(u);
                                  setNewUserPassword('');
                                }}
                              >
                                Reset password
                              </Button>
                              <Button
                                size="sm"
                                icon={u.isActive ? Lock : Unlock}
                                loading={busy}
                                onClick={() => handleToggleUserStatus(u)}
                              >
                                {u.isActive ? 'Lock' : 'Unlock'}
                              </Button>
                              <Button
                                size="sm"
                                icon={LogOut}
                                loading={busy}
                                onClick={() => handleForceLogoutUser(u)}
                              >
                                Force sign-out
                              </Button>
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </Container>
          )}

          {/* TAB: SUBSCRIPTION & QUOTAS */}
          {activeSubTab === 'subscription' && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <Container
                  title="Extend trial period"
                  description="Grant complimentary trial days without requiring a voucher or payment."
                >
                  <div className="flex items-end gap-3">
                    <div className="flex-1">
                      <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                        Additional days
                      </label>
                      <select
                        value={extendDays}
                        onChange={(e) => setExtendDays(Number(e.target.value))}
                        className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] bg-white"
                      >
                        <option value={7}>7 days</option>
                        <option value={14}>14 days</option>
                        <option value={30}>30 days</option>
                        <option value={60}>60 days</option>
                      </select>
                    </div>
                    <Button
                      variant="primary"
                      loading={extending}
                      onClick={handleExtendTrial}
                    >
                      Grant trial days
                    </Button>
                  </div>
                </Container>

                <Container
                  title="Direct subscription activation"
                  description="Immediately activate paid access after confirming bank or mobile money receipt."
                >
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 items-end">
                    <div>
                      <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                        Plan
                      </label>
                      <select
                        value={activatePlan}
                        onChange={(e) => setActivatePlan(e.target.value)}
                        className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] bg-white"
                      >
                        <option value="Starter">Starter</option>
                        <option value="Pro">Pro</option>
                        <option value="Scale">Scale</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                        Duration
                      </label>
                      <select
                        value={activateMonths}
                        onChange={(e) => setActivateMonths(Number(e.target.value))}
                        className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] bg-white"
                      >
                        <option value={1}>1 month (30d)</option>
                        <option value={3}>3 months (90d)</option>
                        <option value={6}>6 months (180d)</option>
                        <option value={12}>12 months (365d)</option>
                      </select>
                    </div>
                    <Button
                      variant="primary"
                      loading={activating}
                      onClick={handleDirectActivate}
                    >
                      Activate now
                    </Button>
                  </div>
                </Container>
              </div>

              <Container
                title="Module & feature entitlements"
                description="Enable or disable specific functional modules for this tenant workspace."
                actions={
                  <Button
                    variant="primary"
                    size="sm"
                    loading={savingFeatures}
                    onClick={handleSaveFeatures}
                  >
                    Save entitlements
                  </Button>
                }
              >
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                  {ALL_FEATURES_LIST.map((feat) => {
                    const enabled = Boolean(featureOverrides[feat.key]);
                    return (
                      <label
                        key={feat.key}
                        className={`border rounded-[6px] p-3 flex items-start gap-2.5 cursor-pointer transition-colors ${
                          enabled
                            ? 'bg-[#F1F8FF] border-[#0972D3]'
                            : 'bg-white border-[#D5DBDB] hover:bg-[#FAFAFA]'
                        }`}
                      >
                        <input
                          type="checkbox"
                          checked={enabled}
                          onChange={(e) =>
                            setFeatureOverrides({
                              ...featureOverrides,
                              [feat.key]: e.target.checked,
                            })
                          }
                          className="mt-0.5 rounded-[2px] border-[#879596] text-[#0972D3] focus:ring-[#0972D3]"
                        />
                        <div>
                          <div className="text-[13px] font-semibold text-[#16191F]">
                            {feat.name}
                          </div>
                          <div className="text-[11px] text-[#5F6B7A] mt-0.5">
                            {feat.desc}
                          </div>
                          <div className="text-[10px] font-mono text-[#5F6B7A] mt-1">
                            {feat.key}
                          </div>
                        </div>
                      </label>
                    );
                  })}
                </div>
              </Container>
            </div>
          )}
        </div>
      </div>

      {/* Extend Trial Modal */}
      <Modal
        open={extendModalOpen}
        onClose={() => setExtendModalOpen(false)}
        title={`Extend trial — ${detail?.name || ''}`}
        size="sm"
        footer={
          <>
            <Button onClick={() => setExtendModalOpen(false)}>Cancel</Button>
            <Button
              variant="primary"
              loading={extending}
              onClick={handleExtendTrial}
            >
              Extend trial
            </Button>
          </>
        }
      >
        <form onSubmit={handleExtendTrial} className="space-y-3">
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Number of trial days to add
            </label>
            <select
              value={extendDays}
              onChange={(e) => setExtendDays(Number(e.target.value))}
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] bg-white"
            >
              <option value={7}>7 days</option>
              <option value={14}>14 days</option>
              <option value={30}>30 days</option>
              <option value={60}>60 days</option>
            </select>
          </div>
        </form>
      </Modal>

      {/* Direct Activate Modal */}
      <Modal
        open={activateModalOpen}
        onClose={() => setActivateModalOpen(false)}
        title={`Activate subscription — ${detail?.name || ''}`}
        size="sm"
        footer={
          <>
            <Button onClick={() => setActivateModalOpen(false)}>Cancel</Button>
            <Button
              variant="primary"
              loading={activating}
              onClick={handleDirectActivate}
            >
              Activate subscription
            </Button>
          </>
        }
      >
        <form onSubmit={handleDirectActivate} className="space-y-3">
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Subscription plan
            </label>
            <select
              value={activatePlan}
              onChange={(e) => setActivatePlan(e.target.value)}
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] bg-white"
            >
              <option value="Starter">Starter</option>
              <option value="Pro">Pro</option>
              <option value="Scale">Scale</option>
            </select>
          </div>
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Paid duration (months)
            </label>
            <select
              value={activateMonths}
              onChange={(e) => setActivateMonths(Number(e.target.value))}
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] bg-white"
            >
              <option value={1}>1 month (30 days)</option>
              <option value={3}>3 months (90 days)</option>
              <option value={6}>6 months (180 days)</option>
              <option value={12}>12 months (365 days)</option>
            </select>
          </div>
        </form>
      </Modal>

      {/* Support Session Token Modal */}
      <Modal
        open={Boolean(supportTokenModal)}
        onClose={() => setSupportTokenModal(null)}
        title={`POS support session — ${supportTokenModal?.tenantName || ''}`}
        size="md"
        footer={
          <Button onClick={() => setSupportTokenModal(null)}>Close</Button>
        }
      >
        {supportTokenModal && (
          <div className="space-y-3.5">
            <p className="text-[13px] text-[#5F6B7A]">
              An audited, time-limited support token has been issued for{' '}
              <span className="font-semibold text-[#16191F]">
                {supportTokenModal.tenantName}
              </span>
              . Use this token or launch link to troubleshoot their POS environment.
            </p>
            <div>
              <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
                Ephemeral support token
              </label>
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  readOnly
                  value={supportTokenModal.token}
                  className="flex-1 px-3 py-1.5 text-[12px] font-mono bg-[#FAFAFA] border border-[#879596] rounded-[4px]"
                />
                <Button
                  size="sm"
                  icon={copiedToken ? Check : Copy}
                  onClick={() => {
                    navigator.clipboard.writeText(supportTokenModal.token);
                    setCopiedToken(true);
                    setTimeout(() => setCopiedToken(false), 2000);
                  }}
                >
                  {copiedToken ? 'Copied' : 'Copy'}
                </Button>
              </div>
            </div>
            <div className="pt-2">
              <a
                href={`${supportTokenModal.clientAppUrl}?impersonate_token=${encodeURIComponent(
                  supportTokenModal.token
                )}`}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-[4px] bg-[#0972D3] hover:bg-[#033160] text-white text-[13px] font-semibold"
              >
                <ExternalLink className="w-3.5 h-3.5" />
                <span>Launch tenant POS in new tab</span>
              </a>
            </div>
          </div>
        )}
      </Modal>

      {/* Suspend / Reactivate Tenant Modal */}
      <Modal
        open={suspendModalOpen}
        onClose={() => setSuspendModalOpen(false)}
        title={detail?.isActive === false ? 'Reactivate tenant' : 'Suspend tenant'}
        footer={
          <>
            <Button onClick={() => setSuspendModalOpen(false)}>Cancel</Button>
            <Button
              variant={detail?.isActive === false ? 'primary' : 'danger'}
              loading={updatingTenantStatus}
              onClick={handleToggleTenantStatus}
            >
              {detail?.isActive === false ? 'Confirm reactivate' : 'Confirm suspend'}
            </Button>
          </>
        }
      >
        <form onSubmit={handleToggleTenantStatus} className="space-y-3">
          <p className="text-[13px] text-[#5F6B7A]">
            {detail?.isActive === false
              ? `Reactivating ${detail?.name} will restore POS and API access immediately.`
              : `Suspending ${detail?.name} will block all active users from logging in or syncing POS sales.`}
          </p>
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Reason (recorded in platform audit log)
            </label>
            <input
              type="text"
              value={suspendReason}
              onChange={(e) => setSuspendReason(e.target.value)}
              placeholder="e.g. Non-payment / Account review"
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px]"
            />
          </div>
        </form>
      </Modal>

      {/* Reset Tenant User Password Modal */}
      <Modal
        open={Boolean(resetPwdUser)}
        onClose={() => setResetPwdUser(null)}
        title={`Reset password · ${resetPwdUser?.fullName || resetPwdUser?.email || 'User'}`}
        footer={
          <>
            <Button onClick={() => setResetPwdUser(null)}>Cancel</Button>
            <Button
              variant="primary"
              loading={resettingPwd}
              disabled={!newUserPassword || newUserPassword.trim().length < 8}
              onClick={handleResetUserPassword}
            >
              Reset password & revoke sessions
            </Button>
          </>
        }
      >
        <form onSubmit={handleResetUserPassword} className="space-y-3">
          <p className="text-[13px] text-[#5F6B7A]">
            Set a temporary password for{' '}
            <span className="font-semibold text-[#16191F]">{resetPwdUser?.email}</span>.
            All existing POS sessions will be signed out immediately.
          </p>
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              New password (minimum 8 characters)
            </label>
            <input
              type="text"
              value={newUserPassword}
              onChange={(e) => setNewUserPassword(e.target.value)}
              placeholder="Enter temporary password..."
              className="w-full px-3 py-1.5 text-[13px] font-mono border border-[#879596] rounded-[4px]"
              autoFocus
            />
          </div>
        </form>
      </Modal>
    </div>
  );
}
