using BusinessOS.Application.Features.Catalog;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;

namespace BusinessOS.Tests.Unit.Catalog;

public sealed class CategoryCycleTests
{
    private sealed class StubTenantContext : ITenantContext
    {
        public Guid TenantId { get; init; }
        public Guid? UserId { get; init; }
        public string? IpAddress => null;
        public string? UserAgent => null;
        public string? CurrentRefreshToken => null;
    }

    private sealed class StubCategoryRepository : ICategoryRepository
    {
        private readonly Dictionary<Guid, ProductCategory> _categories = new();

        public void Seed(params ProductCategory[] categories)
        {
            foreach (var category in categories)
            {
                _categories[category.Id] = category;
            }
        }

        public Task<ProductCategory?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
            => Task.FromResult(_categories.TryGetValue(id, out var category) ? category : null);

        public Task<ProductCategory?> GetByNameAsync(Guid tenantId, string name, CancellationToken ct = default)
            => Task.FromResult(_categories.Values.FirstOrDefault(c => c.Name == name));

        public Task<IReadOnlyList<ProductCategory>> ListAsync(Guid tenantId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<ProductCategory>>(_categories.Values.ToArray());

        public Task AddAsync(ProductCategory category, CancellationToken ct = default)
        {
            _categories[category.Id] = category;
            return Task.CompletedTask;
        }

        public Task RemoveAsync(ProductCategory category, CancellationToken ct = default)
        {
            _categories.Remove(category.Id);
            return Task.CompletedTask;
        }
    }

    [Fact]
    public async Task CreateCategory_DuplicateName_ReturnsConflict()
    {
        var tenantId = Guid.NewGuid();
        var repo = new StubCategoryRepository();
        repo.Seed(ProductCategory.Create(tenantId, "Drinks"));
        var handler = new CreateCategoryCommandHandler(new StubTenantContext { TenantId = tenantId }, repo);

        var result = await handler.Handle(new CreateCategoryCommand("Drinks", null), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Conflict", result.Error.Code);
    }

    [Fact]
    public async Task CreateCategory_MissingParent_ReturnsValidation()
    {
        var tenantId = Guid.NewGuid();
        var handler = new CreateCategoryCommandHandler(
            new StubTenantContext { TenantId = tenantId }, new StubCategoryRepository());

        var result = await handler.Handle(new CreateCategoryCommand("Drinks", Guid.NewGuid()), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task CreateCategory_Success()
    {
        var tenantId = Guid.NewGuid();
        var handler = new CreateCategoryCommandHandler(
            new StubTenantContext { TenantId = tenantId }, new StubCategoryRepository());

        var result = await handler.Handle(new CreateCategoryCommand("Drinks", null), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("Drinks", result.Value.Name);
    }

    [Fact]
    public async Task UpdateCategory_SelfParent_ReturnsValidation()
    {
        var tenantId = Guid.NewGuid();
        var category = ProductCategory.Create(tenantId, "Drinks");
        var repo = new StubCategoryRepository();
        repo.Seed(category);
        var handler = new UpdateCategoryCommandHandler(new StubTenantContext { TenantId = tenantId }, repo);

        var result = await handler.Handle(
            new UpdateCategoryCommand(category.Id, "Drinks", category.Id), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task UpdateCategory_MissingParent_ReturnsValidation()
    {
        var tenantId = Guid.NewGuid();
        var category = ProductCategory.Create(tenantId, "Drinks");
        var repo = new StubCategoryRepository();
        repo.Seed(category);
        var handler = new UpdateCategoryCommandHandler(new StubTenantContext { TenantId = tenantId }, repo);

        var result = await handler.Handle(
            new UpdateCategoryCommand(category.Id, "Drinks", Guid.NewGuid()), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task UpdateCategory_AncestorCycle_ReturnsValidation()
    {
        var tenantId = Guid.NewGuid();
        var drinks = ProductCategory.Create(tenantId, "Drinks");
        var soda = ProductCategory.Create(tenantId, "Soda", drinks.Id);
        var repo = new StubCategoryRepository();
        repo.Seed(drinks, soda);
        var handler = new UpdateCategoryCommandHandler(new StubTenantContext { TenantId = tenantId }, repo);

        var result = await handler.Handle(
            new UpdateCategoryCommand(drinks.Id, "Drinks", soda.Id), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task UpdateCategory_DeepCycle_ReturnsValidation()
    {
        var tenantId = Guid.NewGuid();
        var a = ProductCategory.Create(tenantId, "A");
        var b = ProductCategory.Create(tenantId, "B", a.Id);
        var c = ProductCategory.Create(tenantId, "C", b.Id);
        var repo = new StubCategoryRepository();
        repo.Seed(a, b, c);
        var handler = new UpdateCategoryCommandHandler(new StubTenantContext { TenantId = tenantId }, repo);

        var result = await handler.Handle(
            new UpdateCategoryCommand(a.Id, "A", c.Id), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("Validation", result.Error.Code);
    }

    [Fact]
    public async Task UpdateCategory_ValidReparent_Succeeds()
    {
        var tenantId = Guid.NewGuid();
        var a = ProductCategory.Create(tenantId, "A");
        var b = ProductCategory.Create(tenantId, "B", a.Id);
        var c = ProductCategory.Create(tenantId, "C", a.Id);
        var repo = new StubCategoryRepository();
        repo.Seed(a, b, c);
        var handler = new UpdateCategoryCommandHandler(new StubTenantContext { TenantId = tenantId }, repo);

        var result = await handler.Handle(
            new UpdateCategoryCommand(b.Id, "B", c.Id), CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(c.Id, result.Value.ParentId);
    }
}
