using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;
using BusinessOS.Shared;
using MediatR;

namespace BusinessOS.Application.Features.Accounting.Commands;

public static class AccountingMappers
{
    public static AccountDto ToDto(Account a) => new(
        a.Id, a.TenantId, a.Code, a.Name, a.Type, a.IsActive, a.CreatedAt);

    public static JournalEntryLineDto ToDto(JournalEntryLine l) => new(
        l.Id, l.AccountId, l.DebitAmount, l.CreditAmount, l.Description);

    public static JournalEntryDto ToDto(
        JournalEntry je, IReadOnlyList<JournalEntryLineDto> lines) => new(
        je.Id, je.TenantId, je.Description, je.EntryDate,
        je.SourceType, je.SourceId, je.Status,
        je.TotalDebit, je.TotalCredit, je.PostedAt,
        je.VoidedAt, lines, je.CreatedAt);
}

// ── Create Account ────────────────────────────────────────────────
public sealed record CreateAccountCommand(
    string Code, string Name, AccountType Type)
    : IRequest<Result<AccountDto>>, IRequiresTenantAdvisoryLock;

public sealed class CreateAccountCommandHandler
    : IRequestHandler<CreateAccountCommand, Result<AccountDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAccountRepository _accounts;

    public CreateAccountCommandHandler(ITenantContext tenantContext, IAccountRepository accounts)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
    }

    public async Task<Result<AccountDto>> Handle(
        CreateAccountCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var existing = await _accounts.ListAsync(tenantId, null, cancellationToken);
        if (existing.Any(a => a.Code.Equals(command.Code, StringComparison.OrdinalIgnoreCase)))
        {
            return Error.Conflict($"An account with code '{command.Code}' already exists.");
        }

        var account = Account.Create(tenantId, command.Code, command.Name, command.Type);
        await _accounts.AddAsync(account, cancellationToken);
        return Result.Success(AccountingMappers.ToDto(account));
    }
}

// ── Create Journal Entry ─────────────────────────────────────────
public sealed record CreateJournalEntryCommand(
    string Description, DateTime EntryDate,
    string? SourceType, Guid? SourceId,
    IReadOnlyList<JournalEntryLineInput> Lines)
    : IRequest<Result<JournalEntryDto>>, IRequiresTenantAdvisoryLock;

public sealed record JournalEntryLineInput(
    Guid AccountId, decimal DebitAmount, decimal CreditAmount, string? Description);

public sealed class CreateJournalEntryCommandHandler
    : IRequestHandler<CreateJournalEntryCommand, Result<JournalEntryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IAccountRepository _accounts;
    private readonly IJournalEntryRepository _journalEntries;

    public CreateJournalEntryCommandHandler(
        ITenantContext tenantContext, IAccountRepository accounts,
        IJournalEntryRepository journalEntries)
    {
        _tenantContext = tenantContext;
        _accounts = accounts;
        _journalEntries = journalEntries;
    }

    public async Task<Result<JournalEntryDto>> Handle(
        CreateJournalEntryCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;

        foreach (var line in command.Lines)
        {
            var account = await _accounts.GetByIdAsync(tenantId, line.AccountId, cancellationToken);
            if (account is null)
                return Error.NotFound($"Account {line.AccountId} not found.");
            if (!account.IsActive)
                return Error.Validation($"Account '{account.Name}' is not active.");
        }

        var domainLines = command.Lines.Select(l =>
            JournalEntryLine.Create(l.AccountId, l.DebitAmount, l.CreditAmount, l.Description)).ToList();

        JournalEntry entry;
        try
        {
            entry = JournalEntry.Create(
                tenantId, command.Description, command.EntryDate,
                command.SourceType, command.SourceId, domainLines);
        }
        catch (InvalidOperationException ex)
        {
            return Error.Validation(ex.Message);
        }

        await _journalEntries.AddAsync(entry, cancellationToken);

        var lineDtos = entry.Lines.Select(AccountingMappers.ToDto).ToList();
        return Result.Success(AccountingMappers.ToDto(entry, lineDtos));
    }
}

// ── Post Journal Entry ───────────────────────────────────────────
public sealed record PostJournalEntryCommand(Guid JournalEntryId)
    : IRequest<Result<JournalEntryDto>>, IRequiresTenantAdvisoryLock;

public sealed class PostJournalEntryCommandHandler
    : IRequestHandler<PostJournalEntryCommand, Result<JournalEntryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IJournalEntryRepository _journalEntries;

    public PostJournalEntryCommandHandler(
        ITenantContext tenantContext, IJournalEntryRepository journalEntries)
    {
        _tenantContext = tenantContext;
        _journalEntries = journalEntries;
    }

    public async Task<Result<JournalEntryDto>> Handle(
        PostJournalEntryCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var entry = await _journalEntries.GetByIdAsync(tenantId, command.JournalEntryId, cancellationToken);
        if (entry is null) return Error.NotFound("Journal entry not found.");

        try
        {
            entry.Post(DateTime.UtcNow);
        }
        catch (InvalidOperationException ex)
        {
            return Error.Validation(ex.Message);
        }

        await _journalEntries.UpdateAsync(entry, cancellationToken);
        var lineDtos = entry.Lines.Select(AccountingMappers.ToDto).ToList();
        return Result.Success(AccountingMappers.ToDto(entry, lineDtos));
    }
}

// ── Void Journal Entry ───────────────────────────────────────────
public sealed record VoidJournalEntryCommand(Guid JournalEntryId, string? Reason)
    : IRequest<Result<JournalEntryDto>>, IRequiresTenantAdvisoryLock;

public sealed class VoidJournalEntryCommandHandler
    : IRequestHandler<VoidJournalEntryCommand, Result<JournalEntryDto>>
{
    private readonly ITenantContext _tenantContext;
    private readonly IJournalEntryRepository _journalEntries;

    public VoidJournalEntryCommandHandler(
        ITenantContext tenantContext, IJournalEntryRepository journalEntries)
    {
        _tenantContext = tenantContext;
        _journalEntries = journalEntries;
    }

    public async Task<Result<JournalEntryDto>> Handle(
        VoidJournalEntryCommand command, CancellationToken cancellationToken)
    {
        var tenantId = _tenantContext.TenantId;
        var entry = await _journalEntries.GetByIdAsync(tenantId, command.JournalEntryId, cancellationToken);
        if (entry is null) return Error.NotFound("Journal entry not found.");

        try
        {
            entry.Void(DateTime.UtcNow);
        }
        catch (InvalidOperationException ex)
        {
            return Error.Validation(ex.Message);
        }

        await _journalEntries.UpdateAsync(entry, cancellationToken);
        var lineDtos = entry.Lines.Select(AccountingMappers.ToDto).ToList();
        return Result.Success(AccountingMappers.ToDto(entry, lineDtos));
    }
}
