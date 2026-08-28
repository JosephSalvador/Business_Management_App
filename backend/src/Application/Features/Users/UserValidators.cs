using BusinessOS.Application.Features.Common;
using BusinessOS.Domain.Identity;
using FluentValidation;

namespace BusinessOS.Application.Features.Users.Commands;

public sealed class CreateUserCommandValidator : AbstractValidator<CreateUserCommand>
{
    public CreateUserCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Password).PasswordPolicy();
        RuleFor(x => x.FullName).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Phone).Must(phone => phone is null || PhoneNumber.IsNormalizable(phone))
            .WithMessage("The phone number must be valid, e.g. 0712345678 or +255712345678.");
        RuleFor(x => x.RoleIds).NotNull();
        RuleFor(x => x.BranchIds).NotNull();
        RuleFor(x => x.DefaultBranchId)
            .Must((command, defaultId) => defaultId is null || command.BranchIds!.Contains(defaultId.Value))
            .WithMessage("Default branch must be among the assigned branches.");
    }
}

public sealed class UpdateUserCommandValidator : AbstractValidator<UpdateUserCommand>
{
    public UpdateUserCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.FullName).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Phone).Must(phone => phone is null || PhoneNumber.IsNormalizable(phone))
            .WithMessage("The phone number must be valid, e.g. 0712345678 or +255712345678.");
    }
}

public sealed class SetUserStatusCommandValidator : AbstractValidator<SetUserStatusCommand>
{
    public SetUserStatusCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed class DeleteUserCommandValidator : AbstractValidator<DeleteUserCommand>
{
    public DeleteUserCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public sealed class SetUserRolesCommandValidator : AbstractValidator<SetUserRolesCommand>
{
    public SetUserRolesCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.RoleIds).NotNull();
    }
}

public sealed class SetUserBranchesCommandValidator : AbstractValidator<SetUserBranchesCommand>
{
    public SetUserBranchesCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
        RuleFor(x => x.BranchIds).NotNull();
        RuleFor(x => x.DefaultBranchId)
            .Must((command, defaultId) => defaultId is null || command.BranchIds!.Contains(defaultId.Value))
            .WithMessage("Default branch must be among the assigned branches.");
    }
}
