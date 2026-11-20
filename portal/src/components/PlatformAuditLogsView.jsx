import React, { useState, useEffect } from 'react';
import { Search, RefreshCw, ChevronLeft, ChevronRight, ShieldCheck } from 'lucide-react';
import { listPlatformAuditLogs } from '../services/api';
import { Container, PageHeader, Button, Badge, Alert } from '../ui/primitives';

export default function PlatformAuditLogsView() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const pageSize = 50;

  const fetchLogs = async (targetPage = page) => {
    setLoading(true);
    setError(null);
    try {
      const res = await listPlatformAuditLogs({ search: search.trim(), page: targetPage, pageSize });
      setLogs(res?.items || []);
      setTotalCount(res?.totalCount ?? 0);
    } catch (err) {
      setError(err.message || 'Could not load audit logs.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs(1);
  }, []);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    setPage(1);
    fetchLogs(1);
  };

  const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));

  return (
    <div className="space-y-4">
      <PageHeader
        title="Platform audit logs"
        subtitle="Immutable record of operator actions, tenant suspensions, password resets, bulk imports, and system events (Cloudflare / AWS CloudTrail style)."
        actions={
          <Button size="md" icon={RefreshCw} loading={loading} onClick={() => fetchLogs(page)}>
            Refresh
          </Button>
        }
      />

      {error && (
        <Alert
          type="error"
          title="Failed to load audit logs"
          action={<Button size="sm" onClick={() => fetchLogs(page)}>Retry</Button>}
        >
          {error}
        </Alert>
      )}

      <Container
        title="Audit trail"
        count={totalCount}
        noPadding
        actions={
          <form onSubmit={handleSearchSubmit} className="flex items-center gap-2">
            <div className="relative">
              <Search className="w-3.5 h-3.5 text-[#5F6B7A] absolute left-2.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Filter action, entity, details..."
                className="pl-8 pr-3 py-1.5 text-[12px] border border-[#879596] rounded-[4px] bg-white w-56 focus:outline-none focus:border-[#0972D3]"
              />
            </div>
            <Button size="sm" variant="primary" type="submit">
              Search
            </Button>
          </form>
        }
        footer={
          <div className="flex items-center justify-between text-[12px] text-[#5F6B7A]">
            <span>
              Page {page} of {totalPages} · {totalCount} total events
            </span>
            <div className="flex items-center gap-1.5">
              <Button
                size="sm"
                icon={ChevronLeft}
                disabled={page <= 1 || loading}
                onClick={() => {
                  const next = Math.max(1, page - 1);
                  setPage(next);
                  fetchLogs(next);
                }}
              >
                Prev
              </Button>
              <Button
                size="sm"
                icon={ChevronRight}
                disabled={page >= totalPages || loading}
                onClick={() => {
                  const next = Math.min(totalPages, page + 1);
                  setPage(next);
                  fetchLogs(next);
                }}
              >
                Next
              </Button>
            </div>
          </div>
        }
      >
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-[13px]">
            <thead>
              <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase text-[#5F6B7A]">
                <th className="py-2.5 px-4">Timestamp</th>
                <th className="py-2.5 px-4">Action</th>
                <th className="py-2.5 px-4">Tenant</th>
                <th className="py-2.5 px-4">Operator / User</th>
                <th className="py-2.5 px-4">Entity</th>
                <th className="py-2.5 px-4">Details</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E9EBED]">
              {logs.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-10 text-center text-[#5F6B7A]">
                    {loading ? 'Loading audit logs...' : 'No audit log events match your filter.'}
                  </td>
                </tr>
              ) : (
                logs.map((log) => (
                  <tr key={log.id} className="hover:bg-[#F9FAFB]">
                    <td className="py-2.5 px-4 font-mono text-[12px] text-[#5F6B7A] whitespace-nowrap">
                      {log.createdAtUtc ? new Date(log.createdAtUtc).toLocaleString() : '—'}
                    </td>
                    <td className="py-2.5 px-4">
                      <Badge color={log.action?.startsWith('PlatformOperator') ? 'blue' : 'gray'}>
                        <span className="inline-flex items-center gap-1">
                          <ShieldCheck className="w-3 h-3" />
                          {log.action}
                        </span>
                      </Badge>
                    </td>
                    <td className="py-2.5 px-4 font-medium text-[#16191F]">
                      {log.tenantName || log.tenantId?.slice(0, 8) || '—'}
                    </td>
                    <td className="py-2.5 px-4 font-mono text-[12px] text-[#5F6B7A]">
                      {log.operatorEmail || 'System'}
                    </td>
                    <td className="py-2.5 px-4 text-[12px] text-[#5F6B7A]">
                      <span className="font-semibold text-[#16191F]">{log.entityType}</span>
                      {log.entityId && (
                        <span className="ml-1 font-mono text-[11px]">
                          #{String(log.entityId).slice(0, 8)}
                        </span>
                      )}
                    </td>
                    <td className="py-2.5 px-4 text-[12px] text-[#16191F] max-w-md truncate" title={log.details || ''}>
                      {log.details || '—'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Container>
    </div>
  );
}
