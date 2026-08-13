using FluentValidation;

namespace BusinessOS.Application.Features.Common;

/// <summary>
/// Single source of truth for the password policy shared by registration and
/// admin-created users. Matches the Auth slice policy exactly.
/// </summary>
internal static class PasswordRules
{
    internal static IRuleBuilderOptions<T, string> PasswordPolicy<T>(this IRuleBuilder<T, string> ruleBuilder)
        => ruleBuilder
            .NotEmpty()
            .MinimumLength(8).WithMessage("Password must be at least 8 characters long.")
            .MaximumLength(128).WithMessage("Password must not exceed 128 characters.")
            .Matches("[A-Z]").WithMessage("Password must contain an uppercase letter.")
            .Matches("[a-z]").WithMessage("Password must contain a lowercase letter.")
            .Matches("[0-9]").WithMessage("Password must contain a digit.")
            .Matches("[^A-Za-z0-9]").WithMessage("Password must contain a special character.");
}
