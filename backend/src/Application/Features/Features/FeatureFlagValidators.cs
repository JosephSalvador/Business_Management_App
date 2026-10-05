using BusinessOS.Application.Features.Features.Commands;
using BusinessOS.Application.Features.Features.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Features.Validators;

public sealed class SetFeatureFlagCommandValidator : AbstractValidator<SetFeatureFlagCommand>
{
    public SetFeatureFlagCommandValidator()
    {
        RuleFor(x => x.Key).NotEmpty().MaximumLength(100);
    }
}

public sealed class GetFeatureFlagQueryValidator : AbstractValidator<GetFeatureFlagQuery>
{
    public GetFeatureFlagQueryValidator()
    {
        RuleFor(x => x.Key).NotEmpty();
    }
}
