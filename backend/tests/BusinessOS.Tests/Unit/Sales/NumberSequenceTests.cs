using BusinessOS.Domain.Sales;

namespace BusinessOS.Tests.Unit.Sales;

public sealed class NumberSequenceTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime SaleDate = new(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc);

    private static NumberSequence SaleSequence(string pattern = "{prefix}-{year}-{sequence:000000}")
        => NumberSequence.Create(TenantId, "Sale", "S", pattern);

    [Fact]
    public void Create_NormalizesScopePrefixAndPattern()
    {
        var sequence = NumberSequence.Create(TenantId, " Sale ", " s ", "{prefix}-{sequence:0}");

        Assert.Equal("Sale", sequence.Scope);
        Assert.Equal("S", sequence.Prefix);
        Assert.Equal(0L, sequence.CurrentValue);
        Assert.Equal(TenantId, sequence.TenantId);
    }

    [Fact]
    public void Allocate_ReturnsFormattedNumberAndIncrements()
    {
        var sequence = SaleSequence();

        var first = sequence.Allocate(SaleDate);

        Assert.Equal("S-2026-000001", first);
        Assert.Equal(1L, sequence.CurrentValue);
    }

    [Fact]
    public void Allocate_IsMonotonic()
    {
        var sequence = SaleSequence();

        var first = sequence.Allocate(SaleDate);
        var second = sequence.Allocate(SaleDate);
        var third = sequence.Allocate(SaleDate);

        Assert.Equal("S-2026-000001", first);
        Assert.Equal("S-2026-000002", second);
        Assert.Equal("S-2026-000003", third);
        Assert.Equal(3L, sequence.CurrentValue);
    }

    [Fact]
    public void Allocate_RollsYearWithTheDate()
    {
        var sequence = SaleSequence();

        var late2025 = sequence.Allocate(new DateTime(2025, 12, 31, 23, 59, 0, DateTimeKind.Utc));
        var early2026 = sequence.Allocate(new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc));

        Assert.Equal("S-2025-000001", late2025);
        Assert.Equal("S-2026-000002", early2026);
    }

    [Fact]
    public void Render_ZeroPadsToThePlaceholderWidth()
    {
        var sequence = SaleSequence();
        var nine = NumberSequence.Create(TenantId, "Sale", "S", "{prefix}-{year}-{sequence:000000000}");

        Assert.Equal("S-2026-000123", sequence.Render(SaleDate, 123L));
        Assert.Equal("S-2026-000000123", nine.Render(SaleDate, 123L));
    }

    [Fact]
    public void Render_WithSingleDigitWidth_DoesNotPad()
    {
        var sequence = SaleSequence("{prefix}-{year}-{sequence:0}");

        Assert.Equal("S-2026-1", sequence.Render(SaleDate, 1L));
        Assert.Equal("S-2026-42", sequence.Render(SaleDate, 42L));
    }

    [Fact]
    public void Render_RejectsNonPositiveValue()
    {
        var sequence = SaleSequence();

        Assert.Throws<ArgumentOutOfRangeException>(() => sequence.Render(SaleDate, 0L));
    }

    [Fact]
    public void Create_RejectsMissingScopePrefixOrPattern()
    {
        Assert.Throws<ArgumentException>(() => NumberSequence.Create(TenantId, " ", "S", "{prefix}-{sequence:0}"));
        Assert.Throws<ArgumentException>(() => NumberSequence.Create(TenantId, "Sale", " ", "{prefix}-{sequence:0}"));
        Assert.Throws<ArgumentException>(() => NumberSequence.Create(TenantId, "Sale", "S", " "));
    }

    [Theory]
    [InlineData("S-2026-000123")]
    [InlineData("S-2026-{year}-000123")]
    [InlineData("S-2026-{sequence}")]
    [InlineData("S-2026-{sequence:-1}")]
    public void Create_RejectsPatternWithoutValidSequencePlaceholder(string pattern)
    {
        Assert.Throws<ArgumentException>(() => NumberSequence.Create(TenantId, "Sale", "S", pattern));
    }

    [Fact]
    public void Create_RejectsPatternWithTwoSequencePlaceholders()
    {
        Assert.Throws<ArgumentException>(() =>
            NumberSequence.Create(TenantId, "Sale", "S", "{prefix}-{sequence:00}-{sequence:00}"));
    }

    [Fact]
    public void Create_RejectsEmptyTenant()
    {
        Assert.Throws<ArgumentException>(() => NumberSequence.Create(Guid.Empty, "Sale", "S", "{sequence:0}"));
    }
}
