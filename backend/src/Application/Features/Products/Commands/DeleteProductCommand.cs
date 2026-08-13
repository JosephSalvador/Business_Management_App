using BusinessOS.Application.Features.Products.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Products.Commands;

public sealed record DeleteProductCommand(Guid Id)
    : IRequest<Result>, IRequiresTenantAdvisoryLock;

public sealed class DeleteProductCommandHandler : IRequestHandler<DeleteProductCommand, Result>
{
    private readonly ITenantContext _tenantContext;
    private readonly IProductRepository _products;

    public DeleteProductCommandHandler(ITenantContext tenantContext, IProductRepository products)
    {
        _tenantContext = tenantContext;
        _products = products;
    }

    public async Task<Result> Handle(DeleteProductCommand command, CancellationToken cancellationToken)
    {
        var product = await _products.GetByIdAsync(_tenantContext.TenantId, command.Id, cancellationToken);
        if (product is null)
        {
            return Result.Failure(Error.NotFound("Product not found."));
        }

        product.SetStatus(ProductStatus.Inactive);
        return Result.Success();
    }
}
