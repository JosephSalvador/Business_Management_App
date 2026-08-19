using System.Text;

namespace BusinessOS.Application.Ports;

public interface ICsvExportService
{
    byte[] Export<T>(IReadOnlyList<T> rows, string[] headers, Func<T, object[]> mapRow);
}

public sealed class CsvExportService : ICsvExportService
{
    public byte[] Export<T>(IReadOnlyList<T> rows, string[] headers, Func<T, object[]> mapRow)
    {
        var sb = new StringBuilder();
        sb.AppendLine(string.Join(",", headers));

        foreach (var row in rows)
        {
            var values = mapRow(row).Select(v => EscapeCsvValue(v?.ToString() ?? ""));
            sb.AppendLine(string.Join(",", values));
        }

        return Encoding.UTF8.GetBytes(sb.ToString());
    }

    private static string EscapeCsvValue(string value)
    {
        if (value.Contains(',') || value.Contains('"') || value.Contains('\n'))
        {
            return $"\"{value.Replace("\"", "\"\"")}\"";
        }
        return value;
    }
}
