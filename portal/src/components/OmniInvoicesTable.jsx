import React, { useState, useEffect } from 'react';
import {
  Search,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';
import {
  listTenantInvoices,
  updateTenantInvoiceStatus,
} from '../services/api';
import {
  Container,
  Button,
  StatusIndicator,
  Alert,
} from '../ui/primitives';

export default function OmniInvoicesTable({ tenantId, onNotification }) {
  const [invoices, setInvoices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  const fetchInvoices = async () => {
    if (!tenantId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await listTenantInvoices(tenantId, {
        search,
        status: statusFilter,
        page,
        pageSize: 25,
      });
      if (res && res.items) {
        setInvoices(res.items);
        setTotalCount(res.totalCount || res.items.length);
      } else if (Array.isArray(res)) {
        setInvoices(res);
        setTotalCount(res.length);
      } else {
        setInvoices([]);
        setTotalCount(0);
      }
    } catch (err) {
      setError(err.message || 'Failed to load invoices from server.');
      setInvoices([]);
      setTotalCount(0);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchInvoices();
  }, [tenantId, page, statusFilter]);

  const handleStatusChange = async (invoice, newStatus) => {
    try {
      await updateTenantInvoiceStatus(tenantId, invoice.id, newStatus);
      setInvoices(
        invoices.map((i) =>
          i.id === invoice.id ? { ...i, status: newStatus } : i
        )
      );
      onNotification?.(
        `Updated invoice ${invoice.invoiceNumber || invoice.number || invoice.id} status to "${newStatus}".`
      );
    } catch (err) {
      onNotification?.(
        `Failed to update invoice status: ${err.message || 'Please try again'}`
      );
    }
  };

  const renderStatus = (status) => {
    const s = (status || '').toLowerCase();
    if (s === 'paid') return <StatusIndicator type="success">Paid</StatusIndicator>;
    if (s === 'partiallypaid')
      return <StatusIndicator type="info">Partially paid</StatusIndicator>;
    if (s === 'draft')
      return <StatusIndicator type="pending">Draft</StatusIndicator>;
    if (s === 'cancelled' || s === 'voided')
      return <StatusIndicator type="error">Cancelled</StatusIndicator>;
    if (s === 'overdue')
      return <StatusIndicator type="error">Overdue</StatusIndicator>;
    return <StatusIndicator type="warning">{status || 'Issued'}</StatusIndicator>;
  };

  return (
    <div className="space-y-4">
      {error && (
        <Alert
          type="error"
          title="Could not load customer invoices"
          action={
            <Button size="sm" onClick={fetchInvoices}>
              Retry
            </Button>
          }
        >
          {error}
        </Alert>
      )}

      <Container
        title="Customer invoices"
        count={totalCount}
        description="Manage B2B and customer billing documents, due dates, balances, and status transitions."
        noPadding
        actions={
          <Button
            size="sm"
            icon={RefreshCw}
            loading={loading}
            onClick={fetchInvoices}
          >
            Refresh
          </Button>
        }
        footer={
          <div className="flex items-center justify-between text-[12px] text-[#5F6B7A]">
            <span>
              Showing {invoices.length} of {totalCount} invoices
            </span>
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
                disabled={invoices.length < 25 || loading}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </Button>
            </div>
          </div>
        }
      >
        <div className="px-4 py-2.5 border-b border-[#E9EBED] bg-white flex flex-wrap items-center justify-between gap-2">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              setPage(1);
              fetchInvoices();
            }}
            className="relative flex-1 min-w-[220px] max-w-md"
          >
            <Search className="w-3.5 h-3.5 text-[#5F6B7A] absolute left-2.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Filter by invoice number or customer name..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-8 pr-3 py-1 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
            />
          </form>

          <div className="flex items-center gap-2">
            <span className="text-[12px] text-[#5F6B7A]">Status:</span>
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setPage(1);
              }}
              className="px-2.5 py-1 text-[12px] border border-[#879596] rounded-[4px] bg-white text-[#16191F]"
            >
              <option value="">All statuses</option>
              <option value="Draft">Draft</option>
              <option value="Issued">Issued</option>
              <option value="PartiallyPaid">Partially paid</option>
              <option value="Paid">Paid</option>
              <option value="Cancelled">Cancelled</option>
            </select>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                <th className="py-2.5 px-4">Invoice #</th>
                <th className="py-2.5 px-4">Customer</th>
                <th className="py-2.5 px-4">Issue date</th>
                <th className="py-2.5 px-4">Due date</th>
                <th className="py-2.5 px-4 text-right">Total amount</th>
                <th className="py-2.5 px-4 text-right">Amount paid</th>
                <th className="py-2.5 px-4">Status</th>
                <th className="py-2.5 px-4 text-right">Change status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E9EBED] text-[13px]">
              {loading ? (
                <tr>
                  <td colSpan={8} className="py-10 text-center text-[#5F6B7A]">
                    <RefreshCw className="w-4 h-4 animate-spin inline mr-2 text-[#0972D3]" />
                    Loading invoices...
                  </td>
                </tr>
              ) : invoices.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-10 text-center text-[#5F6B7A]">
                    No customer invoices found for this tenant.
                  </td>
                </tr>
              ) : (
                invoices.map((inv) => {
                  const total = inv.totalAmount ?? inv.grandTotal ?? 0;
                  const paid = inv.amountPaid ?? 0;
                  return (
                    <tr
                      key={inv.id}
                      className="hover:bg-[#F1F8FF]/50 transition-colors"
                    >
                      <td className="py-2 px-4 font-mono text-[12px] font-semibold text-[#16191F]">
                        {inv.invoiceNumber ||
                          inv.number ||
                          (inv.id ? inv.id.slice(0, 8) : '—')}
                      </td>
                      <td className="py-2 px-4 font-medium text-[#16191F]">
                        {inv.customerName || 'Customer'}
                      </td>
                      <td className="py-2 px-4 text-[#5F6B7A]">
                        {inv.issueDate || inv.createdAt
                          ? new Date(
                              inv.issueDate || inv.createdAt
                            ).toLocaleDateString()
                          : '—'}
                      </td>
                      <td className="py-2 px-4 text-[#5F6B7A]">
                        {inv.dueDate
                          ? new Date(inv.dueDate).toLocaleDateString()
                          : '—'}
                      </td>
                      <td className="py-2 px-4 text-right tabular-nums font-semibold text-[#16191F]">
                        {Number(total).toLocaleString()} {inv.currency || 'TZS'}
                      </td>
                      <td className="py-2 px-4 text-right tabular-nums text-[#037F0C]">
                        {Number(paid).toLocaleString()} {inv.currency || 'TZS'}
                      </td>
                      <td className="py-2 px-4">{renderStatus(inv.status)}</td>
                      <td className="py-2 px-4 text-right">
                        <select
                          value={inv.status || 'Issued'}
                          onChange={(e) =>
                            handleStatusChange(inv, e.target.value)
                          }
                          className="px-2 py-1 text-[12px] border border-[#879596] rounded-[4px] bg-white text-[#16191F]"
                        >
                          <option value="Draft">Draft</option>
                          <option value="Issued">Issued</option>
                          <option value="PartiallyPaid">PartiallyPaid</option>
                          <option value="Paid">Paid</option>
                          <option value="Cancelled">Cancelled</option>
                        </select>
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
