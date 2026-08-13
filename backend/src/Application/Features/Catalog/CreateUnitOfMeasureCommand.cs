using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Catalog;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record CreateUnitOfMeasureCommand(string Name, string Abbreviation)
    : IRequest<Result<UnitOfMeasureDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateUnitOfMeasureCommandHandler
    : IRequestHandler<CreateUnitOfMeasureCommand, Result<UnitOfMeasureDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUnitOfMeasureRepository _units;

    public CreateUnitOfMeasureCommandHandler(ITenantContext tenantContext, IUnitOfMeasureRepository units)
    {
        _tenantContext = tenantContext;
        _units = units;
    }

    public async Task<Result<UnitOfMeasureDto>> Handle(
        CreateUnitOfMeasureCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        if (await _units.GetByNameAsync(tenantId, command.Name.Trim(), cancellationToken) is not null)
        {
            return Error.Conflict("A unit of measure with this name already exists.");
        }

        var unit = UnitOfMeasure.Create(tenantId, command.Name, command.Abbreviation);
        await _units.AddAsync(unit, cancellationToken);

        return Result.Success(CatalogMappers.ToUnitDto(unit));
    }
}
