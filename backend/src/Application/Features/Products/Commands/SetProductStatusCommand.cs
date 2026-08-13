using BusinessOS.Application.Features.Products.Dtos;
using BusinessOS.Application.Features.Products.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Products.Commands;

public sealed record SetProductStatusCommand(Guid Id, ProductStatus Status)
    : IRequest<Result<ProductDto>>, IRequiresTenantAdvisoryLock;

public sealed class SetProductStatusCommandHandler : IRequestHandler<SetProductStatusCommand, Result<ProductDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IProductRepository _products;

    public SetProductStatusCommandHandler(ITenantContext tenantContext, IProductRepository products)
    {
        _tenantContext = tenantContext;
        _products = products;
    }

    public async Task<Result<ProductDto>> Handle(
        SetProductStatusCommand command, CancellationToken cancellationToken)
    {
        var product = await _products.GetByIdAsync(_tenantContext.TenantId, command.Id, cancellationToken);
        if (product is null)
        {
            return Error.NotFound("Product not found.");
        }

        product.SetStatus(command.Status);
        return Result.Success(ProductMappers.ToDto(product));
    }
}
