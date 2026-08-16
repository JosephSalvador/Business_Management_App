using BusinessOS.Domain.Catalog;
using BusinessOS.Domain.Events;

namespace BusinessOS.Tests.Unit.Catalog;

public sealed class ProductTests
{
    [Fact]
    public void Create_TrimsNameNormalizesIdentifiersAndDefaultsToDraft()
    {
        var product = Product.Create(
            Guid.NewGuid(),
            "  Coca Cola 500ml  ",
            "Cold drink",
            "  COKE-500  ",
            "  \t  ",
            categoryId: null,
            brandId: null,
            unitOfMeasureId: Guid.NewGuid(),
            ProductType.Product);

        Assert.Equal("Coca Cola 500ml", product.Name);
        Assert.Equal("COKE-500", product.Sku);
        Assert.Null(product.Barcode);
        Assert.Equal(ProductStatus.Draft, product.Status);
        Assert.False(product.HasVariants);
    }

    [Fact]
    public void Create_RaisesProductCreatedEvent()
    {
        var tenantId = Guid.NewGuid();
        var product = Product.Create(
            tenantId,
            "Service",
            null,
            sku: "SRV-1",
            barcode: null,
            categoryId: null,
            brandId: null,
            unitOfMeasureId: Guid.NewGuid(),
            ProductType.Service,
            ProductStatus.Active);

        var created = Assert.Single(product.DomainEvents.OfType<ProductCreatedEvent>());
        Assert.Equal(product.Id, created.ProductId);
        Assert.Equal(tenantId, created.TenantId);
        Assert.Equal("SRV-1", created.Sku);
    }

    [Fact]
    public void UpdateProfile_ChangesFieldsAndRaisesUpdatedEvent()
    {
        var product = MakeProduct();

        product.UpdateProfile(" New Name ", "New description", Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid());

        Assert.Equal("New Name", product.Name);
        Assert.Equal("New description", product.Description);
        Assert.Single(product.DomainEvents.OfType<ProductUpdatedEvent>());
    }

    [Fact]
    public void UpdateIdentifiers_NormalizesValues()
    {
        var product = MakeProduct();

        product.UpdateIdentifiers("  NEW-SKU  ", "  \t  ");

        Assert.Equal("NEW-SKU", product.Sku);
        Assert.Null(product.Barcode);
    }

    [Fact]
    public void UpdateIdentifiers_WithVariantsAndIdentifiers_Throws()
    {
        var product = MakeProduct();
        product.SetVariants(new[] { new ProductVariantSpec(Guid.Empty, "Small", "V-SMALL", null) });

        Assert.Throws<InvalidOperationException>(() => product.UpdateIdentifiers("SKU-1", null));
    }

    [Fact]
    public void SetStatus_ChangesStatusAndRaisesStatusChangedEvent()
    {
        var product = MakeProduct();

        product.SetStatus(ProductStatus.Active);
        product.SetStatus(ProductStatus.Active);

        var events = product.DomainEvents.OfType<ProductStatusChangedEvent>().ToList();
        var statusEvent = Assert.Single(events);
        Assert.Equal(ProductStatus.Active, statusEvent.Status);
    }

    [Fact]
    public void SetVariants_AddsVariantsAndRaisesVariantsChangedEvent()
    {
        var product = MakeProduct();

        product.SetVariants(new[]
        {
            new ProductVariantSpec(Guid.Empty, " Small ", "V-SMALL", null),
            new ProductVariantSpec(Guid.Empty, "Large", null, "BC-LARGE"),
        });

        Assert.True(product.HasVariants);
        Assert.Equal(2, product.Variants.Count);
        Assert.Equal("Small", product.Variants.First(v => v.Sku == "V-SMALL").Name);

        var changed = Assert.Single(product.DomainEvents.OfType<ProductVariantsChangedEvent>());
        Assert.Equal(2, changed.VariantIds.Length);
        Assert.True(changed.HasVariants);
    }

    [Fact]
    public void SetVariants_DuplicateNames_Throws()
    {
        var product = MakeProduct();

        Assert.Throws<ArgumentException>(() => product.SetVariants(new[]
        {
            new ProductVariantSpec(Guid.Empty, "Small", null, null),
            new ProductVariantSpec(Guid.Empty, " Small ", null, null),
        }));
    }

    [Fact]
    public void SetVariants_WithProductLevelSku_Throws()
    {
        var product = Product.Create(
            Guid.NewGuid(),
            "Product",
            null,
            sku: "SKU-1",
            barcode: null,
            categoryId: null,
            brandId: null,
            unitOfMeasureId: Guid.NewGuid(),
            ProductType.Product);

        Assert.Throws<InvalidOperationException>(() =>
            product.SetVariants(new[] { new ProductVariantSpec(Guid.Empty, "Small", null, null) }));
    }

    [Fact]
    public void SetVariants_UnchangedPayload_RaisesNoEvent()
    {
        var product = MakeProduct();
        product.SetVariants(new[] { new ProductVariantSpec(Guid.Empty, "Small", "V-SMALL", null) });

        var eventsBefore = product.DomainEvents.Count;
        product.SetVariants(new[] { new ProductVariantSpec(Guid.Empty, "Small", "V-SMALL", null) });

        Assert.Equal(eventsBefore, product.DomainEvents.Count);
    }

    [Fact]
    public void SetVariants_RenamesExistingVariantByName_ReusesSameInstance()
    {
        var product = MakeProduct();
        product.SetVariants(new[]
        {
            new ProductVariantSpec(Guid.Empty, "Small", "V-SMALL", null),
            new ProductVariantSpec(Guid.Empty, "Large", "V-LARGE", null),
        });
        var original = product.Variants.First(v => v.Name == "Small");

        product.SetVariants(new[]
        {
            new ProductVariantSpec(Guid.Empty, "Small", "V-SMALL-X", null),
        });

        var variant = Assert.Single(product.Variants);
        Assert.Same(original, variant);
        Assert.Equal("Small", variant.Name);
        Assert.Equal("V-SMALL-X", variant.Sku);
    }

    [Fact]
    public void Create_WithTaxCategoryId_StoresIt()
    {
        var taxCategoryId = Guid.NewGuid();

        var product = Product.Create(
            Guid.NewGuid(),
            "Standard VAT Item",
            null,
            sku: null,
            barcode: null,
            categoryId: null,
            brandId: null,
            unitOfMeasureId: Guid.NewGuid(),
            ProductType.Product,
            taxCategoryId: taxCategoryId);

        Assert.Equal(taxCategoryId, product.TaxCategoryId);
    }

    [Fact]
    public void Create_WithoutTaxCategoryId_IsNull()
    {
        var product = MakeProduct();

        Assert.Null(product.TaxCategoryId);
    }

    [Fact]
    public void UpdateProfile_ChangesTaxCategoryId()
    {
        var product = MakeProduct();
        var taxCategoryId = Guid.NewGuid();

        product.UpdateProfile("New Name", null, null, null, Guid.NewGuid(), taxCategoryId);

        Assert.Equal(taxCategoryId, product.TaxCategoryId);
    }

    private static Product MakeProduct() => Product.Create(
        Guid.NewGuid(),
        "Test Product",
        null,
        sku: null,
        barcode: null,
        categoryId: null,
        brandId: null,
        unitOfMeasureId: Guid.NewGuid(),
        ProductType.Product);
}
