using BusinessOS.Application.Features.Accounting.Commands;
using BusinessOS.Application.Features.Accounting.Queries;
using BusinessOS.Application.Ports;
using BusinessOS.Domain.Accounting;
using BusinessOS.Shared;

namespace BusinessOS.Tests.Unit.Accounting;

internal static class AccountingTestHelper
{
    private static readonly Guid DefaultTenantId = new("11111111-1111-1111-1111-111111111111");
    public static ITenantContext StubTenant() => new StubTenantContext(DefaultTenantId);
}

internal sealed class StubTenantContext(Guid tenantId) : ITenantContext
{
    public Guid TenantId => tenantId;
    public Guid? UserId => Guid.NewGuid();
    public string? IpAddress => "127.0.0.1";
    public string? UserAgent => null;
    public string? CurrentRefreshToken => null;
}

internal sealed class StubAccountRepository : IAccountRepository
{
    private readonly List<Account> _seeded = [];
    public void Seed(Account account) => _seeded.Add(account);
    public Task AddAsync(Account a, CancellationToken ct = default) { _seeded.Add(a); return Task.CompletedTask; }
    public Task UpdateAsync(Account a, CancellationToken ct = default) => Task.CompletedTask;
    public Task<Account?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(a => a.Id == id));
    public Task<IReadOnlyList<Account>> ListAsync(Guid tenantId, bool? isActive = null, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<Account>>(
            _seeded.Where(a => isActive == null || a.IsActive == isActive).ToList());
}

internal sealed class StubJournalEntryRepository : IJournalEntryRepository
{
    private readonly List<JournalEntry> _seeded = [];
    public void Seed(JournalEntry entry) => _seeded.Add(entry);
    public Task AddAsync(JournalEntry e, CancellationToken ct = default) { _seeded.Add(e); return Task.CompletedTask; }
    public Task UpdateAsync(JournalEntry e, CancellationToken ct = default) => Task.CompletedTask;
    public Task<JournalEntry?> GetByIdAsync(Guid tenantId, Guid id, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(e => e.Id == id));
    public Task<JournalEntry?> GetBySourceAsync(Guid tenantId, string sourceType, Guid sourceId, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(e => e.SourceType == sourceType && e.SourceId == sourceId));
    public Task<IReadOnlyList<JournalEntry>> ListAsync(Guid tenantId, int page, int pageSize, CancellationToken ct = default)
        => Task.FromResult<IReadOnlyList<JournalEntry>>(_seeded.Skip((page - 1) * pageSize).Take(pageSize).ToList());
    public Task<int> CountAsync(Guid tenantId, CancellationToken ct = default)
        => Task.FromResult(_seeded.Count);
}

internal sealed class StubTenantAccountMappingRepository : ITenantAccountMappingRepository
{
    private readonly List<TenantAccountMapping> _seeded = [];
    public void Seed(TenantAccountMapping mapping) => _seeded.Add(mapping);
    public Task AddAsync(TenantAccountMapping m, CancellationToken ct = default) { _seeded.Add(m); return Task.CompletedTask; }
    public Task<TenantAccountMapping?> GetByMappingKeyAsync(Guid tenantId, string mappingKey, CancellationToken ct = default)
        => Task.FromResult(_seeded.FirstOrDefault(m => m.TenantId == tenantId && m.MappingKey == mappingKey));
}

