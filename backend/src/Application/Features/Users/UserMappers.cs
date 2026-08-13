using BusinessOS.Application.Features.Users.Dtos;
using BusinessOS.Domain.Identity;
using BusinessOS.Domain.Tenants;

namespace BusinessOS.Application.Features.Users;

internal static class UserMappers
{
    internal static IdentityUserDto ToDto(User user) => new(
        user.Id,
        user.TenantId,
        user.Email,
        user.FullName,
        user.Phone,
        user.IsActive,
        user.EmailVerified,
        user.IsLockedOut,
        user.Roles.Select(r => r.Id).ToArray(),
        user.Branches.Select(b => b.BranchId).ToArray(),
        user.DefaultBranchId,
        user.CreatedAt,
        user.UpdatedAt);

    internal static UserBranchDto ToBranchDto(Branch branch, bool isDefault) => new(
        branch.Id,
        branch.Name,
        branch.Code,
        isDefault);
}
