using BusinessOS.Application.Features.Catalog.Dtos;
using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Catalog;

public sealed record UpdateUnitOfMeasureCommand(Guid Id, string Name, string Abbreviation)
    : IRequest<Result<UnitOfMeasureDto>>, IRequiresTenantAdvisoryLock;

public sealed class UpdateUnitOfMeasureCommandHandler
    : IRequestHandler<UpdateUnitOfMeasureCommand, Result<UnitOfMeasureDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IUnitOfMeasureRepository _units;

    public UpdateUnitOfMeasureCommandHandler(ITenantContext tenantContext, IUnitOfMeasureRepository units)
    {
        _tenantContext = tenantContext;
        _units = units;
    }

    public async Task<Result<UnitOfMeasureDto>> Handle(
        UpdateUnitOfMeasureCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var unit = await _units.GetByIdAsync(tenantId, command.Id, cancellationToken);
        if (unit is null)
        {
            return Error.NotFound("Unit of measure not found.");
        }

        if (await _units.GetByNameAsync(tenantId, command.Name.Trim(), cancellationToken) is { } owner
            && owner.Id != unit.Id)
        {
            return Error.Conflict("A unit of measure with this name already exists.");
        }

        unit.Update(command.Name, command.Abbreviation);
        return Result.Success(CatalogMappers.ToUnitDto(unit));
    }
}
