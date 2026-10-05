enum ReportPeriod { today, yesterday, thisWeek, thisMonth, lastMonth, custom }

class ReportFilter {
  const ReportFilter({
    this.period = ReportPeriod.thisMonth,
    this.from,
    this.to,
    this.locationId,
    this.staffId,
    this.categoryId,
    this.paymentMethod,
  });

  final ReportPeriod period;
  final DateTime? from;
  final DateTime? to;
  final String? locationId;
  final String? staffId;
  final String? categoryId;
  final String? paymentMethod;

  ReportFilter copyWith({
    ReportPeriod? period,
    DateTime? from,
    DateTime? to,
    String? locationId,
    String? staffId,
    String? categoryId,
    String? paymentMethod,
    bool clearLocationId = false,
    bool clearStaffId = false,
    bool clearCategoryId = false,
    bool clearPaymentMethod = false,
    bool clearCustomDates = false,
  }) {
    return ReportFilter(
      period: period ?? this.period,
      from: clearCustomDates ? null : (from ?? this.from),
      to: clearCustomDates ? null : (to ?? this.to),
      locationId: clearLocationId ? null : (locationId ?? this.locationId),
      staffId: clearStaffId ? null : (staffId ?? this.staffId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      paymentMethod:
          clearPaymentMethod ? null : (paymentMethod ?? this.paymentMethod),
    );
  }

  /// Returns the effective (from, to) DateTime range in local time.
  (DateTime, DateTime) get dateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfToday = today
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1));

    if (from != null && to != null && period == ReportPeriod.custom) {
      return (from!, to!);
    }

    return switch (period) {
      ReportPeriod.today => (today, endOfToday),
      ReportPeriod.yesterday => (
          today.subtract(const Duration(days: 1)),
          today.subtract(const Duration(microseconds: 1)),
        ),
      ReportPeriod.thisWeek => (
          today.subtract(Duration(days: today.weekday - 1)),
          endOfToday,
        ),
      ReportPeriod.thisMonth => (
          DateTime(today.year, today.month, 1),
          endOfToday
        ),
      ReportPeriod.lastMonth => (
          DateTime(today.year, today.month - 1, 1),
          DateTime(today.year, today.month, 1)
              .subtract(const Duration(microseconds: 1)),
        ),
      ReportPeriod.custom => (from ?? today, to ?? endOfToday),
    };
  }

  Map<String, dynamic> toQueryParams() {
    final (fromDate, toDate) = dateRange;
    return {
      'from': fromDate.toUtc().toIso8601String(),
      'to': toDate.toUtc().toIso8601String(),
      if (locationId != null) 'branchId': locationId,
    };
  }
}
