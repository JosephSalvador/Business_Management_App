using System.Text;

namespace BusinessOS.Infrastructure.Services;

/// <summary>
/// Ultra-lightweight, zero-external-dependency standard PDF binary document generator (PDF-1.4).
/// Formats documents into valid conforming binary PDF structures for immediate native canvas spooling.
/// </summary>
public static class MinimalPdfGenerator
{
    public static byte[] CreateDocument(
        string title,
        string documentNumber,
        string organizationName,
        string customerName,
        string totalFormatted,
        IReadOnlyList<(string Description, string Quantity, string Total)> items,
        bool isThermal = false,
        string? primaryHex = null)
    {
        // Dimensions in PDF points (72 points = 1 inch)
        // Standard A4: 595.28 x 841.89 points
        // Thermal 80mm: 226.77 points width, 600 points height (roll continuous)
        var pageWidth = isThermal ? 226.77 : 595.28;
        var pageHeight = isThermal ? 600.0 : 841.89;

        var sb = new StringBuilder();

        // PDF Stream content commands
        sb.AppendLine("BT");
        sb.AppendLine("/F1 16 Tf");

        if (isThermal)
        {
            // Thermal header
            sb.AppendLine("20 570 Td");
            sb.AppendLine($"({EscapePdfText(organizationName)}) Tj");
            sb.AppendLine("0 -20 Td");
            sb.AppendLine("/F1 12 Tf");
            sb.AppendLine($"({EscapePdfText(title)}: {EscapePdfText(documentNumber)}) Tj");
            sb.AppendLine("0 -18 Td");
            sb.AppendLine("/F1 10 Tf");
            sb.AppendLine($"({EscapePdfText("Customer: " + customerName)}) Tj");
            sb.AppendLine("0 -20 Td");
            sb.AppendLine("(--------------------------------) Tj");

            var yOffset = 0;
            foreach (var item in items)
            {
                yOffset -= 14;
                sb.AppendLine("0 -14 Td");
                var line = $"{item.Quantity}x {item.Description} - {item.Total}";
                if (line.Length > 32) line = line[..32];
                sb.AppendLine($"({EscapePdfText(line)}) Tj");
            }

            sb.AppendLine("0 -16 Td");
            sb.AppendLine("(--------------------------------) Tj");
            sb.AppendLine("0 -18 Td");
            sb.AppendLine("/F1 12 Tf");
            sb.AppendLine($"({EscapePdfText("TOTAL: " + totalFormatted)}) Tj");
            sb.AppendLine("0 -25 Td");
            sb.AppendLine("/F1 9 Tf");
            sb.AppendLine("(Thank you for your business!) Tj");
        }
        else
        {
            // A4 Corporate header
            sb.AppendLine("50 800 Td");
            sb.AppendLine($"({EscapePdfText(organizationName)}) Tj");
            sb.AppendLine("0 -24 Td");
            sb.AppendLine("/F1 14 Tf");
            sb.AppendLine($"({EscapePdfText(title)}) Tj");
            sb.AppendLine("0 -18 Td");
            sb.AppendLine("/F1 11 Tf");
            sb.AppendLine($"({EscapePdfText("Doc Number: " + documentNumber)}) Tj");
            sb.AppendLine("0 -16 Td");
            sb.AppendLine($"({EscapePdfText("Billed To: " + customerName)}) Tj");
            sb.AppendLine("0 -24 Td");
            sb.AppendLine("(--------------------------------------------------------------------------------) Tj");

            foreach (var item in items)
            {
                sb.AppendLine("0 -18 Td");
                var line = $"{item.Quantity.PadRight(8)} {item.Description.PadRight(45)} {item.Total}";
                sb.AppendLine($"({EscapePdfText(line)}) Tj");
            }

            sb.AppendLine("0 -24 Td");
            sb.AppendLine("(--------------------------------------------------------------------------------) Tj");
            sb.AppendLine("0 -22 Td");
            sb.AppendLine("/F1 13 Tf");
            sb.AppendLine($"({EscapePdfText("Total Due: " + totalFormatted)}) Tj");
        }

        sb.AppendLine("ET");

        var streamBytes = Encoding.Latin1.GetBytes(sb.ToString());
        var streamLength = streamBytes.Length;

        // Assembly of conforming PDF object table
        using var ms = new MemoryStream();
        var offsets = new List<long>();

        void Write(string str)
        {
            var bytes = Encoding.Latin1.GetBytes(str);
            ms.Write(bytes, 0, bytes.Length);
        }

        Write("%PDF-1.4\n%\xE2\xE3\xCF\xD3\n");

        // Object 1: Catalog
        offsets.Add(ms.Position);
        Write("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");

        // Object 2: Pages
        offsets.Add(ms.Position);
        Write($"2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 {pageWidth:F2} {pageHeight:F2}] >>\nendobj\n");

        // Object 3: Page
        offsets.Add(ms.Position);
        Write("3 0 obj\n<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n");

        // Object 4: Font (Helvetica)
        offsets.Add(ms.Position);
        Write("4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n");

        // Object 5: Stream
        offsets.Add(ms.Position);
        Write($"5 0 obj\n<< /Length {streamLength} >>\nstream\n");
        ms.Write(streamBytes, 0, streamLength);
        Write("\nendstream\nendobj\n");

        // Cross-reference table
        var xrefOffset = ms.Position;
        Write("xref\n");
        Write($"0 {offsets.Count + 1}\n");
        Write("0000000000 65535 f \n");
        foreach (var offset in offsets)
        {
            Write($"{offset:D10} 00000 n \n");
        }

        // Trailer
        Write("trailer\n");
        Write($"<< /Size {offsets.Count + 1} /Root 1 0 R >>\n");
        Write("startxref\n");
        Write($"{xrefOffset}\n");
        Write("%%EOF\n");

        return ms.ToArray();
    }

    private static string EscapePdfText(string text)
    {
        if (string.IsNullOrEmpty(text)) return string.Empty;
        return text
            .Replace("\\", "\\\\")
            .Replace("(", "\\(")
            .Replace(")", "\\)");
    }
}
