using BusinessOS.Shared.Entities;

namespace BusinessOS.Domain.Sales;

/// <summary>
/// Per-tenant, per-scope receipt counter (e.g. <c>Scope = "Sale"</c>). Allocation is a monotonic
/// increment; uniqueness across concurrent requests is guaranteed by the repository, which
/// increments the row under the per-tenant advisory lock + <c>SELECT ... FOR UPDATE</c> inside the
/// sale transaction. The <see cref="Pattern"/> renders the number, e.g.
/// <c>{prefix}-{year}-{sequence:000000}</c> → <c>S-2026-000123</c>.
/// </summary>
public sealed class NumberSequence : Entity
{
    private const string SequenceMarker = "{sequence:";

    private NumberSequence(Guid id, Guid tenantId, string scope, string prefix, string pattern)
        : base(id)
    {
        TenantId = tenantId;
        Scope = scope;
        Prefix = prefix;
        Pattern = pattern;
    }

    public Guid TenantId { get; private set; }
    public string Scope { get; private set; }

    /// <summary>Last allocated value; 0 until the first allocation, then monotonically increasing.</summary>
    public long CurrentValue { get; private set; }

    public string Prefix { get; private set; }
    public string Pattern { get; private set; }

    public static NumberSequence Create(Guid tenantId, string scope, string prefix, string pattern)
    {
        if (tenantId == Guid.Empty)
        {
            throw new ArgumentException("A tenant is required.", nameof(tenantId));
        }

        return new NumberSequence(
            Guid.NewGuid(),
            tenantId,
            NormalizeScope(scope),
            NormalizePrefix(prefix),
            NormalizePattern(pattern));
    }

    /// <summary>Platform default sale receipt sequence: scope <c>Sale</c>, prefix <c>S</c>.</summary>
    public static NumberSequence CreateSaleSequence(Guid tenantId)
        => Create(tenantId, "Sale", "S", "{prefix}-{year}-{sequence:000000}");

    /// <summary>
    /// Advances the counter by one and renders the next number. The year placeholder resolves to
    /// <paramref name="date"/> so an offline sale keeps the receipt year of its effective date.
    /// </summary>
    public string Allocate(DateTime date)
    {
        CurrentValue += 1;
        return Render(date, CurrentValue);
    }

    /// <summary>Renders the number for <paramref name="value"/> without advancing the counter.</summary>
    public string Render(DateTime date, long value)
    {
        if (value < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(value), "Sequence values start at 1.");
        }

        var (width, placeholder) = ParseSequencePlaceholder(Pattern);

        return Pattern
            .Replace("{prefix}", Prefix)
            .Replace("{year}", date.Year.ToString("D4"))
            .Replace(placeholder, value.ToString(new string('0', width)));
    }

    private static string NormalizeScope(string scope)
    {
        if (string.IsNullOrWhiteSpace(scope))
        {
            throw new ArgumentException("A scope is required.", nameof(scope));
        }

        return scope.Trim();
    }

    private static string NormalizePrefix(string prefix)
    {
        if (string.IsNullOrWhiteSpace(prefix))
        {
            throw new ArgumentException("A prefix is required.", nameof(prefix));
        }

        return prefix.Trim().ToUpperInvariant();
    }

    private static string NormalizePattern(string pattern)
    {
        if (string.IsNullOrWhiteSpace(pattern))
        {
            throw new ArgumentException("A pattern is required.", nameof(pattern));
        }

        ParseSequencePlaceholder(pattern.Trim());
        return pattern.Trim();
    }

    private static (int Width, string Placeholder) ParseSequencePlaceholder(string pattern)
    {
        var start = pattern.IndexOf(SequenceMarker, StringComparison.Ordinal);
        if (start < 0)
        {
            throw new ArgumentException("A pattern must contain a {sequence:NNN} placeholder.", nameof(pattern));
        }

        var end = pattern.IndexOf('}', start);
        if (end < 0)
        {
            throw new ArgumentException("A pattern must contain a {sequence:NNN} placeholder.", nameof(pattern));
        }

        var digits = pattern[(start + SequenceMarker.Length)..end];
        if (digits.Length == 0 || digits.Any(c => c is < '0' or > '9'))
        {
            throw new ArgumentException("The {sequence:NNN} placeholder must contain at least one digit.", nameof(pattern));
        }

        if (pattern.IndexOf(SequenceMarker, start + SequenceMarker.Length, StringComparison.Ordinal) >= 0)
        {
            throw new ArgumentException("A pattern must contain exactly one {sequence:NNN} placeholder.", nameof(pattern));
        }

        return (digits.Length, $"{SequenceMarker}{digits}}}");
    }
}
