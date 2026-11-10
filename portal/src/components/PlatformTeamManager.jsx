import React, { useState, useEffect } from 'react';
import {
  ShieldCheck,
  UserPlus,
  Trash2,
  RefreshCw,
  Crown,
  UserCheck,
  AlertCircle,
  X,
  Mail,
  ShieldAlert
} from 'lucide-react';
import {
  listPlatformTeam,
  assignPlatformRole,
  revokePlatformRole
} from '../services/api';

export default function PlatformTeamManager({ currentOperator, onNotification }) {
  const [operators, setOperators] = useState([]);
  const [loading, setLoading] = useState(true);

  // Invite Modal
  const [showAddModal, setShowAddModal] = useState(false);
  const [newEmail, setNewEmail] = useState('');
  const [newRole, setNewRole] = useState('PlatformStaff');
  const [submitting, setSubmitting] = useState(false);

  // Revoke Target
  const [revokeTarget, setRevokeTarget] = useState(null);

  const fetchTeam = async () => {
    setLoading(true);
    try {
      const res = await listPlatformTeam();
      if (Array.isArray(res)) {
        setOperators(res);
      } else if (res && res.items) {
        setOperators(res.items);
      }
    } catch (err) {
      console.warn('Could not fetch platform team, fallback mock if empty', err);
      if (operators.length === 0) {
        setOperators([
          {
            id: 'op1',
            email: 'joberthix@gmail.com',
            role: 'PlatformSuperAdmin',
            isActive: true,
            createdAt: '2026-10-14'
          },
          {
            id: 'op2',
            email: 'admin@acme.local',
            role: 'PlatformSuperAdmin',
            isActive: true,
            createdAt: '2026-10-15'
          },
          {
            id: 'op3',
            email: 'support1@jolinx.co.tz',
            role: 'PlatformStaff',
            isActive: true,
            createdAt: '2026-11-01'
          }
        ]);
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTeam();
  }, []);

  const handleAddOperator = async (e) => {
    e.preventDefault();
    if (!newEmail.trim()) return;
    setSubmitting(true);
    try {
      await assignPlatformRole(newEmail.trim(), newRole);
      onNotification?.(`Wajibu wa "${newRole}" umewekwa kwa ${newEmail}!`);
      setShowAddModal(false);
      setNewEmail('');
      fetchTeam();
    } catch (err) {
      onNotification?.(`Hitilafu: ${err.message || 'Jaribu tena'}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleConfirmRevoke = async () => {
    if (!revokeTarget) return;
    try {
      await revokePlatformRole(revokeTarget.id);
      setOperators(operators.filter(o => o.id !== revokeTarget.id));
      onNotification?.(`Ufikiaji wa jukwaa kwa ${revokeTarget.email} umesitishwa!`);
      setRevokeTarget(null);
    } catch (err) {
      onNotification?.(`Hitilafu kusitisha ufikiaji: ${err.message || 'Jaribu tena'}`);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 text-white p-6 rounded-2xl shadow-xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border border-indigo-500/20">
        <div>
          <div className="flex items-center gap-2">
            <Crown className="w-6 h-6 text-amber-400" />
            <h1 className="text-xl sm:text-2xl font-bold tracking-tight">
              Usimamizi wa Timu ya Jukwaa (Platform Staff & SuperAdmins)
            </h1>
          </div>
          <p className="text-sm text-slate-300 mt-1 max-w-2xl">
            Wape wafanyakazi wa msaada (Support Staff) uwezo wa kuingia kwenye maduka ya wateja kusaidia kutatua matatizo, huku udhibiti mkuu wa kifedha na mfumo ukibaki kwako tu kama <strong>PlatformSuperAdmin</strong>.
          </p>
        </div>

        <button
          onClick={() => setShowAddModal(true)}
          className="inline-flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2.5 rounded-xl font-semibold shadow-lg shadow-indigo-600/30 transition self-start sm:self-auto"
        >
          <UserPlus className="w-5 h-5" />
          <span>Ongeza Mfanyakazi</span>
        </button>
      </div>

      {/* Operators List Table */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="p-4 border-b border-slate-100 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-5 h-5 text-indigo-600" />
            <h3 className="font-bold text-slate-900 text-sm">Orodha ya Wanaodhibiti Jukwaa ({operators.length})</h3>
          </div>
          <button
            onClick={fetchTeam}
            disabled={loading}
            className="p-2 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-600 transition"
            title="Sasisha Orodha"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm text-slate-600">
            <thead className="bg-slate-50 text-xs uppercase font-semibold text-slate-500 border-b border-slate-200">
              <tr>
                <th className="py-3 px-4">Barua Pepe (Email)</th>
                <th className="py-3 px-4">Wajibu Kwenye Mfumo (Platform Role)</th>
                <th className="py-3 px-4">Uwezo na Mipaka ya Ufikiaji</th>
                <th className="py-3 px-4 text-center">Hali</th>
                <th className="py-3 px-4 text-right">Vitendo</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading && operators.length === 0 ? (
                <tr>
                  <td colSpan="5" className="py-12 text-center text-slate-400">
                    <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-indigo-600" />
                    Inapakia orodha ya timu...
                  </td>
                </tr>
              ) : (
                operators.map((op) => {
                  const isSuper = op.role === 'PlatformSuperAdmin';
                  const isSelf = currentOperator && currentOperator.email && currentOperator.email.toLowerCase() === op.email.toLowerCase();

                  return (
                    <tr key={op.id} className="hover:bg-slate-50 transition">
                      <td className="py-3.5 px-4">
                        <div className="font-bold text-slate-900 flex items-center gap-1.5">
                          <Mail className="w-4 h-4 text-slate-400" />
                          {op.email}
                          {isSelf && (
                            <span className="text-xs px-2 py-0.5 rounded-full bg-indigo-100 text-indigo-700 font-medium">
                              Wewe (You)
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="py-3.5 px-4">
                        {isSuper ? (
                          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-amber-100 text-amber-900 border border-amber-300">
                            <Crown className="w-3.5 h-3.5 text-amber-600" />
                            SUPER SUPER ADMIN
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-900 border border-blue-200">
                            <UserCheck className="w-3.5 h-3.5 text-blue-600" />
                            SUPPORT STAFF
                          </span>
                        )}
                      </td>
                      <td className="py-3.5 px-4 text-xs text-slate-500">
                        {isSuper ? (
                          <span>Ufikiaji kamili wa kila duka, usimamizi wa timu, vifurushi, malipo na mfumo.</span>
                        ) : (
                          <span>Kusaidia maduka ya wateja (bidhaa, stoo, mauzo, invoices pekee). Hana uwezo wa timu au malipo.</span>
                        )}
                      </td>
                      <td className="py-3.5 px-4 text-center">
                        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold bg-emerald-100 text-emerald-800">
                          Hai (Active)
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        {!isSelf && (
                          <button
                            onClick={() => setRevokeTarget(op)}
                            className="px-2.5 py-1 text-rose-600 hover:bg-rose-50 rounded-lg text-xs font-medium transition"
                            title="Ondoa Ufikiaji"
                          >
                            Ondoa Ufikiaji
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Staff Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <UserPlus className="w-5 h-5 text-indigo-600" />
                <h3 className="font-bold text-lg text-slate-900">Ongeza Msimamizi Kwenye Jukwaa</h3>
              </div>
              <button onClick={() => setShowAddModal(false)} className="p-1 text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleAddOperator} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">
                  Barua Pepe ya Mfanyakazi (User Email)
                </label>
                <input
                  type="email"
                  required
                  placeholder="mfano: support@jolinx.co.tz"
                  value={newEmail}
                  onChange={(e) => setNewEmail(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">
                  Ngazi ya Ufikiaji (Platform Role)
                </label>
                <select
                  value={newRole}
                  onChange={(e) => setNewRole(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500"
                >
                  <option value="PlatformStaff">
                    Support Staff — Kuingia kwenye maduka ya wateja kusaidia bidhaa, mauzo na stoo tu
                  </option>
                  <option value="PlatformSuperAdmin">
                    Platform SuperAdmin — Udhibiti Mkuu (Wafanyakazi, Vifurushi, Akaunti za Benki)
                  </option>
                </select>
              </div>

              <div className="bg-amber-50 p-3 rounded-xl border border-amber-200 text-xs text-amber-800 space-y-1">
                <div className="font-semibold flex items-center gap-1">
                  <ShieldAlert className="w-4 h-4 text-amber-600" />
                  Ulinzi wa Jukwaa:
                </div>
                <div>
                  Wafanyakazi wa <strong>PlatformStaff</strong> wanaweza kuingia kwenye maduka ya wateja kusaidia mauzo, stoo, na invoices, lakini hawana uwezo wa kubadili akaunti za benki au kuongeza watumiaji wengine wa platform.
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-4 py-2 border border-slate-300 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-50"
                >
                  Ghairi
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-semibold shadow-md transition"
                >
                  {submitting ? 'Inaongeza...' : 'Ongeza Msimamizi'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Revoke Access Modal */}
      {revokeTarget && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-rose-100 space-y-4">
            <div className="flex items-center gap-2 text-rose-600">
              <AlertCircle className="w-6 h-6" />
              <h3 className="font-bold text-lg text-slate-900">Sitisha Ufikiaji wa Jukwaa</h3>
            </div>
            <p className="text-sm text-slate-600">
              Una uhakika unataka kuondoa ufikiaji wa <strong className="text-slate-900">{revokeTarget.email}</strong>? Hatakuwa na uwezo wa kuingia tena kwenye control plane au maduka ya wateja.
            </p>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                onClick={() => setRevokeTarget(null)}
                className="px-4 py-2 border border-slate-300 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-50"
              >
                Ghairi
              </button>
              <button
                onClick={handleConfirmRevoke}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white rounded-lg text-sm font-semibold shadow-md transition"
              >
                Ndiyo, Ondoa Ufikiaji
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
