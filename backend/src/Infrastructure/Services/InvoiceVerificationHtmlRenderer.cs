using System.Net;
using System.Text;
using BusinessOS.Application.Features.Invoicing;
using BusinessOS.Domain.Invoicing;

namespace BusinessOS.Infrastructure.Services;

/// <summary>
/// High-speed server-rendered HTML engine for the public invoice verification page.
/// Produces a self-contained, responsive, accessible, zero-external-dependency HTML document
/// in under 5ms, optimized for mobile screens when users scan an invoice QR code.
/// </summary>
public static class InvoiceVerificationHtmlRenderer
{
    public static string Render(PublicInvoiceVerificationDto invoice)
    {
        var sb = new StringBuilder(16384);

        var title = $"{Escape(invoice.DocumentTitle)} {Escape(invoice.Number)} - Verified Document";
        var statusClass = invoice.Status switch
        {
            CustomerInvoiceStatus.Paid => "status-paid",
            CustomerInvoiceStatus.PartiallyPaid => "status-partial",
            CustomerInvoiceStatus.Void => "status-void",
            _ => "status-unpaid"
        };

        var statusLabelSwahili = invoice.Status switch
        {
            CustomerInvoiceStatus.Paid => "Imelipwa Yote",
            CustomerInvoiceStatus.PartiallyPaid => "Imelipwa Sehemu",
            CustomerInvoiceStatus.Void => "Imebatilishwa",
            _ => "Haijalipwa (Inadaiwa)"
        };

        var statusLabelEnglish = invoice.Status switch
        {
            CustomerInvoiceStatus.Paid => "Paid in Full",
            CustomerInvoiceStatus.PartiallyPaid => "Partially Paid",
            CustomerInvoiceStatus.Void => "Voided",
            _ => "Awaiting Payment"
        };

        sb.AppendLine("<!DOCTYPE html>");
        sb.AppendLine("<html lang=\"sw\">");
        sb.AppendLine("<head>");
        sb.AppendLine("  <meta charset=\"utf-8\" />");
        sb.AppendLine("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />");
        sb.AppendLine("  <meta name=\"robots\" content=\"noindex, nofollow, noarchive\" />");
        sb.AppendLine($"  <title>{title}</title>");
        sb.AppendLine("  <style>");
        sb.AppendLine(@"
    :root {
      --primary: #0f172a;
      --primary-accent: #2563eb;
      --success: #059669;
      --success-bg: #ecfdf5;
      --warning: #d97706;
      --warning-bg: #fffbeb;
      --danger: #dc2626;
      --danger-bg: #fef2f2;
      --neutral-50: #f8fafc;
      --neutral-100: #f1f5f9;
      --neutral-200: #e2e8f0;
      --neutral-300: #cbd5e1;
      --neutral-600: #475569;
      --neutral-700: #334155;
      --neutral-900: #0f172a;
      --radius: 12px;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, ""Segoe UI"", Roboto, Helvetica, Arial, sans-serif;
      background-color: var(--neutral-100);
      color: var(--neutral-900);
      line-height: 1.5;
      padding: 16px;
    }
    .container {
      max-width: 820px;
      margin: 0 auto 40px auto;
      background: #ffffff;
      border-radius: var(--radius);
      box-shadow: 0 10px 25px -5px rgba(0,0,0,0.06), 0 8px 10px -6px rgba(0,0,0,0.03);
      overflow: hidden;
      border: 1px solid var(--neutral-200);
    }
    .trust-banner {
      background: linear-gradient(135deg, #065f46 0%, #047857 100%);
      color: #ffffff;
      padding: 14px 20px;
      display: flex;
      align-items: center;
      gap: 12px;
      font-size: 13px;
      font-weight: 600;
      letter-spacing: 0.3px;
    }
    .trust-banner svg {
      width: 22px;
      height: 22px;
      flex-shrink: 0;
      fill: #a7f3d0;
    }
    .actions-bar {
      display: flex;
      justify-content: flex-end;
      gap: 10px;
      padding: 14px 24px;
      background: var(--neutral-50);
      border-bottom: 1px solid var(--neutral-200);
    }
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 8px 16px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      text-decoration: none;
      cursor: pointer;
      border: 1px solid transparent;
      transition: all 0.15s ease-in-out;
    }
    .btn-secondary {
      background: #ffffff;
      border-color: var(--neutral-300);
      color: var(--neutral-700);
    }
    .btn-secondary:hover {
      background: var(--neutral-100);
    }
    .btn-primary {
      background: var(--primary-accent);
      color: #ffffff;
    }
    .btn-primary:hover {
      background: #1d4ed8;
    }
    .invoice-body {
      padding: 28px 24px;
    }
    .header-grid {
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 20px;
      align-items: start;
      margin-bottom: 24px;
    }
    .merchant-brand {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .merchant-name {
      font-size: 22px;
      font-weight: 800;
      color: var(--primary);
      letter-spacing: -0.5px;
    }
    .merchant-meta {
      font-size: 13px;
      color: var(--neutral-600);
    }
    .doc-meta {
      text-align: right;
    }
    .doc-title {
      font-size: 24px;
      font-weight: 800;
      color: var(--primary);
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    .doc-number {
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      font-size: 15px;
      font-weight: 700;
      color: var(--primary-accent);
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      margin-top: 8px;
      padding: 6px 12px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .status-paid { background: var(--success-bg); color: var(--success); border: 1px solid #bbf7d0; }
    .status-partial { background: var(--warning-bg); color: var(--warning); border: 1px solid #fde68a; }
    .status-unpaid { background: #eff6ff; color: #2563eb; border: 1px solid #bfdbfe; }
    .status-void { background: var(--danger-bg); color: var(--danger); border: 1px solid #fecaca; }

    .party-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 20px;
      background: var(--neutral-50);
      border-radius: var(--radius);
      padding: 16px 20px;
      margin-bottom: 28px;
      border: 1px solid var(--neutral-200);
    }
    .party-col h4 {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      color: var(--neutral-600);
      margin-bottom: 6px;
      letter-spacing: 0.5px;
    }
    .party-col p {
      font-size: 13px;
      color: var(--neutral-700);
      line-height: 1.4;
    }
    .party-col .strong-name {
      font-weight: 700;
      font-size: 15px;
      color: var(--neutral-900);
      margin-bottom: 2px;
    }

    .table-container {
      width: 100%;
      overflow-x: auto;
      margin-bottom: 24px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
    }
    th {
      background: var(--neutral-100);
      color: var(--neutral-600);
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      padding: 10px 14px;
      border-bottom: 1px solid var(--neutral-200);
    }
    td {
      padding: 12px 14px;
      font-size: 13px;
      border-bottom: 1px solid var(--neutral-200);
      color: var(--neutral-700);
    }
    .text-right { text-align: right; }
    .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }

    .summary-grid {
      display: grid;
      grid-template-columns: 1fr 300px;
      gap: 24px;
      align-items: start;
      margin-bottom: 30px;
    }
    .payment-instructions-box {
      background: var(--neutral-50);
      border-radius: var(--radius);
      padding: 16px;
      font-size: 12px;
      border: 1px dashed var(--neutral-300);
    }
    .payment-instructions-box h5 {
      font-size: 12px;
      font-weight: 700;
      margin-bottom: 6px;
      color: var(--neutral-900);
      text-transform: uppercase;
    }
    .summary-card {
      background: var(--neutral-50);
      border-radius: var(--radius);
      padding: 16px 20px;
      border: 1px solid var(--neutral-200);
    }
    .summary-row {
      display: flex;
      justify-content: space-between;
      font-size: 13px;
      padding: 6px 0;
      color: var(--neutral-600);
    }
    .summary-row.total {
      font-size: 16px;
      font-weight: 800;
      color: var(--neutral-900);
      border-top: 1px solid var(--neutral-300);
      margin-top: 8px;
      padding-top: 10px;
    }
    .summary-row.due {
      font-size: 15px;
      font-weight: 800;
      color: #b91c1c;
      border-top: 1px dashed var(--neutral-300);
      margin-top: 6px;
      padding-top: 8px;
    }
    .summary-row.paid {
      color: var(--success);
      font-weight: 700;
    }

    .verification-seal {
      margin-top: 32px;
      padding: 16px 20px;
      background: #f0fdf4;
      border: 1px solid #bbf7d0;
      border-radius: var(--radius);
      display: flex;
      flex-direction: column;
      gap: 6px;
      font-size: 12px;
      color: #166534;
    }
    .verification-seal .seal-header {
      font-weight: 700;
      font-size: 13px;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .footer {
      text-align: center;
      font-size: 12px;
      color: var(--neutral-600);
      margin-top: 20px;
    }

    @media (max-width: 640px) {
      body { padding: 8px; }
      .header-grid { grid-template-columns: 1fr; }
      .doc-meta { text-align: left; }
      .party-grid { grid-template-columns: 1fr; gap: 14px; }
      .summary-grid { grid-template-columns: 1fr; }
      .actions-bar { justify-content: stretch; }
      .btn { flex: 1; justify-content: center; }
    }

    @media print {
      body { background: #ffffff; padding: 0; }
      .container { box-shadow: none; border: none; }
      .no-print { display: none !important; }
      .trust-banner { color: #000; background: none; border-bottom: 2px solid #000; padding: 10px 0; }
    }
  ");
        sb.AppendLine("  </style>");
        sb.AppendLine("</head>");
        sb.AppendLine("<body>");

        sb.AppendLine("  <div class=\"container\">");

        // Trust Banner
        sb.AppendLine("    <div class=\"trust-banner\">");
        sb.AppendLine("      <svg viewBox=\"0 0 24 24\"><path d=\"M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z\"/></svg>");
        sb.AppendLine("      <div>");
        sb.AppendLine("        HATI HALISI ILIYOTHIBITISHWA &bull; OFFICIAL AUTHENTIC INVOICE");
        sb.AppendLine("        <div style=\"font-size:11px;opacity:0.9;font-weight:400;\">Imetolewa kihalali na imehifadhiwa kwenye kumbukumbu rasmi za mfumo.</div>");
        sb.AppendLine("      </div>");
        sb.AppendLine("    </div>");

        // Actions Bar
        sb.AppendLine("    <div class=\"actions-bar no-print\">");
        sb.AppendLine("      <button onclick=\"window.print()\" class=\"btn btn-secondary\">");
        sb.AppendLine("        <svg width=\"15\" height=\"15\" viewBox=\"0 0 24 24\" fill=\"currentColor\"><path d=\"M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-4 11H9v-5h6v5zm4-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-3-9H8v3h8V3z\"/></svg>");
        sb.AppendLine("        Chapisha / Print");
        sb.AppendLine("      </button>");
        sb.AppendLine($"      <a href=\"/v/{Escape(invoice.VerificationToken)}/pdf\" class=\"btn btn-primary\" download>");
        sb.AppendLine("        <svg width=\"15\" height=\"15\" viewBox=\"0 0 24 24\" fill=\"currentColor\"><path d=\"M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z\"/></svg>");
        sb.AppendLine("        Pakua PDF / Download");
        sb.AppendLine("      </a>");
        sb.AppendLine("    </div>");

        // Invoice Body
        sb.AppendLine("    <div class=\"invoice-body\">");

        // Header Grid: Merchant + Doc Title & Status
        sb.AppendLine("      <div class=\"header-grid\">");
        sb.AppendLine("        <div class=\"merchant-brand\">");
        sb.AppendLine($"          <div class=\"merchant-name\">{Escape(invoice.Organization.Name)}</div>");
        if (!string.IsNullOrWhiteSpace(invoice.Organization.TaxId))
        {
            sb.AppendLine($"          <div class=\"merchant-meta\"><strong>TIN:</strong> {Escape(invoice.Organization.TaxId)}</div>");
        }
        if (!string.IsNullOrWhiteSpace(invoice.Organization.ContactPhone))
        {
            sb.AppendLine($"          <div class=\"merchant-meta\"><strong>Simu / Phone:</strong> {Escape(invoice.Organization.ContactPhone)}</div>");
        }
        if (!string.IsNullOrWhiteSpace(invoice.Organization.ContactEmail))
        {
            sb.AppendLine($"          <div class=\"merchant-meta\"><strong>Barua Pepe / Email:</strong> {Escape(invoice.Organization.ContactEmail)}</div>");
        }
        if (!string.IsNullOrWhiteSpace(invoice.Organization.Address))
        {
            sb.AppendLine($"          <div class=\"merchant-meta\"><strong>Mahali / Address:</strong> {Escape(invoice.Organization.Address)}</div>");
        }
        sb.AppendLine("        </div>");

        sb.AppendLine("        <div class=\"doc-meta\">");
        sb.AppendLine($"          <div class=\"doc-title\">{Escape(invoice.DocumentTitle)}</div>");
        sb.AppendLine($"          <div class=\"doc-number\">{Escape(invoice.Number)}</div>");
        sb.AppendLine($"          <div class=\"status-badge {statusClass}\">{statusLabelSwahili} &bull; {statusLabelEnglish}</div>");
        sb.AppendLine("        </div>");
        sb.AppendLine("      </div>");

        // Party Grid: Customer + Invoice Dates
        sb.AppendLine("      <div class=\"party-grid\">");
        sb.AppendLine("        <div class=\"party-col\">");
        sb.AppendLine("          <h4>Mteja / Billed To</h4>");
        var customerDisplayName = string.IsNullOrWhiteSpace(invoice.CustomerName) ? "Mteja wa Kawaida / Walk-in Customer" : invoice.CustomerName;
        sb.AppendLine($"          <div class=\"strong-name\">{Escape(customerDisplayName)}</div>");
        if (!string.IsNullOrWhiteSpace(invoice.CustomerAttention))
        {
            sb.AppendLine($"          <p><strong>Kwa:</strong> {Escape(invoice.CustomerAttention)}</p>");
        }
        if (!string.IsNullOrWhiteSpace(invoice.CustomerPhone))
        {
            sb.AppendLine($"          <p><strong>Simu:</strong> {Escape(invoice.CustomerPhone)}</p>");
        }
        if (!string.IsNullOrWhiteSpace(invoice.CustomerEmail))
        {
            sb.AppendLine($"          <p><strong>Email:</strong> {Escape(invoice.CustomerEmail)}</p>");
        }
        if (!string.IsNullOrWhiteSpace(invoice.CustomerTin))
        {
            sb.AppendLine($"          <p><strong>TIN:</strong> {Escape(invoice.CustomerTin)}</p>");
        }
        if (!string.IsNullOrWhiteSpace(invoice.CustomerAddress))
        {
            sb.AppendLine($"          <p><strong>Mahali:</strong> {Escape(invoice.CustomerAddress)}</p>");
        }
        sb.AppendLine("        </div>");

        sb.AppendLine("        <div class=\"party-col\">");
        sb.AppendLine("          <h4>Taarifa za Ankara / Invoice Dates</h4>");
        sb.AppendLine($"          <p><strong>Tarehe ya Kutolewa:</strong> {invoice.IssueDate:yyyy-MM-dd}</p>");
        if (invoice.DueDate.HasValue)
        {
            sb.AppendLine($"          <p><strong>Tarehe ya Mwisho:</strong> {invoice.DueDate.Value:yyyy-MM-dd}</p>");
        }
        if (!string.IsNullOrWhiteSpace(invoice.ReferenceNumber))
        {
            sb.AppendLine($"          <p><strong>Kumbukumbu / Ref:</strong> {Escape(invoice.ReferenceNumber)}</p>");
        }
        if (!string.IsNullOrWhiteSpace(invoice.PaymentTerms))
        {
            sb.AppendLine($"          <p><strong>Masharti:</strong> {Escape(invoice.PaymentTerms)}</p>");
        }
        sb.AppendLine("        </div>");
        sb.AppendLine("      </div>");

        // Itemized Line Items Table
        sb.AppendLine("      <div class=\"table-container\">");
        sb.AppendLine("        <table>");
        sb.AppendLine("          <thead>");
        sb.AppendLine("            <tr>");
        sb.AppendLine("              <th style=\"width:40px;\">#</th>");
        sb.AppendLine("              <th>Maelezo / Description</th>");
        sb.AppendLine("              <th class=\"text-right\">Kiasi / Qty</th>");
        sb.AppendLine("              <th class=\"text-right\">Bei / Rate</th>");
        sb.AppendLine("              <th class=\"text-right\">Jumla / Total</th>");
        sb.AppendLine("            </tr>");
        sb.AppendLine("          </thead>");
        sb.AppendLine("          <tbody>");

        var lineIndex = 1;
        foreach (var line in invoice.Lines)
        {
            var qtyFormatted = line.Quantity % 1 == 0 ? $"{line.Quantity:0}" : $"{line.Quantity:0.##}";
            var uom = string.IsNullOrWhiteSpace(line.UnitOfMeasure) ? "" : $" {line.UnitOfMeasure}";
            sb.AppendLine("            <tr>");
            sb.AppendLine($"              <td class=\"mono\">{lineIndex++}</td>");
            sb.AppendLine($"              <td><strong>{Escape(line.Description)}</strong></td>");
            sb.AppendLine($"              <td class=\"text-right mono\">{qtyFormatted}{Escape(uom)}</td>");
            sb.AppendLine($"              <td class=\"text-right mono\">{line.UnitPrice:N2}</td>");
            sb.AppendLine($"              <td class=\"text-right mono\"><strong>{line.LineTotal:N2}</strong></td>");
            sb.AppendLine("            </tr>");
        }

        sb.AppendLine("          </tbody>");
        sb.AppendLine("        </table>");
        sb.AppendLine("      </div>");

        // Summary Grid
        sb.AppendLine("      <div class=\"summary-grid\">");
        sb.AppendLine("        <div class=\"payment-instructions-box\">");
        sb.AppendLine("          <h5>Akaunti za Malipo / Payment Instructions</h5>");

        var hasPaymentInfo = false;
        if (!string.IsNullOrWhiteSpace(invoice.Organization.BankName) && !string.IsNullOrWhiteSpace(invoice.Organization.BankAccountNumber))
        {
            hasPaymentInfo = true;
            sb.AppendLine($"          <p><strong>Benki / Bank:</strong> {Escape(invoice.Organization.BankName)}</p>");
            if (!string.IsNullOrWhiteSpace(invoice.Organization.BankAccountName))
            {
                sb.AppendLine($"          <p><strong>Jina la Akaunti:</strong> {Escape(invoice.Organization.BankAccountName)}</p>");
            }
            sb.AppendLine($"          <p><strong>Akaunti Namba:</strong> <span class=\"mono\"><strong>{Escape(invoice.Organization.BankAccountNumber)}</strong></span></p>");
            if (!string.IsNullOrWhiteSpace(invoice.Organization.BankBranchOrSwift))
            {
                sb.AppendLine($"          <p><strong>Tawi / SWIFT:</strong> {Escape(invoice.Organization.BankBranchOrSwift)}</p>");
            }
        }

        if (!string.IsNullOrWhiteSpace(invoice.Organization.MobileMoneyDetails))
        {
            hasPaymentInfo = true;
            sb.AppendLine($"          <p style=\"margin-top:6px;\"><strong>Mitandao ya Simu:</strong> {Escape(invoice.Organization.MobileMoneyDetails)}</p>");
        }

        if (!string.IsNullOrWhiteSpace(invoice.PaymentInstructions))
        {
            hasPaymentInfo = true;
            sb.AppendLine($"          <p style=\"margin-top:6px;\">{Escape(invoice.PaymentInstructions)}</p>");
        }

        if (!hasPaymentInfo)
        {
            sb.AppendLine("          <p style=\"color:var(--neutral-600);\">Wasiliana na muuzaji moja kwa moja kupokea maelekezo ya malipo.</p>");
        }

        if (!string.IsNullOrWhiteSpace(invoice.Notes))
        {
            sb.AppendLine($"          <div style=\"margin-top:10px;padding-top:8px;border-top:1px dashed var(--neutral-300);\"><strong>Maelezo ya Ziada / Notes:</strong><br/>{Escape(invoice.Notes)}</div>");
        }

        sb.AppendLine("        </div>");

        // Financial totals card
        sb.AppendLine("        <div class=\"summary-card\">");
        sb.AppendLine("          <div class=\"summary-row\">");
        sb.AppendLine($"            <span>Jumla Ndogo / Subtotal</span><span class=\"mono\">{invoice.Currency} {invoice.Subtotal:N2}</span>");
        sb.AppendLine("          </div>");

        if (invoice.DiscountAmount > 0)
        {
            sb.AppendLine("          <div class=\"summary-row\">");
            sb.AppendLine($"            <span>Punguzo / Discount</span><span class=\"mono\">- {invoice.Currency} {invoice.DiscountAmount:N2}</span>");
            sb.AppendLine("          </div>");
        }

        sb.AppendLine("          <div class=\"summary-row total\">");
        sb.AppendLine($"            <span>Jumla Kuu / Total</span><span class=\"mono\">{invoice.Currency} {invoice.TotalAmount:N2}</span>");
        sb.AppendLine("          </div>");

        if (invoice.AmountPaid > 0)
        {
            sb.AppendLine("          <div class=\"summary-row paid\">");
            sb.AppendLine($"            <span>Imelipwa / Paid</span><span class=\"mono\">{invoice.Currency} {invoice.AmountPaid:N2}</span>");
            sb.AppendLine("          </div>");
        }

        if (invoice.BalanceDue > 0)
        {
            sb.AppendLine("          <div class=\"summary-row due\">");
            sb.AppendLine($"            <span>Salio / Balance Due</span><span class=\"mono\">{invoice.Currency} {invoice.BalanceDue:N2}</span>");
            sb.AppendLine("          </div>");
        }
        else if (invoice.Status == CustomerInvoiceStatus.Paid)
        {
            sb.AppendLine("          <div class=\"summary-row\" style=\"color:var(--success);font-weight:700;margin-top:4px;\">");
            sb.AppendLine("            <span>Salio / Balance</span><span class=\"mono\">0.00 (Imekamilika)</span>");
            sb.AppendLine("          </div>");
        }

        sb.AppendLine("        </div>");
        sb.AppendLine("      </div>");

        // Signatory if present
        if (!string.IsNullOrWhiteSpace(invoice.AuthorizedSignatoryName))
        {
            sb.AppendLine("      <div style=\"display:flex;justify-content:flex-end;margin-top:20px;\">");
            sb.AppendLine("        <div style=\"text-align:right;border-top:1px solid var(--neutral-300);padding-top:8px;min-width:200px;\">");
            sb.AppendLine($"          <div style=\"font-weight:700;font-size:13px;\">{Escape(invoice.AuthorizedSignatoryName)}</div>");
            if (!string.IsNullOrWhiteSpace(invoice.AuthorizedSignatoryTitle))
            {
                sb.AppendLine($"          <div style=\"font-size:12px;color:var(--neutral-600);\">{Escape(invoice.AuthorizedSignatoryTitle)}</div>");
            }
            sb.AppendLine("        </div>");
            sb.AppendLine("      </div>");
        }

        // Verification Seal
        sb.AppendLine("      <div class=\"verification-seal\">");
        sb.AppendLine("        <div class=\"seal-header\">");
        sb.AppendLine("          <svg width=\"18\" height=\"18\" viewBox=\"0 0 24 24\" fill=\"#059669\"><path d=\"M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z\"/></svg>");
        sb.AppendLine("          <span>HATI HII NI HALISI &bull; OFFICIAL VERIFIED DOCUMENT</span>");
        sb.AppendLine("        </div>");
        sb.AppendLine($"        <div>Kodi ya Uthibitisho / Verification Token: <strong class=\"mono\">{Escape(invoice.VerificationToken)}</strong></div>");
        sb.AppendLine($"        <div style=\"font-size:11px;opacity:0.8;\">Tarehe ya Uhakiki / Verified at: {invoice.VerifiedAtUtc:yyyy-MM-dd HH:mm:ss} UTC</div>");
        sb.AppendLine("      </div>");

        sb.AppendLine("    </div>"); // .invoice-body
        sb.AppendLine("  </div>");   // .container

        sb.AppendLine("  <div class=\"footer no-print\">");
        sb.AppendLine("    Imewezeshwa na Jolinx Business OS &bull; Mfumo wa Kisasa wa Uendeshaji Biashara");
        sb.AppendLine("  </div>");

        sb.AppendLine("</body>");
        sb.AppendLine("</html>");

        return sb.ToString();
    }

    private static string Escape(string? input) => WebUtility.HtmlEncode(input ?? string.Empty);
}
