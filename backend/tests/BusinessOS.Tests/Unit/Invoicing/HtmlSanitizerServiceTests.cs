using BusinessOS.Infrastructure.Services;

namespace BusinessOS.Tests.Unit.Invoicing;

public sealed class HtmlSanitizerServiceTests
{
    private readonly HtmlSanitizerService _sanitizer = new();

    [Fact]
    public void Sanitize_StripsScriptTagsAndDangerousElements()
    {
        var input = @"<div class=""invoice"">
    <h1>Invoice</h1>
    <script>alert('xss');</script>
    <iframe src=""https://evil.com""></iframe>
    <object data=""evil.swf""></object>
    <p>Legitimate content</p>
</div>";

        var sanitized = _sanitizer.Sanitize(input);

        Assert.DoesNotContain("<script", sanitized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("alert('xss')", sanitized);
        Assert.DoesNotContain("<iframe", sanitized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("<object", sanitized, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("<h1>Invoice</h1>", sanitized);
        Assert.Contains("<p>Legitimate content</p>", sanitized);
    }

    [Fact]
    public void Sanitize_StripsEventAttributesAndJavascriptUris()
    {
        var input = @"<div onclick=""doBadStuff()"" onmouseover=""evil()"" class=""card"">
    <a href=""javascript:stealTokens()"">Click here</a>
    <img src=""javascript:attack()"" onerror=""fallbackBad()"" />
    <span style=""color: red;"">Clean styled text</span>
</div>";

        var sanitized = _sanitizer.Sanitize(input);

        Assert.DoesNotContain("onclick", sanitized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("onmouseover", sanitized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("onerror", sanitized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("javascript:", sanitized, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("<span style=\"color: red;\">Clean styled text</span>", sanitized);
    }

    [Fact]
    public void Sanitize_ShieldsLiquidSegmentsFromCorruption()
    {
        var input = @"<div class=""invoice-header"" style=""border-color: {{ theme.primary_hex }};"">
    <h2>{{ invoice.document_title }} #{{ invoice.number }}</h2>
    <table>
        <tbody>
        {% for line in invoice.lines %}
            <tr class=""{% if forloop.first %}first-row{% endif %}"">
                <td>{{ line.description }}</td>
                <td>{{ line.quantity }} {{ line.unit_of_measure }}</td>
                <td>{{ line.line_total }}</td>
            </tr>
        {% endfor %}
        </tbody>
    </table>
    <script>evilCode();</script>
</div>";

        var sanitized = _sanitizer.Sanitize(input);

        // Verify malicious script was purged
        Assert.DoesNotContain("<script", sanitized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("evilCode()", sanitized);

        // Verify Liquid tokens were safely shielded and restored verbatim
        Assert.Contains("{{ theme.primary_hex }}", sanitized);
        Assert.Contains("{{ invoice.document_title }}", sanitized);
        Assert.Contains("{{ invoice.number }}", sanitized);
        Assert.Contains("{% for line in invoice.lines %}", sanitized);
        Assert.Contains("{% if forloop.first %}first-row{% endif %}", sanitized);
        Assert.Contains("{{ line.description }}", sanitized);
        Assert.Contains("{{ line.quantity }}", sanitized);
        Assert.Contains("{{ line.line_total }}", sanitized);
        Assert.Contains("{% endfor %}", sanitized);
    }

    [Theory]
    [InlineData(null, "")]
    [InlineData("", "")]
    [InlineData("   ", "")]
    public void Sanitize_NullOrWhitespace_ReturnsEmptyString(string? input, string expected)
    {
        var result = _sanitizer.Sanitize(input);
        Assert.Equal(expected, result);
    }
}
