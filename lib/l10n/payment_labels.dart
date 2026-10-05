import 'generated/app_localizations.dart';

/// Display labels for money-account types (kept in storage as legacy keys).
String moneyAccountTypeLabel(AppLocalizations loc, int type) => switch (type) {
      0 => loc.posCash,
      1 => loc.posMobileMoney,
      2 => loc.posBankTransfer,
      _ => loc.commonOther,
    };

/// Display label for a stored expense payment-method value. The stored value
/// is kept untouched; only the presentation is localized.
String storedPaymentMethodLabel(AppLocalizations loc, String? stored) =>
    switch (stored) {
      'Pesa Taslimu' => loc.posCash,
      'M-Pesa' => loc.posMobileMoney,
      'Benki' => loc.posBankTransfer,
      'Nyingine' => loc.commonOther,
      _ => stored ?? '',
    };

/// Display label for a sales [PaymentMethod] enum int (widget layer).
String posPaymentMethodLabel(AppLocalizations loc, int method) =>
    switch (method) {
      0 => loc.posCash,
      1 => loc.posMobileMoney,
      2 => loc.posCard,
      3 => loc.posBankTransfer,
      4 => loc.posCredit,
      _ => loc.commonOther,
    };
