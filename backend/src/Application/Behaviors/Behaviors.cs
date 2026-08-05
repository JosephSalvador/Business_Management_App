using BusinessOS.Application.Ports;
using BusinessOS.Shared;
using FluentValidation;
using MediatR;

namespace BusinessOS.Application.Behaviors;

public sealed class ValidationBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
    where TResponse : Result, IResult<TResponse>
{
    private readonly IEnumerable<IValidator<TRequest>> _validators;

    public ValidationBehavior(IEnumerable<IValidator<TRequest>> validators)
        => _validators = validators;

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var failures = new List<FluentValidation.Results.ValidationFailure>();
        foreach (var validator in _validators)
        {
            var result = await validator.ValidateAsync(request, cancellationToken);
            failures.AddRange(result.Errors);
        }

        if (failures.Count > 0)
        {
            var details = failures
                .GroupBy(f => f.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());
            return TResponse.Failure(Error.Validation(details));
        }

        return await next();
    }
}

public sealed class TransactionBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
    where TResponse : Result, IResult<TResponse>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IEventBus _eventBus;

    public TransactionBehavior(IUnitOfWork unitOfWork, IEventBus eventBus)
    {
        _unitOfWork = unitOfWork;
        _eventBus = eventBus;
    }

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var response = await next();

        var dispatched = await _unitOfWork.SaveChangesAsync(cancellationToken);

        if (response.IsFailure)
        {
            return response;
        }

        foreach (var item in dispatched)
        {
            await _eventBus.PublishAsync(item.Event, cancellationToken);
        }

        if (dispatched.Count > 0)
        {
            await _unitOfWork.MarkProcessedAsync(dispatched.Select(d => d.OutboxMessageId).ToArray(), cancellationToken);
        }

        return response;
    }
}
