import React, { useState, useEffect } from 'react';
import {
  Search,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  Printer,
  Eye,
  Receipt,
} from 'lucide-react';
import {
  listTenantSales,
  getTenantSaleReceiptPreview,
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

  // Sale Receipt Preview Modal
  const [selectedSaleDetail, setSelectedSaleDetail] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [receiptViewMode, setReceiptViewMode] = useState('thermal'); // 'thermal' | 'table'

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
    setReceiptViewMode('thermal');
    try {
      const detail = await getTenantSaleReceiptPreview(tenantId, sale.id);
      setSelectedSaleDetail(detail || sale);
    } catch {
      setSelectedSaleDetail(sale);
    } finally {
      setDetailLoading(false);
    }
  };

  const handlePrintReceipt = () => {
    if (!selectedSaleDetail) return;
    const s = selectedSaleDetail;
    const currency = s.currency || 'TZS';
    const total = Number(s.totalAmount ?? s.grandTotal ?? 0);
    const subtotal = Number(s.subtotal ?? total);
    const discount = Number(s.discountAmount ?? 0);
    const paid = Number(s.amountPaid ?? total);
    const change = Number(s.change ?? 0);
    const lines = s.lines || s.items || [];
    const primaryColor = s.themePrimaryHex || '#0F172A';
    const logoSrc = s.logoBase64
      ? s.logoBase64.startsWith('data:') || s.logoBase64.startsWith('http')
        ? s.logoBase64
        : `data:image/png;base64,${s.logoBase64}`
      : null;

    const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Receipt ${s.receiptNumber || s.number || s.id}</title>
  <style>
    body { font-family: 'JetBrains Mono', 'Courier New', monospace; width: 300px; margin: 0 auto; padding: 12px; color: #111; font-size: 12px; }
    .center { text-align: center; }
    .bold { font-weight: 700; }
    .divider { border-top: 1px dashed #888; margin: 8px 0; }
    .row { display: flex; justify-content: space-between; margin: 3px 0; }
    .accent { height: 4px; background: ${primaryColor}; margin-bottom: 10px; border-radius: 2px; }
    img.logo { max-height: 48px; max-width: 160px; object-fit: contain; margin: 0 auto 6px; display: block; }
  </style>
</head>
<body onload="window.print()">
  <div class="accent"></div>
  ${logoSrc ? `<img class="logo" src="${logoSrc}" alt="Logo" />` : ''}
  <div class="center bold" style="font-size:15px;">${s.businessName || 'Business Receipt'}</div>
  ${s.branchName ? `<div class="center">${s.branchName}</div>` : ''}
  ${s.address ? `<div class="center">${s.address}</div>` : ''}
  ${s.phone ? `<div class="center">Tel: ${s.phone}</div>` : ''}
  ${s.tin ? `<div class="center bold">TIN: ${s.tin}</div>` : ''}
  <div class="divider"></div>
  <div class="row"><span>Receipt #:</span><span class="bold">${s.receiptNumber || s.number || ''}</span></div>
  <div class="row"><span>Date:</span><span>${s.createdAt ? new Date(s.createdAt).toLocaleString() : ''}</span></div>
  <div class="row"><span>Customer:</span><span>${s.customerName || 'Walk-in Customer'}</span></div>
  <div class="row"><span>Cashier:</span><span>${s.cashierName || 'Cashier'}</span></div>
  <div class="row"><span>Payment:</span><span class="bold">${s.paymentMethod || 'Cash'}</span></div>
  <div class="divider"></div>
  ${lines
    .map(
      (l) => `
    <div style="margin: 4px 0;">
      <div class="bold">${l.productName || l.name || 'Item'}</div>
      <div class="row">
        <span>${l.quantity} x ${Number(l.unitPrice || 0).toLocaleString()}</span>
        <span class="bold">${Number(l.totalPrice ?? l.lineTotal ?? (l.quantity || 1) * (l.unitPrice || 0)).toLocaleString()}</span>
      </div>
    </div>`
    )
    .join('')}
  <div class="divider"></div>
  <div class="row"><span>Subtotal:</span><span>${subtotal.toLocaleString()} ${currency}</span></div>
  ${discount > 0 ? `<div class="row"><span>Discount:</span><span>-${discount.toLocaleString()} ${currency}</span></div>` : ''}
  <div class="row bold" style="font-size:14px;margin-top:4px;"><span>TOTAL:</span><span>${total.toLocaleString()} ${currency}</span></div>
  <div class="row"><span>Paid:</span><span>${paid.toLocaleString()} ${currency}</span></div>
  ${change > 0 ? `<div class="row"><span>Change:</span><span>${change.toLocaleString()} ${currency}</span></div>` : ''}
  ${
    s.mobileMoneyDetails || s.bankAccountNumber
      ? `<div class="divider"></div>
         ${s.mobileMoneyDetails ? `<div class="center" style="font-size:11px;">M-Pesa / Lipa: ${s.mobileMoneyDetails}</div>` : ''}
         ${s.bankAccountNumber ? `<div class="center" style="font-size:11px;">${s.bankName || 'Bank'}: ${s.bankAccountNumber}</div>` : ''}`
      : ''
  }
  <div class="divider"></div>
  <div class="center" style="font-size:11px;">${s.footerNotes || 'Thank you for your business!'}</div>
</body>
</html>`;

    const win = window.open('', '_blank', 'width=420,height=680');
    if (win) {
      win.document.open();
      win.document.write(html);
      win.document.close();
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
        description="Complete ledger of point-of-sale checkouts, live thermal receipt previews using the tenant's phone settings, and void controls."
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
                          className="hover:underline inline-flex items-center gap-1"
                        >
                          <Receipt className="w-3.5 h-3.5" />
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
                          size="sm"
                          icon={Eye}
                          loading={detailLoading && selectedSaleDetail?.id === sale.id}
                          onClick={() => handleOpenReceipt(sale)}
                        >
                          Preview receipt
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

      {/* Receipt Preview Modal (Rendered with Tenant's Phone Settings) */}
      <Modal
        open={Boolean(selectedSaleDetail)}
        onClose={() => setSelectedSaleDetail(null)}
        title={`POS Receipt Preview — ${
          selectedSaleDetail?.receiptNumber ||
          selectedSaleDetail?.number ||
          selectedSaleDetail?.id ||
          ''
        }`}
        size="lg"
        footer={
          <div className="flex items-center justify-between w-full">
            <div className="text-[12px] text-[#5F6B7A]">
              Previewed with tenant’s mobile app receipt settings & branding.
            </div>
            <div className="flex items-center gap-2">
              <Button
                variant="primary"
                icon={Printer}
                onClick={handlePrintReceipt}
              >
                Print 80mm Receipt
              </Button>
              <Button onClick={() => setSelectedSaleDetail(null)}>Close</Button>
            </div>
          </div>
        }
      >
        {selectedSaleDetail && (
          <div className="space-y-4">
            {/* Toolbar: Tenant Settings Info + View Toggle */}
            <div className="px-3.5 py-2 bg-[#F8F9FA] border border-[#D5DBDB] rounded-[4px] flex flex-wrap items-center justify-between gap-2 text-[12px]">
              <div className="flex flex-wrap items-center gap-3">
                <div>
                  <span className="text-[#5F6B7A] mr-1">Shop:</span>
                  <span className="font-semibold text-[#16191F]">
                    {selectedSaleDetail.businessName || 'Tenant Shop'}
                  </span>
                </div>
                {selectedSaleDetail.tin && (
                  <div>
                    <span className="text-[#5F6B7A] mr-1">TIN:</span>
                    <span className="font-mono font-medium text-[#16191F]">
                      {selectedSaleDetail.tin}
                    </span>
                  </div>
                )}
                {selectedSaleDetail.branchName && (
                  <div>
                    <span className="text-[#5F6B7A] mr-1">Branch:</span>
                    <span className="font-medium text-[#16191F]">
                      {selectedSaleDetail.branchName}
                    </span>
                  </div>
                )}
              </div>

              <div className="inline-flex rounded-[4px] border border-[#879596] overflow-hidden bg-white">
                <button
                  type="button"
                  onClick={() => setReceiptViewMode('thermal')}
                  className={`px-2.5 py-1 text-[11px] font-semibold transition-colors ${
                    receiptViewMode === 'thermal'
                      ? 'bg-[#0972D3] text-white'
                      : 'text-[#16191F] hover:bg-[#F2F3F3]'
                  }`}
                >
                  80mm Thermal Slip (Phone Preview)
                </button>
                <button
                  type="button"
                  onClick={() => setReceiptViewMode('table')}
                  className={`px-2.5 py-1 text-[11px] font-semibold transition-colors border-l border-[#879596] ${
                    receiptViewMode === 'table'
                      ? 'bg-[#0972D3] text-white'
                      : 'text-[#16191F] hover:bg-[#F2F3F3]'
                  }`}
                >
                  Ledger Table
                </button>
              </div>
            </div>

            {receiptViewMode === 'thermal' ? (
              <div className="bg-[#EAEDED] border border-[#D5DBDB] rounded-[4px] py-6 px-4 flex justify-center">
                {/* Realistic 80mm POS Thermal Slip Styled with Tenant Phone Settings */}
                <div className="w-[330px] bg-white shadow-lg border border-[#D5DBDB] rounded-[2px] p-4 font-mono text-[12px] text-[#16191F]">
                  {/* Tenant Brand Color Accent Strip */}
                  <div
                    className="h-1.5 w-full rounded-full mb-3"
                    style={{
                      backgroundColor:
                        selectedSaleDetail.themePrimaryHex || '#0F172A',
                    }}
                  />

                  {/* Tenant Logo (if set on phone) */}
                  {selectedSaleDetail.logoBase64 && (
                    <div className="flex justify-center mb-2">
                      <img
                        src={
                          selectedSaleDetail.logoBase64.startsWith('data:') ||
                          selectedSaleDetail.logoBase64.startsWith('http')
                            ? selectedSaleDetail.logoBase64
                            : `data:image/png;base64,${selectedSaleDetail.logoBase64}`
                        }
                        alt="Tenant Logo"
                        className="max-h-12 max-w-[160px] object-contain"
                      />
                    </div>
                  )}

                  {/* Business Identity Header */}
                  <div className="text-center space-y-0.5">
                    <div className="font-bold text-[14px] tracking-tight uppercase">
                      {selectedSaleDetail.businessName || 'Tenant Business'}
                    </div>
                    {selectedSaleDetail.branchName && (
                      <div className="text-[11px] text-[#5F6B7A]">
                        {selectedSaleDetail.branchName}
                      </div>
                    )}
                    {selectedSaleDetail.address && (
                      <div className="text-[11px] text-[#5F6B7A]">
                        {selectedSaleDetail.address}
                      </div>
                    )}
                    {selectedSaleDetail.phone && (
                      <div className="text-[11px] text-[#5F6B7A]">
                        Tel: {selectedSaleDetail.phone}
                      </div>
                    )}
                    {selectedSaleDetail.tin && (
                      <div className="text-[11px] font-bold text-[#16191F]">
                        TIN: {selectedSaleDetail.tin}
                      </div>
                    )}
                  </div>

                  <div className="border-t border-dashed border-[#879596] my-2.5" />

                  {/* Receipt Metadata */}
                  <div className="space-y-1 text-[11px]">
                    <div className="flex justify-between">
                      <span className="text-[#5F6B7A]">RECEIPT #:</span>
                      <span className="font-bold">
                        {selectedSaleDetail.receiptNumber ||
                          selectedSaleDetail.number ||
                          selectedSaleDetail.id?.slice(0, 8)}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-[#5F6B7A]">DATE:</span>
                      <span>
                        {selectedSaleDetail.createdAt
                          ? new Date(
                              selectedSaleDetail.createdAt
                            ).toLocaleString()
                          : '—'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-[#5F6B7A]">CUSTOMER:</span>
                      <span className="font-medium">
                        {selectedSaleDetail.customerName || 'Walk-in Customer'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-[#5F6B7A]">CASHIER:</span>
                      <span>
                        {selectedSaleDetail.cashierName || 'POS Cashier'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-[#5F6B7A]">PAYMENT:</span>
                      <span className="font-bold uppercase">
                        {selectedSaleDetail.paymentMethod || 'Cash'}
                      </span>
                    </div>
                  </div>

                  <div className="border-t border-dashed border-[#879596] my-2.5" />

                  {/* Line Items */}
                  <div className="space-y-2">
                    {(
                      selectedSaleDetail.lines ||
                      selectedSaleDetail.items ||
                      []
                    ).length === 0 ? (
                      <div className="text-center py-2 text-[#5F6B7A] text-[11px]">
                        No line items recorded
                      </div>
                    ) : (
                      (
                        selectedSaleDetail.lines ||
                        selectedSaleDetail.items ||
                        []
                      ).map((line, i) => {
                        const lineTotal =
                          line.totalPrice ??
                          line.lineTotal ??
                          (line.quantity || 1) * (line.unitPrice || 0);
                        return (
                          <div key={i} className="text-[11px]">
                            <div className="font-semibold text-[#16191F]">
                              {line.productName || line.name || 'Item'}
                            </div>
                            <div className="flex justify-between text-[#5F6B7A]">
                              <span>
                                {line.quantity} x{' '}
                                {Number(line.unitPrice || 0).toLocaleString()}
                              </span>
                              <span className="font-bold text-[#16191F]">
                                {Number(lineTotal).toLocaleString()}
                              </span>
                            </div>
                          </div>
                        );
                      })
                    )}
                  </div>

                  <div className="border-t border-dashed border-[#879596] my-2.5" />

                  {/* Totals */}
                  <div className="space-y-1 text-[11px]">
                    {selectedSaleDetail.subtotal != null && (
                      <div className="flex justify-between">
                        <span className="text-[#5F6B7A]">SUBTOTAL:</span>
                        <span>
                          {Number(selectedSaleDetail.subtotal).toLocaleString()}{' '}
                          {selectedSaleDetail.currency || 'TZS'}
                        </span>
                      </div>
                    )}
                    {Number(selectedSaleDetail.discountAmount || 0) > 0 && (
                      <div className="flex justify-between text-[#037F0C]">
                        <span>DISCOUNT:</span>
                        <span>
                          -
                          {Number(
                            selectedSaleDetail.discountAmount
                          ).toLocaleString()}{' '}
                          {selectedSaleDetail.currency || 'TZS'}
                        </span>
                      </div>
                    )}
                    <div className="flex justify-between text-[13px] font-bold pt-1 border-t border-[#E9EBED]">
                      <span>TOTAL:</span>
                      <span>
                        {Number(
                          selectedSaleDetail.totalAmount ??
                            selectedSaleDetail.grandTotal ??
                            0
                        ).toLocaleString()}{' '}
                        {selectedSaleDetail.currency || 'TZS'}
                      </span>
                    </div>
                    {selectedSaleDetail.amountPaid != null && (
                      <div className="flex justify-between">
                        <span className="text-[#5F6B7A]">AMOUNT PAID:</span>
                        <span>
                          {Number(
                            selectedSaleDetail.amountPaid
                          ).toLocaleString()}{' '}
                          {selectedSaleDetail.currency || 'TZS'}
                        </span>
                      </div>
                    )}
                    {Number(selectedSaleDetail.change || 0) > 0 && (
                      <div className="flex justify-between">
                        <span className="text-[#5F6B7A]">CHANGE:</span>
                        <span>
                          {Number(selectedSaleDetail.change).toLocaleString()}{' '}
                          {selectedSaleDetail.currency || 'TZS'}
                        </span>
                      </div>
                    )}
                  </div>

                  {/* Tenant Payment Channels (if configured on phone) */}
                  {(selectedSaleDetail.mobileMoneyDetails ||
                    selectedSaleDetail.bankAccountNumber) && (
                    <>
                      <div className="border-t border-dashed border-[#879596] my-2.5" />
                      <div className="text-[10px] text-center space-y-0.5 text-[#5F6B7A]">
                        {selectedSaleDetail.mobileMoneyDetails && (
                          <div>
                            Lipa / Mobile Money:{' '}
                            <span className="font-semibold text-[#16191F]">
                              {selectedSaleDetail.mobileMoneyDetails}
                            </span>
                          </div>
                        )}
                        {selectedSaleDetail.bankAccountNumber && (
                          <div>
                            {selectedSaleDetail.bankName || 'Bank'}:{' '}
                            <span className="font-semibold text-[#16191F]">
                              {selectedSaleDetail.bankAccountNumber}
                            </span>
                          </div>
                        )}
                      </div>
                    </>
                  )}

                  <div className="border-t border-dashed border-[#879596] my-2.5" />

                  {/* Tenant Custom Footer Notes */}
                  <div className="text-center text-[10px] text-[#5F6B7A] space-y-1">
                    <div>
                      {selectedSaleDetail.footerNotes ||
                        'Thank you for your business! / Asante kwa kufanya biashara nasi!'}
                    </div>
                    {selectedSaleDetail.fiscalHash && (
                      <div className="font-mono text-[9px] text-[#879596] pt-1">
                        VERIFY: {selectedSaleDetail.fiscalHash.slice(0, 16)}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ) : (
              <div className="space-y-4">
                <KeyValueGrid
                  columns={3}
                  items={[
                    {
                      label: 'Customer',
                      value:
                        selectedSaleDetail.customerName || 'Walk-in Customer',
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
                      ).toLocaleString()} ${
                        selectedSaleDetail.currency || 'TZS'
                      }`,
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
                      {(
                        selectedSaleDetail.lines ||
                        selectedSaleDetail.items ||
                        []
                      ).length === 0 ? (
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
                                line.totalPrice ??
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
