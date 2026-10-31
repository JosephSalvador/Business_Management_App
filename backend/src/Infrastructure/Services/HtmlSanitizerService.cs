using System.Text.RegularExpressions;
using BusinessOS.Application.Ports;

namespace BusinessOS.Infrastructure.Services;

/// <summary>
/// Safe HTML layout parser and tokenizer that shields '{{' and '{%' segments from stripping,
/// then purges all script blocks, iframes, objects, forms, inline event handlers (e.g. onclick, onerror),
/// and javascript: pseudo-protocols from custom tenant templates.
/// </summary>
public sealed class HtmlSanitizerService : IHtmlSanitizerService
{
    private static readonly Regex LiquidRegex = new(
        @"(\{\{[\s\S]*?\}\}|\{%[\s\S]*?%\})",
        RegexOptions.Compiled);

    private static readonly Regex DangerousTagsRegex = new(
        @"<(script|iframe|object|embed|applet|form|base|meta|link)[^>]*>([\s\S]*?<\/\1>)?",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex SelfClosingDangerousTagsRegex = new(
        @"<(script|iframe|object|embed|applet|form|base|meta|link)[^>]*\/?>",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex EventAttributesRegex = new(
        @"\bon[a-zA-Z]+\s*=\s*(""[^""]*""|'[^']*'|[^\s>]+)",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex JavascriptUriRegex = new(
        @"\b(href|src|action|dynsrc|lowsrc)\s*=\s*(""[^""]*(javascript:|vbscript:|data:text/html)[^""]*""|'[^']*(javascript:|vbscript:|data:text/html)[^']*')",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex StyleScriptRegex = new(
        @"\bstyle\s*=\s*(""[^""]*(expression\(|behavior:|javascript:)[^""]*""|'[^']*(expression\(|behavior:|javascript:)[^']*')",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    public string Sanitize(string? rawHtml)
    {
        if (string.IsNullOrWhiteSpace(rawHtml))
        {
            return string.Empty;
        }

        // 1. Tokenize and shield all '{{ ... }}' and '{% ... %}' segments
        var tokens = new List<string>();
        var shielded = LiquidRegex.Replace(rawHtml, match =>
        {
            var placeholder = $"___LIQUID_TOKEN_{tokens.Count}___";
            tokens.Add(match.Value);
            return placeholder;
        });

        // 2. Strip dangerous tags and their content
        var sanitized = DangerousTagsRegex.Replace(shielded, string.Empty);
        sanitized = SelfClosingDangerousTagsRegex.Replace(sanitized, string.Empty);

        // 3. Strip malicious event attributes (onclick, onerror, onload, onmouseover, etc.)
        sanitized = EventAttributesRegex.Replace(sanitized, string.Empty);

        // 4. Strip dangerous URI schemes (javascript:, vbscript:, data:text/html)
        sanitized = JavascriptUriRegex.Replace(sanitized, string.Empty);

        // 5. Strip dangerous style expressions
        sanitized = StyleScriptRegex.Replace(sanitized, string.Empty);

        // 6. Restore shielded Liquid segments
        for (var i = 0; i < tokens.Count; i++)
        {
            sanitized = sanitized.Replace($"___LIQUID_TOKEN_{i}___", tokens[i]);
        }

        return sanitized.Trim();
    }
}