public sealed class CreateAccountCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task ValidAccount_ReturnsSuccess()
    {
        var handler = new CreateAccountCommandHandler(
            AccountingTestHelper.StubTenant(), new StubAccountRepository());
        var result = await handler.Handle(
            new CreateAccountCommand("1000", "Cash", AccountType.Asset),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal("1000", result.Value.Code);
        Assert.Equal("Cash", result.Value.Name);
        Assert.Equal(AccountType.Asset, result.Value.Type);
    }

    [Fact]
    public async Task DuplicateCode_ReturnsConflict()
    {
        var repo = new StubAccountRepository();
        repo.Seed(Account.Create(TenantId, "1000", "Cash", AccountType.Asset));

        var handler = new CreateAccountCommandHandler(
            AccountingTestHelper.StubTenant(), repo);
        var result = await handler.Handle(
            new CreateAccountCommand("1000", "Cash Other", AccountType.Asset),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("Conflict", result.Error.Code);
    }
}

public sealed class UpdateAccountCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task ValidUpdate_ReturnsSuccess()
    {
        var account = Account.Create(TenantId, "1000", "Cash", AccountType.Asset);
        var repo = new StubAccountRepository();
        repo.Seed(account);

        var handler = new UpdateAccountCommandHandler(
            AccountingTestHelper.StubTenant(), repo);
        var result = await handler.Handle(
            new UpdateAccountCommand(account.Id, "Cash Updated", AccountType.Asset),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal("Cash Updated", result.Value.Name);
    }

    [Fact]
    public async Task NotFound_ReturnsError()
    {
        var handler = new UpdateAccountCommandHandler(
            AccountingTestHelper.StubTenant(), new StubAccountRepository());
        var result = await handler.Handle(
            new UpdateAccountCommand(Guid.NewGuid(), "X", AccountType.Asset),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("NotFound", result.Error.Code);
    }
}

public sealed class CreateJournalEntryCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task ValidEntry_ReturnsSuccess()
    {
        var cashAccount = Account.Create(TenantId, "1000", "Cash", AccountType.Asset);
        var revenueAccount = Account.Create(TenantId, "4000", "Revenue", AccountType.Revenue);
        var repo = new StubAccountRepository();
        repo.Seed(cashAccount);
        repo.Seed(revenueAccount);

        var handler = new CreateJournalEntryCommandHandler(
            AccountingTestHelper.StubTenant(), repo, new StubJournalEntryRepository());
        var result = await handler.Handle(
            new CreateJournalEntryCommand(
                "Test entry", DateTime.UtcNow, null, null,
                [
                    new JournalEntryLineInput(cashAccount.Id, 100, 0, null),
                    new JournalEntryLineInput(revenueAccount.Id, 0, 100, null)
                ]),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal("Test entry", result.Value.Description);
        Assert.Equal(2, result.Value.Lines.Count);
    }

    [Fact]
    public async Task UnbalancedEntry_ReturnsError()
    {
        var cashAccount = Account.Create(TenantId, "1000", "Cash", AccountType.Asset);
        var repo = new StubAccountRepository();
        repo.Seed(cashAccount);

        var handler = new CreateJournalEntryCommandHandler(
            AccountingTestHelper.StubTenant(), repo, new StubJournalEntryRepository());
        var result = await handler.Handle(
            new CreateJournalEntryCommand(
                "Unbalanced", DateTime.UtcNow, null, null,
                [
                    new JournalEntryLineInput(cashAccount.Id, 100, 0, null)
                ]),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
    }

    [Fact]
    public async Task NonexistentAccount_ReturnsNotFound()
    {
        var handler = new CreateJournalEntryCommandHandler(
            AccountingTestHelper.StubTenant(), new StubAccountRepository(), new StubJournalEntryRepository());
        var result = await handler.Handle(
            new CreateJournalEntryCommand(
                "Test", DateTime.UtcNow, null, null,
                [
                    new JournalEntryLineInput(Guid.NewGuid(), 100, 0, null)
                ]),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("NotFound", result.Error.Code);
    }
}

public sealed class PostJournalEntryCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task DraftEntry_PostsSuccessfully()
    {
        var cashAccount = Account.Create(TenantId, "1000", "Cash", AccountType.Asset);
        var revenueAccount = Account.Create(TenantId, "4000", "Revenue", AccountType.Revenue);

        var entry = JournalEntry.Create(
            TenantId, "Test", DateTime.UtcNow, null, null,
            [
                JournalEntryLine.Create(cashAccount.Id, 100, 0, null),
                JournalEntryLine.Create(revenueAccount.Id, 0, 100, null)
            ]);

        var repo = new StubJournalEntryRepository();
        repo.Seed(entry);

        var handler = new PostJournalEntryCommandHandler(
            AccountingTestHelper.StubTenant(), repo);
        var result = await handler.Handle(
            new PostJournalEntryCommand(entry.Id),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(JournalEntryStatus.Posted, result.Value.Status);
    }

    [Fact]
    public async Task AlreadyPosted_ReturnsError()
    {
        var cashAccount = Account.Create(TenantId, "1000", "Cash", AccountType.Asset);
        var revenueAccount = Account.Create(TenantId, "4000", "Revenue", AccountType.Revenue);

        var entry = JournalEntry.Create(
            TenantId, "Test", DateTime.UtcNow, null, null,
            [
                JournalEntryLine.Create(cashAccount.Id, 100, 0, null),
                JournalEntryLine.Create(revenueAccount.Id, 0, 100, null)
            ]);
        entry.Post(DateTime.UtcNow);

        var repo = new StubJournalEntryRepository();
        repo.Seed(entry);

        var handler = new PostJournalEntryCommandHandler(
            AccountingTestHelper.StubTenant(), repo);
        var result = await handler.Handle(
            new PostJournalEntryCommand(entry.Id),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
    }
}

public sealed class VoidJournalEntryCommandTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task PostedEntry_VoidsSuccessfully()
    {
        var cashAccount = Account.Create(TenantId, "1000", "Cash", AccountType.Asset);
        var revenueAccount = Account.Create(TenantId, "4000", "Revenue", AccountType.Revenue);

        var entry = JournalEntry.Create(
            TenantId, "Test", DateTime.UtcNow, null, null,
            [
                JournalEntryLine.Create(cashAccount.Id, 100, 0, null),
                JournalEntryLine.Create(revenueAccount.Id, 0, 100, null)
            ]);
        entry.Post(DateTime.UtcNow);

        var repo = new StubJournalEntryRepository();
        repo.Seed(entry);

        var handler = new VoidJournalEntryCommandHandler(
            AccountingTestHelper.StubTenant(), repo);
        var result = await handler.Handle(
            new VoidJournalEntryCommand(entry.Id, "Mistake"),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(JournalEntryStatus.Voided, result.Value.Status);
    }

    [Fact]
    public async Task DraftEntry_CannotVoid()
    {
        var cashAccount = Account.Create(TenantId, "1000", "Cash", AccountType.Asset);
        var revenueAccount = Account.Create(TenantId, "4000", "Revenue", AccountType.Revenue);

        var entry = JournalEntry.Create(
            TenantId, "Test", DateTime.UtcNow, null, null,
            [
                JournalEntryLine.Create(cashAccount.Id, 100, 0, null),
                JournalEntryLine.Create(revenueAccount.Id, 0, 100, null)
            ]);

        var repo = new StubJournalEntryRepository();
        repo.Seed(entry);

        var handler = new VoidJournalEntryCommandHandler(
            AccountingTestHelper.StubTenant(), repo);
        var result = await handler.Handle(
            new VoidJournalEntryCommand(entry.Id, null),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
    }
}

public sealed class ListAccountsQueryTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task ReturnsAllAccounts()
    {
        var repo = new StubAccountRepository();
        repo.Seed(Account.Create(TenantId, "1000", "Cash", AccountType.Asset));
        repo.Seed(Account.Create(TenantId, "4000", "Revenue", AccountType.Revenue));

        var handler = new ListAccountsQueryHandler(
            AccountingTestHelper.StubTenant(), repo);
        var result = await handler.Handle(
            new ListAccountsQuery(null),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(2, result.Value.Count);
    }
}

public sealed class TenantAccountMappingTests
{
    private static readonly Guid TenantId = new("11111111-1111-1111-1111-111111111111");

    [Fact]
    public async Task CreateMapping_ReturnsSuccess()
    {
        var account = Account.Create(TenantId, "1000", "Cash", AccountType.Asset);
        var accountRepo = new StubAccountRepository();
        accountRepo.Seed(account);
        var mappingRepo = new StubTenantAccountMappingRepository();

        var handler = new CreateTenantAccountMappingCommandHandler(
            AccountingTestHelper.StubTenant(), accountRepo, mappingRepo);
        var result = await handler.Handle(
            new CreateTenantAccountMappingCommand(AccountMappingKeys.CashOnHand, account.Id),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.Equal(AccountMappingKeys.CashOnHand, result.Value.MappingKey);
    }

    [Fact]
    public async Task DuplicateMappingKey_ReturnsConflict()
    {
        var account = Account.Create(TenantId, "1000", "Cash", AccountType.Asset);
        var accountRepo = new StubAccountRepository();
        accountRepo.Seed(account);

        var mappingRepo = new StubTenantAccountMappingRepository();
        mappingRepo.Seed(TenantAccountMapping.Create(TenantId, AccountMappingKeys.CashOnHand, account.Id));

        var handler = new CreateTenantAccountMappingCommandHandler(
            AccountingTestHelper.StubTenant(), accountRepo, mappingRepo);
        var result = await handler.Handle(
            new CreateTenantAccountMappingCommand(AccountMappingKeys.CashOnHand, account.Id),
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("Conflict", result.Error.Code);
    }
}
