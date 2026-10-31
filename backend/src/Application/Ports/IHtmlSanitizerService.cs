namespace BusinessOS.Application.Ports;

/// <summary>
/// Sanitizes custom HTML and Liquid template overrides, stripping hazardous tags
/// (&lt;script&gt;, &lt;iframe&gt;, &lt;object&gt;, etc.) and malicious event attributes
/// (onload, onclick, onerror, javascript: urls) while shielding Liquid delimiters ('{{' and '{%').
/// </summary>
public interface IHtmlSanitizerService
{
    string Sanitize(string? rawHtml);
}
