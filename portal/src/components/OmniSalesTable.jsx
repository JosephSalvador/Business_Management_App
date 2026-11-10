import React, { useState, useEffect } from 'react';
import {
  Search,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';
import {
  listTenantSales,
  getTenantSaleDetail,
  voidTenantSale,
} from '../services/api';
import {
  Container,
  Button,
  StatusIndicator,
  Badge,
  Modal,
  Alert,
  KeyValueGrid,
} from '../ui/primitives';

export default function OmniSalesTable({ tenantId, onNotification }) {
  const [sales, setSales] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  // Sale Detail Modal
  const [selectedSaleDetail, setSelectedSaleDetail] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);

  // Void Sale Confirmation Modal
  const [voidTargetSale, setVoidTargetSale] = useState(null);
  const [voidReason, setVoidReason] = useState(
    'Platform Operator Sale Correction'
  );
  const [voiding, setVoiding] = useState(false);

  const fetchSales = async () => {
    if (!tenantId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await listTenantSales(tenantId, {
        search,
        startDate,
        endDate,
        page,
        pageSize: 20,
      });
      if (res && res.items) {
        setSales(res.items);
        setTotalCount(res.totalCount || res.items.length);
      } else if (Array.isArray(res)) {
        setSales(res);
        setTotalCount(res.length);
      } else {
        setSales([]);
        setTotalCount(0);
      }
    } catch (err) {
      setError(err.message || 'Failed to load sales from server.');
      setSales([]);
      setTotalCount(0);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSales();
  }, [tenantId, page]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    setPage(1);
    fetchSales();
  };

  const handleOpenReceipt = async (sale) => {
    setDetailLoading(true);
    try {
      const detail = await getTenantSaleDetail(tenantId, sale.id);
      setSelectedSaleDetail(detail || sale);
    } catch {
      setSelectedSaleDetail(sale);
    } finally {
      setDetailLoading(false);
    }
  };

  const handleConfirmVoid = async (e) => {
    if (e) e.preventDefault();
    if (!voidTargetSale) return;
    setVoiding(true);
    try {
      await voidTenantSale(tenantId, voidTargetSale.id, voidReason);
      setSales(
        sales.map((s) =>
          s.id === voidTargetSale.id ? { ...s, status: 'Voided' } : s
        )
      );
      setVoidTargetSale(null);
      onNotification?.(
        `Voided sale receipt ${voidTargetSale.receiptNumber || voidTargetSale.id}.`
      );
    } catch (err) {
      onNotification?.(
        `Failed to void sale: ${err.message || 'Please try again'}`
      );
    } finally {
      setVoiding(false);
    }
  };

  return (
    <div className="space-y-4">
      {error && (
        <Alert
          type="error"
          title="Could not load sales transactions"
          action={
            <Button size="sm" onClick={fetchSales}>
              Retry
            </Button>
          }
        >
          {error}
        </Alert>
      )}

      <Container
        title="Sales & POS transactions"
        count={totalCount}
        description="Complete ledger of point-of-sale checkouts, payment methods, cashier attributions, and void controls."
        noPadding
        actions={
          <Button
            size="sm"
            icon={RefreshCw}
            loading={loading}
            onClick={fetchSales}
          >
            Refresh
          </Button>
        }
        footer={
          <div className="flex items-center justify-between text-[12px] text-[#5F6B7A]">
            <span>
              Showing {sales.length} of {totalCount} records
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
                disabled={sales.length < 20 || loading}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </Button>
            </div>
          </div>
        }
      >
        {/* Filter Bar */}
        <form
          onSubmit={handleSearchSubmit}
          className="px-4 py-2.5 border-b border-[#E9EBED] bg-white flex flex-wrap items-center gap-2"
        >
          <div className="relative flex-1 min-w-[220px] max-w-md">
            <Search className="w-3.5 h-3.5 text-[#5F6B7A] absolute left-2.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              placeholder="Filter by receipt number, customer, or cashier..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-8 pr-3 py-1 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
            />
          </div>
          <div className="flex items-center gap-1.5 text-[12px] text-[#5F6B7A]">
            <span>From:</span>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="px-2 py-1 text-[12px] border border-[#879596] rounded-[4px] text-[#16191F]"
            />
            <span>To:</span>
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              className="px-2 py-1 text-[12px] border border-[#879596] rounded-[4px] text-[#16191F]"
            />
            <Button size="sm" type="submit">
              Apply filter
            </Button>
          </div>
        </form>

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[11px] font-bold uppercase tracking-wider text-[#5F6B7A]">
                <th className="py-2.5 px-4">Receipt #</th>
                <th className="py-2.5 px-4">Date & time</th>
                <th className="py-2.5 px-4">Customer</th>
                <th className="py-2.5 px-4">Cashier</th>
                <th className="py-2.5 px-4">Payment</th>
                <th className="py-2.5 px-4 text-right">Total amount</th>
                <th className="py-2.5 px-4">Status</th>
                <th className="py-2.5 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E9EBED] text-[13px]">
              {loading ? (
                <tr>
                  <td colSpan={8} className="py-10 text-center text-[#5F6B7A]">
                    <RefreshCw className="w-4 h-4 animate-spin inline mr-2 text-[#0972D3]" />
                    Loading sales records...
                  </td>
                </tr>
              ) : sales.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-10 text-center text-[#5F6B7A]">
                    No sales records found for this tenant.
                  </td>
                </tr>
              ) : (
                sales.map((sale) => {
                  const isVoided =
                    (sale.status || '').toLowerCase() === 'voided' ||
                    (sale.status || '').toLowerCase() === 'cancelled';
                  const total = sale.totalAmount ?? sale.grandTotal ?? 0;

                  return (
                    <tr
                      key={sale.id}
                      className="hover:bg-[#F1F8FF]/50 transition-colors"
                    >
                      <td className="py-2 px-4 font-mono text-[12px] font-semibold text-[#0972D3]">
                        <button
                          type="button"
                          onClick={() => handleOpenReceipt(sale)}
                          className="hover:underline"
                        >
                          {sale.receiptNumber ||
                            sale.number ||
                            (sale.id ? sale.id.slice(0, 8) : '—')}
                        </button>
                      </td>
                      <td className="py-2 px-4 text-[#5F6B7A] whitespace-nowrap">
                        {sale.createdAt
                          ? new Date(sale.createdAt).toLocaleString()
                          : '—'}
                      </td>
                      <td className="py-2 px-4 text-[#16191F]">
                        {sale.customerName || 'Walk-in Customer'}
                      </td>
                      <td className="py-2 px-4 text-[#5F6B7A]">
                        {sale.cashierName || sale.createdBy || 'POS Cashier'}
                      </td>
                      <td className="py-2 px-4">
                        <Badge color="blue">
                          {sale.paymentMethod || 'Cash'}
                        </Badge>
                      </td>
                      <td className="py-2 px-4 text-right tabular-nums font-semibold text-[#16191F]">
                        {Number(total).toLocaleString()}{' '}
                        {sale.currency || 'TZS'}
                      </td>
                      <td className="py-2 px-4">
                        {isVoided ? (
                          <StatusIndicator type="error">Voided</StatusIndicator>
                        ) : (
                          <StatusIndicator type="success">
                            Completed
                          </StatusIndicator>
                        )}
                      </td>
                      <td className="py-2 px-4 text-right whitespace-nowrap space-x-2">
                        <Button
                          variant="link"
                          size="sm"
                          loading={detailLoading && selectedSaleDetail?.id === sale.id}
                          onClick={() => handleOpenReceipt(sale)}
                        >
                          View receipt
                        </Button>
                        {!isVoided && (
                          <Button
                            variant="link"
                            size="sm"
                            className="text-[#D91515]"
                            onClick={() => setVoidTargetSale(sale)}
                          >
                            Void
                          </Button>
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

      {/* Receipt Detail Modal */}
      <Modal
        open={Boolean(selectedSaleDetail)}
        onClose={() => setSelectedSaleDetail(null)}
        title={`Sale receipt — ${
          selectedSaleDetail?.receiptNumber ||
          selectedSaleDetail?.number ||
          selectedSaleDetail?.id ||
          ''
        }`}
        size="md"
        footer={
          <Button onClick={() => setSelectedSaleDetail(null)}>Close</Button>
        }
      >
        {selectedSaleDetail && (
          <div className="space-y-4">
            <KeyValueGrid
              columns={3}
              items={[
                {
                  label: 'Customer',
                  value: selectedSaleDetail.customerName || 'Walk-in Customer',
                },
                {
                  label: 'Payment method',
                  value: selectedSaleDetail.paymentMethod || 'Cash',
                },
                {
                  label: 'Total amount',
                  value: `${Number(
                    selectedSaleDetail.totalAmount ??
                      selectedSaleDetail.grandTotal ??
                      0
                  ).toLocaleString()} ${selectedSaleDetail.currency || 'TZS'}`,
                },
              ]}
            />

            <div className="border border-[#E9EBED] rounded-[4px] overflow-hidden">
              <table className="w-full text-left border-collapse text-[12px]">
                <thead>
                  <tr className="bg-[#FAFAFA] border-b border-[#E9EBED] text-[#5F6B7A] uppercase text-[11px]">
                    <th className="py-2 px-3">Item</th>
                    <th className="py-2 px-3 text-right">Qty</th>
                    <th className="py-2 px-3 text-right">Unit price</th>
                    <th className="py-2 px-3 text-right">Line total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#E9EBED]">
                  {(selectedSaleDetail.lines || selectedSaleDetail.items || [])
                    .length === 0 ? (
                    <tr>
                      <td
                        colSpan={4}
                        className="py-4 text-center text-[#5F6B7A]"
                      >
                        No individual line items returned for this receipt.
                      </td>
                    </tr>
                  ) : (
                    (
                      selectedSaleDetail.lines ||
                      selectedSaleDetail.items ||
                      []
                    ).map((line, i) => (
                      <tr key={i}>
                        <td className="py-2 px-3 font-medium text-[#16191F]">
                          {line.productName || line.name || 'Item'}
                        </td>
                        <td className="py-2 px-3 text-right tabular-nums">
                          {line.quantity}
                        </td>
                        <td className="py-2 px-3 text-right tabular-nums">
                          {Number(line.unitPrice || 0).toLocaleString()}
                        </td>
                        <td className="py-2 px-3 text-right tabular-nums font-semibold">
                          {Number(
                            line.lineTotal ??
                              (line.quantity || 1) * (line.unitPrice || 0)
                          ).toLocaleString()}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </Modal>

      {/* Void Sale Modal */}
      <Modal
        open={Boolean(voidTargetSale)}
        onClose={() => setVoidTargetSale(null)}
        title="Void sale transaction"
        size="sm"
        footer={
          <>
            <Button onClick={() => setVoidTargetSale(null)}>Cancel</Button>
            <Button
              variant="dangerPrimary"
              loading={voiding}
              onClick={handleConfirmVoid}
            >
              Confirm void
            </Button>
          </>
        }
      >
        <form onSubmit={handleConfirmVoid} className="space-y-3">
          <Alert type="warning" title="Reversal warning">
            Voiding this receipt will reverse inventory deductions and mark the transaction as voided in the tenant ledger.
          </Alert>
          <div>
            <label className="block text-[12px] font-semibold text-[#16191F] mb-1">
              Reason for voiding (recorded in audit log)
            </label>
            <input
              type="text"
              required
              value={voidReason}
              onChange={(e) => setVoidReason(e.target.value)}
              className="w-full px-3 py-1.5 text-[13px] border border-[#879596] rounded-[4px] focus:outline-none focus:border-[#0972D3]"
            />
          </div>
        </form>
      </Modal>
    </div>
  );
}
