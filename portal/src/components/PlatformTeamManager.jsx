import React, { useState, useEffect } from 'react';
import { RefreshCw, UserPlus } from 'lucide-react';
import {
  listPlatformTeam,
  assignPlatformRole,
  revokePlatformRole,
} from '../services/api';
import {
  Container,
  PageHeader,
  Button,
  StatusIndicator,
  Badge,
  Modal,
  Alert,
} from '../ui/primitives';

export default function PlatformTeamManager({
  currentOperator,
  onNotification,
}) {
  const [operators, setOperators] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Add operator modal
  const [showAddModal, setShowAddModal] = useState(false);
  const [newEmail, setNewEmail] = useState('');
  const [newRole, setNewRole] = useState('PlatformStaff');
  const [submitting, setSubmitting] = useState(false);

  // Revoke confirmation modal
  const [revokeTarget, setRevokeTarget] = useState(null);
  const [revoking, setRevoking] = useState(false);

  const fetchTeam = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await listPlatformTeam();
      if (Array.isArray(res)) {
        setOperators(res);
      } else if (res && res.items) {
        setOperators(res.items);
      } else {
        setOperators([]);
      }
    } catch (err) {
      setError(err.message || 'Failed to load platform team members.');
      setOperators([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTeam();
  }, []);

  const handleAddOperator = async (e) => {
    if (e) e.preventDefault();
    if (!newEmail.trim()) return;
    setSubmitting(true);
    try {
      await assignPlatformRole(newEmail.trim(), newRole);
      setShowAddModal(false);
      setNewEmail('');
      onNotification?.(`Assigned ${newRole} role to ${newEmail.trim()}.`);
      fetchTeam();
    } catch (err) {
      onNotification?.(
        `Failed to assign role: ${err.message || 'Please try again'}`
      );
    } finally {
      setSubmitting(false);
    }
  };

  const handleConfirmRevoke = async () => {
    if (!revokeTarget) return;
    setRevoking(true);
    try {
      await revokePlatformRole(revokeTarget.id || revokeTarget.userId);
      setRevokeTarget(null);
      onNotification?.(
        `Revoked platform privileges for ${revokeTarget.email}.`
      );
      fetchTeam();
    } catch (err) {
      onNotification?.(
        `Failed to revoke privileges: ${err.message || 'Please try again'}`
      );
    } finally {
      setRevoking(false);
    }
  };

  return (
    <div className="space-y-4">
      <PageHeader
        title="Platform team & IAM roles"
        count={operators.length}
        subtitle="Manage platform-level operators who can inspect and assist tenants. Platform roles exist strictly outside customer workspaces."
        actions={
          <>
            <Button
              size="md"
              icon={RefreshCw}
              loading={loading}
              onClick={fetchTeam}
            >
              Refresh
            </Button>
            <Button
              size="md"
              variant="primary"
              icon={UserPlus}
              onClick={() => setShowAddModal(true)}
            >
              Grant platform role
            </Button>
          </>
        }
      />

      {error && (
        <Alert
          type="error"
          title="Could not load platform operators"
          action={
            <Button size="sm" onClick={fetchTeam}>
              Retry
            </Button>
          }
        >
          {error}
        </Alert>
      )}

      {/* Role Policy Reference */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <Container
          title="PlatformSuperAdmin"
          description="Unrestricted platform root authority"
        >
          <ul className="text-[12px] text-[#5F6B7A] space-y-1 list-disc list-inside">
            <li>Full access across all tenant workspaces, sales, catalog, and billing</li>
            <li>Manage platform subscription plans, pricing, and payment accounts</li>
            <li>Assign or revoke PlatformStaff and PlatformSuperAdmin roles</li>
          </ul>
        </Container>
        <Container
          title="PlatformStaff"
          description="Delegated tenant support & onboarding specialist"
        >
          <ul className="text-[12px] text-[#5F6B7A] space-y-1 list-disc list-inside">
            <li>Inspect tenant products, sales, invoices, and cash drawer sessions</li>
            <li>Assist tenants with product price fixes, stock adjustments, and trial extensions</li>
            <li>Cannot modify global billing plans, payment accounts, or platform IAM team</li>
          </ul>
        </Container>
      </div>

      <Container
        title="Active platform operators"
        count={operators.length}
        noPadding
      >
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                <th className="py-2.5 px-4">Operator name</th>
                <th className="py-2.5 px-4">Email address</th>
                <th className="py-2.5 px-4">Platform role</th>
                <th className="py-2.5 px-4">Status</th>
                <th className="py-2.5 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E9EBED] text-[13px]">
              {loading ? (
                <tr>
                  <td colSpan={5} className="py-10 text-center text-[#5F6B7A]">
                    <RefreshCw className="w-4 h-4 animate-spin inline mr-2 text-[#0972D3]" />
                    Loading platform operators...
                  </td>
                </tr>
              ) : operators.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-10 text-center text-[#5F6B7A]">
                    No platform operators returned from server.
                  </td>
                </tr>
              ) : (
                operators.map((op) => {
                  const id = op.id || op.userId || op.email;
                  const isSuper = op.platformRole === 'PlatformSuperAdmin';
                  const isSelf =
                    currentOperator &&
                    (currentOperator.email === op.email ||
                      currentOperator.id === id);

                  return (
                    <tr
                      key={id}
                      className="hover:bg-[#F1F8FF]/50 transition-colors"
                    >
                      <td className="py-2.5 px-4 font-semibold text-[#16191F]">
                        {op.fullName || op.name || op.email?.split('@')[0] || 'Operator'}
                        {isSelf && (
                          <span className="ml-2 text-[11px] font-normal text-[#5F6B7A]">
                            (You)
                          </span>
                        )}
                      </td>
                      <td className="py-2.5 px-4 font-mono text-[12px] text-[#5F6B7A]">
                        {op.email}
                      </td>
                      <td className="py-2.5 px-4">
                        <Badge color={isSuper ? 'amber' : 'blue'}>
                          {op.platformRole || 'PlatformStaff'}
                        </Badge>
                      </td>
                      <td className="py-2.5 px-4">
                        <StatusIndicator type="success">Active</StatusIndicator>
                      </td>
                      <td className="py-2.5 px-4 text-right">
                        {!isSelf ? (
                          <Button
                            variant="link"
                            size="sm"
                            className="text-[#D91515]"
                            onClick={() => setRevokeTarget(op)}
                          >
                            Revoke role
                          </Button>
                        ) : (
                          <span className="text-[12px] text-[#5F6B7A]">Protected</span>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </Container>

      {/* Grant Role Modal */}
      <Modal
        open={showAddModal}
        onClose={() => setShowAddModal(false)}
        title="Grant platform role"
        size="sm"
        footer={
          <>
            <Button onClick={() => setShowAddModal(false)}>Cancel</Button>
            <Button
              variant="primary"
              loading={submitting}
              onClick={handleAddOperator}
            >
              Grant access
            </Button>
          </>
        }
      >
        <form onSubmit={handleAddOperator} className="space-y-3.5">
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              User email address
            </label>
            <input
              type="email"
              required
              placeholder="operator@jolinx.co.tz"
              value={newEmail}
              onChange={(e) => setNewEmail(e.target.value)}
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
            />
            <p className="text-[11px] text-[#5F6B7A] mt-1">
              The user must already have a registered account in the platform.
            </p>
          </div>
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Platform role
            </label>
            <select
              value={newRole}
              onChange={(e) => setNewRole(e.target.value)}
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] bg-white text-[#16191F]"
            >
              <option value="PlatformStaff">
                PlatformStaff (Support & Onboarding)
              </option>
              <option value="PlatformSuperAdmin">
                PlatformSuperAdmin (Full Platform Root)
              </option>
            </select>
          </div>
        </form>
      </Modal>

      {/* Revoke Role Modal */}
      <Modal
        open={Boolean(revokeTarget)}
        onClose={() => setRevokeTarget(null)}
        title="Revoke platform role"
        size="sm"
        footer={
          <>
            <Button onClick={() => setRevokeTarget(null)}>Cancel</Button>
            <Button
              variant="dangerPrimary"
              loading={revoking}
              onClick={handleConfirmRevoke}
            >
              Revoke access
            </Button>
          </>
        }
      >
        <p className="text-[13px] text-[#16191F]">
          Are you sure you want to revoke platform operator privileges for{' '}
          <span className="font-semibold">{revokeTarget?.email}</span>? They will immediately lose access to this console.
        </p>
      </Modal>
    </div>
  );
}
