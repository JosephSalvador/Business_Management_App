using BusinessOS.Application.Features.Reports.Queries;
using FluentValidation;

namespace BusinessOS.Application.Features.Reports.Validators;

public sealed class TaxSummaryQueryValidator : AbstractValidator<TaxSummaryQuery>
{
    public TaxSummaryQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class SalesSummaryQueryValidator : AbstractValidator<SalesSummaryQuery>
{
    public SalesSummaryQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class TopProductsQueryValidator : AbstractValidator<TopProductsQuery>
{
    public TopProductsQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
        RuleFor(x => x.Limit).InclusiveBetween(1, 100);
    }
}

public sealed class SalesTrendQueryValidator : AbstractValidator<SalesTrendQuery>
{
    public SalesTrendQueryValidator()
    {
        RuleFor(x => x.Days).InclusiveBetween(1, 365);
    }
}

public sealed class ExportTaxSummaryCommandValidator : AbstractValidator<ExportTaxSummaryCommand>
{
    public ExportTaxSummaryCommandValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class ExportSalesSummaryCommandValidator : AbstractValidator<ExportSalesSummaryCommand>
{
    public ExportSalesSummaryCommandValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class ExportTopProductsCommandValidator : AbstractValidator<ExportTopProductsCommand>
{
    public ExportTopProductsCommandValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
        RuleFor(x => x.Limit).InclusiveBetween(1, 100);
    }
}

public sealed class BusinessOverviewQueryValidator : AbstractValidator<BusinessOverviewQuery>
{
    public BusinessOverviewQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class MoneyMovementQueryValidator : AbstractValidator<MoneyMovementQuery>
{
    public MoneyMovementQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class PurchasesSummaryQueryValidator : AbstractValidator<PurchasesSummaryQuery>
{
    public PurchasesSummaryQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class SalesByPaymentMethodQueryValidator : AbstractValidator<SalesByPaymentMethodQuery>
{
    public SalesByPaymentMethodQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class SalesByCategoryQueryValidator : AbstractValidator<SalesByCategoryQuery>
{
    public SalesByCategoryQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class SalesByStaffQueryValidator : AbstractValidator<SalesByStaffQuery>
{
    public SalesByStaffQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class SalesByCustomerQueryValidator : AbstractValidator<SalesByCustomerQuery>
{
    public SalesByCustomerQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class StockSummaryQueryValidator : AbstractValidator<StockSummaryQuery>
{
    public StockSummaryQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class StockMovementSummaryQueryValidator : AbstractValidator<StockMovementSummaryQuery>
{
    public StockMovementSummaryQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class ExpenseTrendQueryValidator : AbstractValidator<ExpenseTrendQuery>
{
    public ExpenseTrendQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class ExpenseByPaymentMethodQueryValidator : AbstractValidator<ExpenseByPaymentMethodQuery>
{
    public ExpenseByPaymentMethodQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class PurchasesBySupplierQueryValidator : AbstractValidator<PurchasesBySupplierQuery>
{
    public PurchasesBySupplierQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class ExportSalesByPaymentMethodCommandValidator : AbstractValidator<ExportSalesByPaymentMethodCommand>
{
    public ExportSalesByPaymentMethodCommandValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class ExportStockSummaryCommandValidator : AbstractValidator<ExportStockSummaryCommand>
{
    public ExportStockSummaryCommandValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}

public sealed class ExportExpenseSummaryCommandValidator : AbstractValidator<ExportExpenseSummaryCommand>
{
    public ExportExpenseSummaryCommandValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To);
    }
}
