import React, { useState, useEffect } from 'react';
import { RefreshCw, ChevronLeft, ChevronRight } from 'lucide-react';
import { listTenantCashSessions } from '../services/api';
import {
  Container,
  Button,
  StatusIndicator,
  Alert,
} from '../ui/primitives';

export default function OmniCashSessionsTable({ tenantId }) {
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [page, setPage] = useState(1);

  const fetchSessions = async () => {
    if (!tenantId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await listTenantCashSessions(tenantId, {
        page,
        pageSize: 20,
      });
      if (res && res.items) {
        setSessions(res.items);
      } else if (Array.isArray(res)) {
        setSessions(res);
      } else {
        setSessions([]);
      }
    } catch (err) {
      setError(err.message || 'Failed to load cash drawer sessions.');
      setSessions([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSessions();
  }, [tenantId, page]);

  return (
    <div className="space-y-4">
      {error && (
        <Alert
          type="error"
          title="Could not load cash sessions"
          action={
            <Button size="sm" onClick={fetchSessions}>
              Retry
            </Button>
          }
        >
          {error}
        </Alert>
      )}

      <Container
        title="POS cash drawer sessions"
        count={sessions.length}
        description="Reconciliation of cashier shifts, opening float, cash sales, declared closing balances, and variances."
        noPadding
        actions={
          <Button
            size="sm"
            icon={RefreshCw}
            loading={loading}
            onClick={fetchSessions}
          >
            Refresh
          </Button>
        }
        footer={
          <div className="flex items-center justify-between text-[12px] text-[#5F6B7A]">
            <span>Showing {sessions.length} sessions</span>
            <div className="flex items-center gap-1.5">
              <Button
                size="sm"
                icon={ChevronLeft}
                disabled={page <= 1 || loading}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
              >
                Prev
              </Button>
              <span className="px-2 font-medium text-[#16191F]">
                Page {page}
              </span>
              <Button
                size="sm"
                icon={ChevronRight}
                disabled={sessions.length < 20 || loading}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </Button>
            </div>
          </div>
        }
      >
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                <th className="py-2.5 px-4">Register</th>
                <th className="py-2.5 px-4">Cashier</th>
                <th className="py-2.5 px-4">Opened at</th>
                <th className="py-2.5 px-4">Closed at</th>
                <th className="py-2.5 px-4 text-right">Opening float</th>
                <th className="py-2.5 px-4 text-right">Cash sales</th>
                <th className="py-2.5 px-4 text-right">Declared closing</th>
                <th className="py-2.5 px-4 text-right">Variance</th>
                <th className="py-2.5 px-4">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E9EBED] text-[13px]">
              {loading ? (
                <tr>
                  <td colSpan={9} className="py-10 text-center text-[#5F6B7A]">
                    <RefreshCw className="w-4 h-4 animate-spin inline mr-2 text-[#0972D3]" />
                    Loading cash drawer sessions...
                  </td>
                </tr>
              ) : sessions.length === 0 ? (
                <tr>
                  <td colSpan={9} className="py-10 text-center text-[#5F6B7A]">
                    No POS cash drawer sessions recorded for this tenant.
                  </td>
                </tr>
              ) : (
                sessions.map((s) => {
                  const isOpen =
                    (s.status || '').toLowerCase() === 'open' || !s.closedAt;
                  const variance = Number(s.variance ?? 0);

                  return (
                    <tr
                      key={s.id}
                      className="hover:bg-[#F1F8FF]/50 transition-colors"
                    >
                      <td className="py-2 px-4 font-medium text-[#16191F]">
                        {s.registerName || s.accountName || 'Main Register'}
                      </td>
                      <td className="py-2 px-4 text-[#5F6B7A]">
                        {s.cashierName || s.openedBy || 'Cashier'}
                      </td>
                      <td className="py-2 px-4 text-[#5F6B7A] whitespace-nowrap">
                        {s.openedAt
                          ? new Date(s.openedAt).toLocaleString()
                          : '—'}
                      </td>
                      <td className="py-2 px-4 text-[#5F6B7A] whitespace-nowrap">
                        {s.closedAt
                          ? new Date(s.closedAt).toLocaleString()
                          : '—'}
                      </td>
                      <td className="py-2 px-4 text-right tabular-nums text-[#5F6B7A]">
                        {Number(s.openingBalance ?? 0).toLocaleString()}
                      </td>
                      <td className="py-2 px-4 text-right tabular-nums font-medium text-[#16191F]">
                        {Number(s.cashSales ?? 0).toLocaleString()}
                      </td>
                      <td className="py-2 px-4 text-right tabular-nums font-semibold text-[#16191F]">
                        {s.closingBalance !== undefined &&
                        s.closingBalance !== null
                          ? Number(s.closingBalance).toLocaleString()
                          : '—'}
                      </td>
                      <td className="py-2 px-4 text-right tabular-nums font-semibold">
                        <span
                          className={
                            variance < 0
                              ? 'text-[#D91515]'
                              : variance > 0
                              ? 'text-[#8D6605]'
                              : 'text-[#037F0C]'
                          }
                        >
                          {variance > 0 ? `+${variance.toLocaleString()}` : variance.toLocaleString()}
                        </span>
                      </td>
                      <td className="py-2 px-4">
                        {isOpen ? (
                          <StatusIndicator type="info">Open</StatusIndicator>
                        ) : (
                          <StatusIndicator type="success">
                            Closed
                          </StatusIndicator>
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
    </div>
  );
}
