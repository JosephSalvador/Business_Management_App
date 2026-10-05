using Asp.Versioning.Builder;
using BusinessOS.Api.Authorization;
using BusinessOS.Api.Http;
using BusinessOS.Application.Features.Finance.Commands;
using BusinessOS.Application.Features.Finance.Queries;
using BusinessOS.Domain.Finance;
using BusinessOS.Domain.Identity;
using MediatR;

namespace BusinessOS.Api.Endpoints;

public static class FinanceEndpoints
{
    public static IEndpointRouteBuilder MapFinanceEndpoints(this IEndpointRouteBuilder app)
    {
        var api = app.MapGroup("/api/v{version:apiVersion}");
        var versionSet = api.NewApiVersionSet()
            .HasApiVersion(new Asp.Versioning.ApiVersion(1, 0))
            .ReportApiVersions()
            .Build();

        // ── Money Accounts ───────────────────────────────────────
        var accounts = api.MapGroup("/money-accounts")
            .WithApiVersionSet(versionSet)
            .WithTags("MoneyAccounts")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        accounts.MapGet("/", ListMoneyAccountsAsync)
            .RequirePermission(PermissionNames.AccountingView)
            .WithName("ListMoneyAccounts");
        accounts.MapGet("/{id:guid}", GetMoneyAccountAsync)
            .RequirePermission(PermissionNames.AccountingView)
            .WithName("GetMoneyAccount");
        accounts.MapPost("/", CreateMoneyAccountAsync)
            .RequirePermission(PermissionNames.AccountingCreate)
            .WithName("CreateMoneyAccount");
        accounts.MapPost("/transfer", TransferMoneyAsync)
            .RequirePermission(PermissionNames.AccountingCreate)
            .WithName("TransferMoney");
        accounts.MapPost("/income", RecordIncomeAsync)
            .RequirePermission(PermissionNames.AccountingCreate)
            .WithName("RecordIncome");
        accounts.MapPost("/expense", RecordAccountExpenseAsync)
            .RequirePermission(PermissionNames.AccountingCreate)
            .WithName("RecordAccountExpense");
        accounts.MapGet("/{id:guid}/transactions", ListAccountTransactionsAsync)
            .RequirePermission(PermissionNames.AccountingView)
            .WithName("ListAccountTransactions");

        // ── Cash Sessions ────────────────────────────────────────
        var cashSessions = api.MapGroup("/cash-sessions")
            .WithApiVersionSet(versionSet)
            .WithTags("CashSessions")
            .RequireAuthorization()
            .RequireRateLimiting("global");

        cashSessions.MapGet("/current", GetCurrentCashSessionAsync)
            .RequirePermission(PermissionNames.AccountingView)
            .WithName("GetCurrentCashSession");
        cashSessions.MapPost("/", OpenCashSessionAsync)
            .RequirePermission(PermissionNames.AccountingCreate)
            .WithName("OpenCashSession");
        cashSessions.MapPost("/{id:guid}/close", CloseCashSessionAsync)
            .RequirePermission(PermissionNames.AccountingCreate)
            .WithName("CloseCashSession");

        return app;
    }

    // ── Money Account handlers ───────────────────────────────────
    private static async Task<IResult> ListMoneyAccountsAsync(
        ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new ListMoneyAccountsQuery(), cancellationToken)).ToApiResult();

    private static async Task<IResult> GetMoneyAccountAsync(
        Guid id, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(new GetMoneyAccountQuery(id), cancellationToken)).ToApiResult();

    private static async Task<IResult> CreateMoneyAccountAsync(
        CreateMoneyAccountRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new CreateMoneyAccountCommand(request.Name, request.Type, request.Reference),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> TransferMoneyAsync(
        TransferMoneyRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new TransferMoneyCommand(request.FromAccountId, request.ToAccountId, request.Amount, request.Description),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> RecordIncomeAsync(
        RecordIncomeRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new RecordIncomeCommand(request.AccountId, request.Amount, request.Description),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> RecordAccountExpenseAsync(
        RecordExpenseRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new RecordAccountExpenseCommand(request.AccountId, request.Amount, request.Description),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> ListAccountTransactionsAsync(
        Guid id, int? page, int? pageSize, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new ListAccountTransactionsQuery(id, page ?? 1, pageSize ?? 20),
            cancellationToken)).ToApiResult();

    // ── Cash Session handlers ────────────────────────────────────
    private static async Task<IResult> GetCurrentCashSessionAsync(
        Guid? accountId, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new GetCurrentCashSessionQuery(accountId ?? Guid.Empty),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> OpenCashSessionAsync(
        OpenCashSessionRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new OpenCashSessionCommand(request.AccountId, request.OpeningCash),
            cancellationToken)).ToApiResult();

    private static async Task<IResult> CloseCashSessionAsync(
        Guid id, CloseCashSessionRequest request, ISender sender, CancellationToken cancellationToken)
        => (await sender.Send(
            new CloseCashSessionCommand(id, request.ClosingCash, request.Notes),
            cancellationToken)).ToApiResult();

    // ── Request DTOs ─────────────────────────────────────────────
    private sealed record CreateMoneyAccountRequest(
        string Name, MoneyAccountType Type, string? Reference);

    private sealed record TransferMoneyRequest(
        Guid FromAccountId, Guid ToAccountId, decimal Amount, string Description);

    private sealed record RecordIncomeRequest(
        Guid AccountId, decimal Amount, string Description);

    private sealed record RecordExpenseRequest(
        Guid AccountId, decimal Amount, string Description);

    private sealed record OpenCashSessionRequest(
        Guid AccountId, decimal OpeningCash);

    private sealed record CloseCashSessionRequest(
        decimal ClosingCash, string? Notes);
}
