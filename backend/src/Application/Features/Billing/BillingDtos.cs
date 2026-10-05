using BusinessOS.Domain.Billing;

namespace BusinessOS.Application.Features.Billing;

public static class PlanMappers
{
    public static PlanDto ToDto(Plan p) => new(
        p.Id, p.Code, p.Name, p.MonthlyPrice, p.Currency,
        p.FeatureKeys, p.MaxBranches, p.MaxUsers, p.MaxProducts, p.IsPackage);
}

public sealed record PlanDto(
    Guid Id,
    string Code,
    string Name,
    decimal MonthlyPrice,
    string Currency,
    IReadOnlyList<string> FeatureKeys,
    int? MaxBranches,
    int? MaxUsers,
    int? MaxProducts,
    bool IsPackage);

public static class SubscriptionMappers
{
    public static SubscriptionDto ToDto(Subscription s) => new(
        s.Id, s.TenantId, s.PlanCode, s.Status,
        s.TrialEndedAtUtc, s.PaidUntilUtc);
}

public sealed record SubscriptionDto(
    Guid Id,
    Guid TenantId,
    string PlanCode,
    SubscriptionStatus Status,
    DateTime TrialEndedAtUtc,
    DateTime? PaidUntilUtc);

public static class InvoiceMappers
{
    public static InvoiceDto ToDto(Invoice i) => new(
        i.Id, i.Number, i.Description, i.Amount, i.Currency,
        i.SubscriptionId, i.PeriodStartUtc, i.PeriodEndUtc, i.IssuedAtUtc,
        i.Status, i.Reference, i.ConfirmedByUserId, i.PaidAtUtc);
}

public sealed record InvoiceDto(
    Guid Id,
    string Number,
    string Description,
    decimal Amount,
    string Currency,
    Guid SubscriptionId,
    DateTime PeriodStartUtc,
    DateTime PeriodEndUtc,
    DateTime IssuedAtUtc,
    InvoiceStatus Status,
    string? Reference,
    Guid? ConfirmedByUserId,
    DateTime? PaidAtUtc);

public sealed record BillingDebtDto(
    Guid InvoiceId,
    string InvoiceNumber,
    Guid TenantId,
    string TenantName,
    decimal Amount,
    string Currency,
    DateTime IssuedAtUtc,
    string? Reference);

public sealed record CapabilitiesDto(
    IReadOnlyList<string> FeatureKeys,
    IReadOnlyList<string> PlanFeatureKeys,
    IReadOnlyList<string> Packages,
    string? PlanCode,
    int AccessLevel,
    int Status,
    DateTime EvaluatedAtUtc,
    DateTime ValidOfflineUntil,
    DateTime? NextDueUtc,
    bool HasOpenInvoice,
    int? MaxBranches,
    int? MaxUsers,
    int? MaxProducts);