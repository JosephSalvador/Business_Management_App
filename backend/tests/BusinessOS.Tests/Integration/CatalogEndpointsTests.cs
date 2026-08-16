using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BusinessOS.Domain.Identity;
using BusinessOS.Infrastructure.Persistence;
using BusinessOS.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BusinessOS.Tests.Integration;

public sealed class CatalogEndpointsTests : IClassFixture<BusinessOsApiFactory>, IAsyncLifetime
{
    private readonly BusinessOsApiFactory _factory;
    private readonly HttpClient _client;

    public CatalogEndpointsTests(BusinessOsApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public Task DisposeAsync()
    {
        _client.Dispose();
        return Task.CompletedTask;
    }

    private static JsonElement Body(string json) => JsonSerializer.Deserialize<JsonElement>(json);

    private static string GetProperty(JsonElement doc, params string[] path)
    {
        JsonElement current = doc;
        foreach (var part in path)
        {
            current = current.GetProperty(part);
        }
        return current.ToString();
    }

    private async Task<(string AccessToken, string TenantId)> RegisterAsync(string label)
    {
        var email = $"{label}-{Guid.NewGuid():N}@test.local";
        var response = await _client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email,
            password = "Passw0rd!",
            fullName = $"{label} Owner",
            organizationName = $"{label} Org {Guid.NewGuid():N}",
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var doc = Body(await response.Content.ReadAsStringAsync());
        return (GetProperty(doc, "accessToken"), GetProperty(doc, "user", "tenantId"));
    }

    private async Task<string> RegisterLimitedViewerAsync(string email, Guid tenantId)
    {
        using var db = CreateDbContext();
        var viewPermissions = await db.Permissions
            .Where(p => new[] { PermissionNames.ProductsView, PermissionNames.CategoriesView }.Contains(p.Name))
            .ToListAsync();
        var role = Role.Create(tenantId, "Catalog Viewer");
        role.Grant(viewPermissions);
        await db.Roles.AddAsync(role);

        var hash = await db.Users
            .Where(u => u.TenantId == tenantId)
            .Select(u => u.PasswordHash)
            .FirstAsync();
        var user = User.Create(Guid.NewGuid(), tenantId, email, hash, "Catalog Viewer", phone: null);
        user.AssignRole(role);
        await db.Users.AddAsync(user);
        await db.SaveChangesAsync();

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { email, password = "Passw0rd!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return GetProperty(Body(await login.Content.ReadAsStringAsync()), "accessToken");
    }

    private void Authorize(string token) => _client.DefaultRequestHeaders.Authorization = new("Bearer", token);

    private async Task<string> CreateUnitAsync(string token, string name)
    {
        Authorize(token);
        var response = await _client.PostAsJsonAsync("/api/v1/units", new { name, abbreviation = name.Substring(0, 3) });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return GetProperty(Body(await response.Content.ReadAsStringAsync()), "id");
    }

    [Fact]
    public async Task ReferenceDataCrud_AndDuplicateConflict()
    {
        var (token, _) = await RegisterAsync("refdata");
        Authorize(token);

        var category = await _client.PostAsJsonAsync("/api/v1/categories", new { name = "Drinks" });
        Assert.Equal(HttpStatusCode.OK, category.StatusCode);
        var categoryId = GetProperty(Body(await category.Content.ReadAsStringAsync()), "id");

        var duplicateCategory = await _client.PostAsJsonAsync("/api/v1/categories", new { name = "Drinks" });
        Assert.Equal(HttpStatusCode.Conflict, duplicateCategory.StatusCode);

        var nested = await _client.PostAsJsonAsync("/api/v1/categories", new { name = "Soda", parentId = categoryId });
        Assert.Equal(HttpStatusCode.OK, nested.StatusCode);

        var brand = await _client.PostAsJsonAsync("/api/v1/brands", new { name = "Coca-Cola" });
        Assert.Equal(HttpStatusCode.OK, brand.StatusCode);
        var brandId = GetProperty(Body(await brand.Content.ReadAsStringAsync()), "id");

        var unitId = await CreateUnitAsync(token, "Pieces");

        var listedCategories = await _client.GetAsync("/api/v1/categories");
        Assert.Equal(HttpStatusCode.OK, listedCategories.StatusCode);
        Assert.True(Body(await listedCategories.Content.ReadAsStringAsync()).GetArrayLength() >= 2);

        var updatedCategory = await _client.PutAsJsonAsync($"/api/v1/categories/{categoryId}", new
        {
            name = "Beverages",
            parentId = (string?)null,
        });
        Assert.Equal(HttpStatusCode.OK, updatedCategory.StatusCode);
        Assert.Equal("Beverages", GetProperty(Body(await updatedCategory.Content.ReadAsStringAsync()), "name"));

        var updatedUnit = await _client.PutAsJsonAsync($"/api/v1/units/{unitId}", new
        {
            name = "Piece",
            abbreviation = "pc",
        });
        Assert.Equal(HttpStatusCode.OK, updatedUnit.StatusCode);
        Assert.Equal("pc", GetProperty(Body(await updatedUnit.Content.ReadAsStringAsync()), "abbreviation"));

        var updatedBrand = await _client.PutAsJsonAsync($"/api/v1/brands/{brandId}", new { name = "Coca-Cola Company" });
        Assert.Equal(HttpStatusCode.OK, updatedBrand.StatusCode);
    }

    [Fact]
    public async Task CategoryCycle_SelfParentAndAncestorCycle_ReturnValidation()
    {
        var (token, _) = await RegisterAsync("catcycle");
        Authorize(token);

        var a = await _client.PostAsJsonAsync("/api/v1/categories", new { name = $"A-{Guid.NewGuid():N}" });
        var aId = GetProperty(Body(await a.Content.ReadAsStringAsync()), "id");
        var b = await _client.PostAsJsonAsync("/api/v1/categories", new { name = $"B-{Guid.NewGuid():N}", parentId = aId });
        var bId = GetProperty(Body(await b.Content.ReadAsStringAsync()), "id");

        var selfParent = await _client.PutAsJsonAsync($"/api/v1/categories/{aId}", new { name = $"A-{Guid.NewGuid():N}", parentId = aId });
        Assert.Equal(HttpStatusCode.BadRequest, selfParent.StatusCode);

        var cycle = await _client.PutAsJsonAsync($"/api/v1/categories/{aId}", new { name = $"A-{Guid.NewGuid():N}", parentId = bId });
        Assert.Equal(HttpStatusCode.BadRequest, cycle.StatusCode);
    }

    [Fact]
    public async Task ProductCrud_DuplicateSkuConflict_StatusAndDelete()
    {
        var (token, _) = await RegisterAsync("productcrud");
        var unitId = await CreateUnitAsync(token, "Bottles");

        Authorize(token);
        var sku = $"SKU-{Guid.NewGuid():N}";
        var created = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Coca Cola 500ml",
            sku,
            unitOfMeasureId = unitId,
            productType = 0,
            status = 1,
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var createdDoc = Body(await created.Content.ReadAsStringAsync());
        Assert.Equal("Coca Cola 500ml", GetProperty(createdDoc, "name"));
        Assert.Equal(sku, GetProperty(createdDoc, "sku"));
        Assert.Equal("1", GetProperty(createdDoc, "status"));
        var productId = GetProperty(createdDoc, "id");

        var duplicate = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Other",
            sku,
            unitOfMeasureId = unitId,
            productType = 0,
        });
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);

