using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Accounting.Commands;
using BusinessOS.Application.Features.Accounting.Queries;
using BusinessOS.Domain.Accounting;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class AccountingEndpoints
{
    public static IEndpointRouteBuilder MapAccountingEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        // ── Accounts ───────────────────────────────────────────────
        var accounts = api.MapGroup("/accounts")
            .WithApiVersionSet(versionSet)
            .WithTags("Accounts")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        accounts.MapGet("/", ListAccountsAsync)
            .RequirePermission(PermissionNames.AccountingView)
            .WithName("ListAccounts");
        accounts.MapPost("/", CreateAccountAsync)
            .RequirePermission(PermissionNames.AccountingCreate)
            .WithName("CreateAccount");
        accounts.MapPut("/{id:guid}", UpdateAccountAsync)
            .RequirePermission(PermissionNames.AccountingCreate)
            .WithName("UpdateAccount");

        // ── Journal Entries ────────────────────────────────────────
        var journalEntries = api.MapGroup("/journal-entries")
            .WithApiVersionSet(versionSet)
            .WithTags("JournalEntries")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        journalEntries.MapPost("/", CreateJournalEntryAsync)
            .RequirePermission(PermissionNames.AccountingCreate)
            .WithName("CreateJournalEntry");
        journalEntries.MapPost("/{id:guid}/post", PostJournalEntryAsync)
            .RequirePermission(PermissionNames.AccountingApprove)
            .WithName("PostJournalEntry");
        journalEntries.MapPost("/{id:guid}/void", VoidJournalEntryAsync)
            .RequirePermission(PermissionNames.AccountingApprove)
            .WithName("VoidJournalEntry");

        // ── Tenant Account Mappings ────────────────────────────────
        var mappings = api.MapGroup("/account-mappings")
            .WithApiVersionSet(versionSet)
            .WithTags("AccountMappings")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        mappings.MapGet("/{mappingKey}", GetTenantAccountMappingAsync)
            .RequirePermission(PermissionNames.AccountingView)
            .WithName("GetTenantAccountMapping");
        mappings.MapPost("/", CreateTenantAccountMappingAsync)
            .RequirePermission(PermissionNames.AccountingCreate)
            .WithName("CreateTenantAccountMapping");

        // ── Reports ────────────────────────────────────────────────
        var reports = api.MapGroup("/accounting-reports")
            .WithApiVersionSet(versionSet)
            .WithTags("AccountingReports")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        reports.MapGet("/trial-balance", GetTrialBalanceAsync)
            .RequirePermission(PermissionNames.AccountingView)
            .WithName("GetTrialBalance");
        reports.MapGet("/general-ledger", GetGeneralLedgerAsync)
            .RequirePermission(PermissionNames.AccountingView)
            .WithName("GetGeneralLedger");

        // ── Expenses ──────────────────────────────────────────────
        var expenses = api.MapGroup("/expenses")
            .WithApiVersionSet(versionSet)
            .WithTags("Expenses")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        expenses.MapGet("/", ListExpensesAsync)
            .RequirePermission(PermissionNames.ExpensesView)
            .WithName("ListExpenses");
        expenses.MapGet("/{id:guid}", GetExpenseAsync)
            .RequirePermission(PermissionNames.ExpensesView)
            .WithName("GetExpense");
        expenses.MapPost("/", CreateExpenseAsync)
            .RequirePermission(PermissionNames.ExpensesCreate)
            .WithName("CreateExpense");
        expenses.MapPut("/{id:guid}", UpdateExpenseAsync)
            .RequirePermission(PermissionNames.ExpensesUpdate)
            .WithName("UpdateExpense");
        expenses.MapDelete("/{id:guid}", DeleteExpenseAsync)
            .RequirePermission(PermissionNames.ExpensesDelete)
            .WithName("DeleteExpense");
        expenses.MapGet("/categories", ListExpenseCategoriesAsync)
            .RequirePermission(PermissionNames.ExpensesView)
            .WithName("ListExpenseCategories");
        expenses.MapPost("/categories", CreateExpenseCategoryAsync)
            .RequirePermission(PermissionNames.ExpensesCreate)
            .WithName("CreateExpenseCategory");
        expenses.MapGet("/summary", GetExpenseSummaryAsync)
            .RequirePermission(PermissionNames.ExpensesView)
            .WithName("GetExpenseSummary");

        return app;
    }

    // ── Account handlers ───────────────────────────────────────────
    private static async Task<IResult> ListAccountsAsync(
        bool? isActive,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListAccountsQuery(isActive), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateAccountAsync(
        CreateAccountRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateAccountCommand(request.Code, request.Name, request.Type),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateAccountAsync(
        Guid id,
        UpdateAccountRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new UpdateAccountCommand(id, request.Name, request.Type),
            cancellationToken)).ToApiResult();

    // ── Journal Entry handlers ─────────────────────────────────────
    private static async Task<IResult> CreateJournalEntryAsync(
        CreateJournalEntryRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateJournalEntryCommand(
                request.Description, request.EntryDate,
                request.SourceType, request.SourceId,
                request.Lines),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> PostJournalEntryAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new PostJournalEntryCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> VoidJournalEntryAsync(
        Guid id,
        VoidJournalEntryRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new VoidJournalEntryCommand(id, request.Reason),
            cancellationToken)).ToApiResult();

    // ── Mapping handlers ───────────────────────────────────────────
    private static async Task<IResult> GetTenantAccountMappingAsync(
        string mappingKey,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetTenantAccountMappingQuery(mappingKey), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateTenantAccountMappingAsync(
        CreateTenantAccountMappingRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateTenantAccountMappingCommand(request.MappingKey, request.AccountId),
            cancellationToken)).ToApiResult();

    // ── Report handlers ────────────────────────────────────────────
    private static async Task<IResult> GetTrialBalanceAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new TrialBalanceQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetGeneralLedgerAsync(
        DateTime? fromDate,
        DateTime? toDate,
        Guid? accountId,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new GeneralLedgerQuery(fromDate, toDate, accountId),
            cancellationToken)).ToApiResult();

    // ── Expense handlers ─────────────────────────────────────────
    private static async Task<IResult> ListExpensesAsync(
        int? page,
        int? pageSize,
        DateTime? fromDate,
        DateTime? toDate,
        string? search,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new ListExpensesQuery(page ?? 1, pageSize ?? 20, fromDate, toDate, search),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetExpenseAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new GetExpenseQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateExpenseAsync(
        CreateExpenseRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateExpenseCommand(
                request.Description, request.Amount, request.ExpenseDate,
                request.CategoryId, request.PaymentMethod, request.Reference, request.Notes),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> UpdateExpenseAsync(
        Guid id,
        UpdateExpenseRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new UpdateExpenseCommand(
                id, request.Description, request.Amount, request.ExpenseDate,
                request.CategoryId, request.PaymentMethod, request.Reference, request.Notes),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> DeleteExpenseAsync(
        Guid id,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new DeleteExpenseCommand(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> ListExpenseCategoriesAsync(
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(new ListExpenseCategoriesQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateExpenseCategoryAsync(
        CreateExpenseCategoryRequest request,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateExpenseCategoryCommand(request.Name),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> GetExpenseSummaryAsync(
        DateTime? fromDate,
        DateTime? toDate,
        ISender sender,
        CancellationToken cancellationToken)
        => (await sender.Send(
            new GetExpenseSummaryQuery(fromDate, toDate),
            cancellationToken)).ToApiResult();

    // ── Request DTOs ───────────────────────────────────────────────
    private sealed record CreateAccountRequest(
        string Code, string Name, AccountType Type);

    private sealed record UpdateAccountRequest(
        string Name, AccountType Type);

    private sealed record CreateJournalEntryRequest(
        string Description, DateTime EntryDate,
        string? SourceType, Guid? SourceId,
        IReadOnlyList<JournalEntryLineInput> Lines);

    private sealed record VoidJournalEntryRequest(string? Reason);

    private sealed record CreateTenantAccountMappingRequest(
        string MappingKey, Guid AccountId);

    private sealed record CreateExpenseRequest(
        string Description, decimal Amount, DateTime ExpenseDate,
        Guid? CategoryId, string? PaymentMethod, string? Reference, string? Notes);

    private sealed record CreateExpenseCategoryRequest(string Name);

    private sealed record UpdateExpenseRequest(
        string Description, decimal Amount, DateTime ExpenseDate,
        Guid? CategoryId, string? PaymentMethod, string? Reference, string? Notes);
}
