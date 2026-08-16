using BusinessOS.Application.Features.Common;
using BusinessOS.Application.Features.Sales;
using BusinessOS.Application.Features.Sales.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Sales;
using BusinessOS.Shared;

namespace BusinessOS.Tests.Unit.Sales;

public sealed class SalesQueriesTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");
    private static readonly Guid CashierId = new("22222222-2222-2222-2222-222222222222");
    private static readonly DateTime EffectiveAt = new(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc);

    private static Sale BuildSale(string number)
    {
        var line = SaleLine.Create(
            Guid.NewGuid(), null, "Coca Cola 500ml", "SKU-1", null,
            Guid.NewGuid(), "Piece", 1m, 100m, 0m,
            "A", 0.18m, Guid.NewGuid(), 84.75m, 15.25m, 100m, 0);
        var payment = SalePayment.Create(PaymentMethod.Cash, 100m, null, null, null, 0);

        return Sale.Create(
            TenantId, Guid.NewGuid(), Guid.NewGuid(), CashierId, Guid.NewGuid(),
            number, SaleSource.Online, EffectiveAt, EffectiveAt,
            "TZS", Guid.NewGuid(), isPriceTaxInclusive: true, isElectronicPayment: false,
            customerId: null, customerName: "John Doe", customerTin: "123-456-789", isVatRegistered: true,
            subtotal: 100m, discountAmount: 0m, taxAmount: 15.25m, totalAmount: 100m,
            amountPaid: 100m, change: 0m, [line], [payment]);
    }

    [Fact]
    public async Task GetSale_ReturnsMappedDto()
    {
        var sale = BuildSale("S-2026-000001");
        var handler = new GetSaleQueryHandler(
            new StubTenantContext { TenantId = TenantId }, new StubSaleRepository(sale));

        var result = await handler.Handle(new GetSaleQuery(sale.Id), CancellationToken.None);

        Assert.True(result.IsSuccess);
        var dto = result.Value;
        Assert.Equal(sale.Id, dto.Id);
        Assert.Equal("S-2026-000001", dto.Number);
        Assert.Equal(100m, dto.TotalAmount);
        Assert.Equal(15.25m, dto.TaxAmount);
        Assert.Equal(PaymentMethod.Cash, dto.Payments[0].Method);
        Assert.NotNull(dto.Customer);
        Assert.Equal("John Doe", dto.Customer!.Name);
        Assert.Equal("123-456-789", dto.Customer.Tin);
        Assert.True(dto.Customer.IsVatRegistered);
        Assert.Single(dto.Lines);
        Assert.Equal("Coca Cola 500ml", dto.Lines[0].ProductName);
    }

    [Fact]
    public async Task GetSale_ReturnsNullsForMissingCustomer()
    {
        var sale = BuildSale("S-2026-000001");
        var customerless = Sale.Create(
            sale.TenantId, sale.BranchId, sale.WarehouseId, sale.CashierId, sale.ClientSaleId,
            sale.Number, sale.Source, sale.SaleDate, sale.EffectiveAt,
            sale.Currency, sale.PriceListId, sale.IsPriceTaxInclusive, sale.IsElectronicPayment,
            customerId: null, customerName: null, customerTin: null, isVatRegistered: null,
            sale.Subtotal, sale.DiscountAmount, sale.TaxAmount, sale.TotalAmount,
            sale.AmountPaid, sale.Change, sale.Lines, sale.Payments);
        var handler = new GetSaleQueryHandler(
            new StubTenantContext { TenantId = TenantId }, new StubSaleRepository(customerless));

        var result = await handler.Handle(new GetSaleQuery(customerless.Id), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Null(result.Value.Customer);
    }

    [Fact]
    public async Task GetSale_NotFound_ReturnsNotFound()
    {
        var handler = new GetSaleQueryHandler(
            new StubTenantContext { TenantId = TenantId }, new StubSaleRepository());

        var result = await handler.Handle(new GetSaleQuery(Guid.NewGuid()), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("NotFound", result.Error.Code);
        Assert.Contains("Sale not found", result.Error.Message);
    }

    [Fact]
    public async Task GetSale_IsTenantScoped()
    {
        var sale = BuildSale("S-2026-000001");
        var handler = new GetSaleQueryHandler(
            new StubTenantContext { TenantId = Guid.NewGuid() }, new StubSaleRepository(sale));

        var result = await handler.Handle(new GetSaleQuery(sale.Id), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("NotFound", result.Error.Code);
    }

    [Fact]
    public async Task ListSales_ReturnsPagedMappedResults()
    {
        var first = BuildSale("S-2026-000001");
        var second = BuildSale("S-2026-000002");
        var repository = new StubSaleRepository(first, second);
        var handler = new ListSalesQueryHandler(
            new StubTenantContext { TenantId = TenantId }, repository);

        var result = await handler.Handle(
            new ListSalesQuery(Page: 1, PageSize: 10, null, null, null, null, null),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var paged = result.Value;
        Assert.Equal(2, paged.Items.Count);
        Assert.Equal(2, paged.Total);
        Assert.Equal(1, paged.Page);
        Assert.Equal(10, paged.PageSize);
        Assert.Equal("S-2026-000001", paged.Items[0].Number);
        Assert.Equal("S-2026-000002", paged.Items[1].Number);
        Assert.Single(paged.Items[0].Lines);
        Assert.Single(paged.Items[0].Payments);
    }

    [Fact]
    public async Task ListSales_ForwardsFilterToRepository()
    {
        var repository = new StubSaleRepository(BuildSale("S-2026-000001"));
        var handler = new ListSalesQueryHandler(
            new StubTenantContext { TenantId = TenantId }, repository);
        var branchId = Guid.NewGuid();
        var from = new DateTime(2026, 8, 1, 0, 0, 0, DateTimeKind.Utc);
        var to = new DateTime(2026, 8, 31, 23, 59, 59, DateTimeKind.Utc);

        var result = await handler.Handle(
            new ListSalesQuery(Page: 2, PageSize: 25, branchId, from, to, SaleStatus.Completed, "coca"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(branchId, repository.LastFilter!.BranchId);
        Assert.Equal(from, repository.LastFilter.FromDate);
        Assert.Equal(to, repository.LastFilter.ToDate);
        Assert.Equal(SaleStatus.Completed, repository.LastFilter.Status);
        Assert.Equal("coca", repository.LastFilter.Search);
        Assert.Equal(2, result.Value.Page);
        Assert.Equal(25, result.Value.PageSize);
    }

    private sealed class StubTenantContext : ITenantContext
    {
        public Guid TenantId { get; init; }
        public Guid? UserId => null;
        public string? IpAddress => null;
    }

    private sealed class StubSaleRepository : ISaleRepository
    {
        private readonly List<Sale> _sales = [];

        public StubSaleRepository(params Sale[] sales) => _sales.AddRange(sales);

        public SaleListFilter? LastFilter { get; private set; }
        public (int Page, int PageSize)? LastPage { get; private set; }

        public Task AddAsync(Sale sale, CancellationToken cancellationToken = default)
        {
            _sales.Add(sale);
            return Task.CompletedTask;
        }

        public Task<Sale?> GetByIdAsync(
            Guid tenantId, Guid id, CancellationToken cancellationToken = default)
            => Task.FromResult(_sales.FirstOrDefault(s => s.TenantId == tenantId && s.Id == id));

        public Task<Sale?> GetByClientSaleIdAsync(
            Guid tenantId, Guid clientSaleId, CancellationToken cancellationToken = default)
            => Task.FromResult(_sales.FirstOrDefault(s => s.TenantId == tenantId && s.ClientSaleId == clientSaleId));

        public Task<IReadOnlyList<Sale>> ListAsync(
            Guid tenantId, int page, int pageSize, SaleListFilter filter, CancellationToken cancellationToken = default)
        {
            LastFilter = filter;
            LastPage = (page, pageSize);
            IReadOnlyList<Sale> items = _sales.Where(s => s.TenantId == tenantId).ToArray();
            return Task.FromResult(items);
        }

        public Task<int> CountAsync(Guid tenantId, SaleListFilter filter, CancellationToken cancellationToken = default)
        {
            LastFilter = filter;
            return Task.FromResult(_sales.Count(s => s.TenantId == tenantId));
        }
    }
}