        var missingUnit = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Invalid",
            unitOfMeasureId = Guid.NewGuid(),
            productType = 0,
        });
        Assert.Equal(HttpStatusCode.BadRequest, missingUnit.StatusCode);

        var fetched = await _client.GetAsync($"/api/v1/products/{productId}");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);

        var updated = await _client.PutAsJsonAsync($"/api/v1/products/{productId}", new
        {
            name = "Coca Cola 600ml",
            description = "Family pack",
            sku,
            unitOfMeasureId = unitId,
            productType = 0,
        });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        Assert.Equal("Coca Cola 600ml", GetProperty(Body(await updated.Content.ReadAsStringAsync()), "name"));

        var deactivated = await _client.PatchAsJsonAsync($"/api/v1/products/{productId}/status", new { status = 2 });
        Assert.Equal(HttpStatusCode.OK, deactivated.StatusCode);
        Assert.Equal("2", GetProperty(Body(await deactivated.Content.ReadAsStringAsync()), "status"));

        var deleted = await _client.DeleteAsync($"/api/v1/products/{productId}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        var afterDelete = await _client.GetAsync($"/api/v1/products/{productId}");
        Assert.Equal(HttpStatusCode.OK, afterDelete.StatusCode);
        Assert.Equal("2", GetProperty(Body(await afterDelete.Content.ReadAsStringAsync()), "status"));

        var listed = await _client.GetAsync($"/api/v1/products?page=1&pageSize=10&search={sku}");
        Assert.Equal(HttpStatusCode.OK, listed.StatusCode);
        var listedBody = await listed.Content.ReadAsStringAsync();
        var listDoc = Body(listedBody);
        Assert.Equal("1", GetProperty(listDoc, "page"));
        Assert.True(listDoc.GetProperty("total").GetInt32() >= 1, $"list body: {listedBody}");
    }

    [Fact]
    public async Task Product_TaxCategoryAssignmentAndValidation()
    {
        var (token, _) = await RegisterAsync("taxcat");
        var unitId = await CreateUnitAsync(token, "Bottles");

        Guid standardCategoryId;
        using (var db = CreateDbContext())
        {
            var standard = await db.TaxCategories.FirstAsync(c => c.Code == "VAT_STANDARD");
            standardCategoryId = standard.Id;
        }

        Authorize(token);
        var created = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Taxed Soda",
            unitOfMeasureId = unitId,
            productType = 0,
            taxCategoryId = standardCategoryId,
        });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        Assert.Equal(
            standardCategoryId.ToString(),
            GetProperty(Body(await created.Content.ReadAsStringAsync()), "taxCategoryId"));

        var invalid = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Bad Tax",
            unitOfMeasureId = unitId,
            productType = 0,
            taxCategoryId = Guid.NewGuid(),
        });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
    }

    [Fact]
    public async Task ProductVariants_RoundTripAndValidation()
    {
        var (token, _) = await RegisterAsync("variants");
        var unitId = await CreateUnitAsync(token, "Bottles");

        Authorize(token);
        var created = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Soda Pack",
            unitOfMeasureId = unitId,
            productType = 0,
        });
        var productId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var setVariants = await _client.PutAsJsonAsync($"/api/v1/products/{productId}/variants", new
        {
            variants = new[]
            {
                new { id = (string?)null, name = "Small", sku = (string?)$"VS-{Guid.NewGuid():N}", barcode = (string?)null },
                new { id = (string?)null, name = "Large", sku = (string?)null, barcode = (string?)$"BC-{Guid.NewGuid():N}" },
            },
        });
        Assert.Equal(HttpStatusCode.OK, setVariants.StatusCode);
        var variantsDoc = Body(await setVariants.Content.ReadAsStringAsync());
        Assert.Equal(2, variantsDoc.GetArrayLength());

        var fetched = await _client.GetAsync($"/api/v1/products/{productId}/variants");
        Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
        Assert.Equal(2, Body(await fetched.Content.ReadAsStringAsync()).GetArrayLength());

        var large = variantsDoc.EnumerateArray().Single(v => GetProperty(v, "name") == "Large");
        var largeId = large.GetProperty("id").ToString();
        var replaced = await _client.PutAsJsonAsync($"/api/v1/products/{productId}/variants", new
        {
            variants = new[]
            {
                new { id = largeId, name = "Large Bottle", sku = (string?)null },
            },
        });
        Assert.Equal(HttpStatusCode.OK, replaced.StatusCode);
        var replacedDoc = Body(await replaced.Content.ReadAsStringAsync());
        Assert.Equal(1, replacedDoc.GetArrayLength());
        Assert.Equal(largeId, replacedDoc[0].GetProperty("id").ToString());
        Assert.Equal("Large Bottle", replacedDoc[0].GetProperty("name").ToString());

        var skuProduct = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "SKU Product",
            sku = $"SKU-{Guid.NewGuid():N}",
            unitOfMeasureId = unitId,
            productType = 0,
        });
        var skuProductId = GetProperty(Body(await skuProduct.Content.ReadAsStringAsync()), "id");

        var variantsOnSkuProduct = await _client.PutAsJsonAsync($"/api/v1/products/{skuProductId}/variants", new
        {
            variants = new[] { new { id = (string?)null, name = "Small", sku = (string?)null } },
        });
        Assert.Equal(HttpStatusCode.BadRequest, variantsOnSkuProduct.StatusCode);
    }

    [Fact]
    public async Task CrossTableSkuUniqueness_ProductAndVariantCannotShareIdentifier()
    {
        var (token, _) = await RegisterAsync("crosstable");
        var unitId = await CreateUnitAsync(token, "Bottles");

        Authorize(token);
        var productSku = $"SKU-{Guid.NewGuid():N}";
        var productWithSku = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "With SKU",
            sku = productSku,
            unitOfMeasureId = unitId,
            productType = 0,
        });
        Assert.Equal(HttpStatusCode.OK, productWithSku.StatusCode);

        var productB = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Variant carrier",
            unitOfMeasureId = unitId,
            productType = 0,
        });
        var productBId = GetProperty(Body(await productB.Content.ReadAsStringAsync()), "id");

        var variantCollidesWithProduct = await _client.PutAsJsonAsync($"/api/v1/products/{productBId}/variants", new
        {
            variants = new[] { new { id = (string?)null, name = "Small", sku = productSku, barcode = (string?)null } },
        });
        Assert.Equal(HttpStatusCode.Conflict, variantCollidesWithProduct.StatusCode);

        var variantSku = $"VSKU-{Guid.NewGuid():N}";
        var setVariants = await _client.PutAsJsonAsync($"/api/v1/products/{productBId}/variants", new
        {
            variants = new[] { new { id = (string?)null, name = "Small", sku = variantSku, barcode = (string?)null } },
        });
        Assert.Equal(HttpStatusCode.OK, setVariants.StatusCode);

        var productCollidesWithVariant = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Tries variant sku",
            sku = variantSku,
            unitOfMeasureId = unitId,
            productType = 0,
        });
        Assert.Equal(HttpStatusCode.Conflict, productCollidesWithVariant.StatusCode);
    }

    [Fact]
    public async Task LimitedViewer_CanReadButCannotCreateProducts()
    {
        var (_, tenantId) = await RegisterAsync("catalogviewer");
        var viewerToken = await RegisterLimitedViewerAsync($"catalog-{Guid.NewGuid():N}@test.local", Guid.Parse(tenantId));

        Authorize(viewerToken);
        var read = await _client.GetAsync("/api/v1/products?page=1&pageSize=10");
        Assert.Equal(HttpStatusCode.OK, read.StatusCode);

        var create = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Blocked",
            unitOfMeasureId = Guid.NewGuid(),
            productType = 0,
        });
        Assert.Equal(HttpStatusCode.Forbidden, create.StatusCode);

        var createCategory = await _client.PostAsJsonAsync("/api/v1/categories", new { name = "Blocked" });
        Assert.Equal(HttpStatusCode.Forbidden, createCategory.StatusCode);
    }

    [Fact]
    public async Task TenantIsolation_OtherTenantCannotReadOrUpdateProduct()
    {
        var (tokenA, _) = await RegisterAsync("tenantA");
        var unitId = await CreateUnitAsync(tokenA, "Bottles");
        Authorize(tokenA);
        var created = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Secret Product",
            sku = $"SKU-{Guid.NewGuid():N}",
            unitOfMeasureId = unitId,
            productType = 0,
        });
        var productId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");

        var (tokenB, _) = await RegisterAsync("tenantB");
        var unitBId = await CreateUnitAsync(tokenB, "Bottles");
        Authorize(tokenB);

        var read = await _client.GetAsync($"/api/v1/products/{productId}");
        Assert.Equal(HttpStatusCode.NotFound, read.StatusCode);

        var update = await _client.PutAsJsonAsync($"/api/v1/products/{productId}", new
        {
            name = "Hijacked",
            unitOfMeasureId = unitBId,
            productType = 0,
        });
        Assert.Equal(HttpStatusCode.NotFound, update.StatusCode);

        var variants = await _client.PutAsJsonAsync($"/api/v1/products/{productId}/variants", new
        {
            variants = new[] { new { id = (string?)null, name = "Small" } },
        });
        Assert.Equal(HttpStatusCode.NotFound, variants.StatusCode);
    }

    [Fact]
    public async Task ProductMutations_WriteAuditRows()
    {
        var (token, _) = await RegisterAsync("catalogaudit");
        var unitId = await CreateUnitAsync(token, "Bottles");

        Authorize(token);
        var created = await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Audited Product",
            sku = $"SKU-{Guid.NewGuid():N}",
            unitOfMeasureId = unitId,
            productType = 0,
        });
        var productId = GetProperty(Body(await created.Content.ReadAsStringAsync()), "id");
        await _client.PutAsJsonAsync($"/api/v1/products/{productId}", new
        {
            name = "Audited Product 2",
            unitOfMeasureId = unitId,
            productType = 0,
        });
        await _client.PutAsJsonAsync($"/api/v1/products/{productId}/variants", new
        {
            variants = new[] { new { id = (string?)null, name = "Small" } },
        });
        await _client.PostAsJsonAsync("/api/v1/categories", new { name = $"Audited-{Guid.NewGuid():N}" });

        using var db = CreateDbContext();
        foreach (var action in new[] { "CreateProductCommand", "UpdateProductCommand", "SetProductVariantsCommand", "CreateCategoryCommand" })
        {
            Assert.NotNull(await db.AuditLogs.FirstOrDefaultAsync(l => l.Action == action));
        }
    }

    [Fact]
    public async Task ProductCreation_PersistsOutboxEventAndDispatchesIt()
    {
        var (token, _) = await RegisterAsync("catalogoutbox");
        var unitId = await CreateUnitAsync(token, "Bottles");

        Authorize(token);
        await _client.PostAsJsonAsync("/api/v1/products", new
        {
            name = "Outbox Product",
            sku = $"SKU-{Guid.NewGuid():N}",
            unitOfMeasureId = unitId,
            productType = 0,
        });

        using var db = CreateDbContext();
        var outbox = await db.OutboxMessages
            .Where(o => o.Type == "BusinessOS.Domain.Events.ProductCreatedEvent")
            .OrderByDescending(o => o.OccurredAt)
            .FirstOrDefaultAsync();
        Assert.NotNull(outbox);
        Assert.NotNull(outbox.ProcessedAt);
    }

    private BusinessDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<BusinessDbContext>()
            .UseNpgsql(BusinessOsApiFactory.TestConnectionString)
            .Options;
        return new BusinessDbContext(options);
    }
}
