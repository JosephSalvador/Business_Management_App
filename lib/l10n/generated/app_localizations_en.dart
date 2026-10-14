// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'JOLINX Business OS';

  @override
  String get loginSubtitle => 'Sign in to your business';

  @override
  String get identifierLabel => 'Email or phone number';

  @override
  String get identifierRequired => 'Enter your email or phone number';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordRequired => 'Enter your password';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get signIn => 'Sign in';

  @override
  String get noAccount => 'No account yet? Register';

  @override
  String get registerTitle => 'Register';

  @override
  String get registerHeading => 'Start your business';

  @override
  String get businessNameOptional => 'Business name (optional)';

  @override
  String get businessNameHelper =>
      'Not decided yet? We will use a placeholder — rename it later';

  @override
  String get fullNameLabel => 'Your full name';

  @override
  String get fullNameRequired => 'Enter your name';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailRequired => 'Enter your email';

  @override
  String get emailInvalid => 'That email is not valid';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneHelper => 'Example: 0712345678 or +255712345678';

  @override
  String get phoneRequired => 'Enter your phone number';

  @override
  String get phoneInvalid => 'That phone number is not valid';

  @override
  String get passwordHelper => 'At least 8 characters';

  @override
  String get passwordTooShort =>
      'Password is too short (at least 8 characters)';

  @override
  String get confirmPasswordLabel => 'Repeat password';

  @override
  String get passwordsDiffer => 'Passwords do not match';

  @override
  String get acceptTermsPrefix => 'I accept the ';

  @override
  String get acceptTermsLink => 'terms and privacy policy';

  @override
  String get acceptTermsSuffix => '.';

  @override
  String get acceptTermsRequired => 'Accept the terms of service to continue.';

  @override
  String get createAccount => 'Create account';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get forgotTitle => 'Forgot password';

  @override
  String get forgotIntro =>
      'Enter the email you registered with. We will send you a reset code.';

  @override
  String get sendCode => 'Send code';

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get resetSentTitle => 'Check your email';

  @override
  String get resetSentBody =>
      'If an account with this email exists, a reset code has been sent to it. Check your inbox (and spam folder).';

  @override
  String get enterResetCode => 'Enter reset code';

  @override
  String get resendCode => 'Resend code';

  @override
  String get resetTitle => 'Reset password';

  @override
  String get resetIntro =>
      'Enter the code we emailed you, then choose a new password.';

  @override
  String get emailLabelPlain => 'Email';

  @override
  String get emailInvalidShort => 'That email is not valid';

  @override
  String get resetCodeLabel => 'Reset code';

  @override
  String get resetCodeDigits => 'The code has 6 digits';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get resetSubmit => 'Reset password';

  @override
  String get resetSuccess => 'Password changed. Please sign in again.';

  @override
  String get strengthWeak => 'Weak';

  @override
  String get strengthFair => 'Fair';

  @override
  String get strengthGood => 'Good';

  @override
  String get strengthStrong => 'Strong';

  @override
  String get showPassword => 'Show';

  @override
  String get hidePassword => 'Hide';

  @override
  String get termsTitle => 'Terms and Privacy';

  @override
  String get termsAccountTitle => 'Your account';

  @override
  String get termsAccountBody =>
      'You are responsible for keeping your password safe. All activity on your account is considered yours.';

  @override
  String get termsDataTitle => 'Business data';

  @override
  String get termsDataBody =>
      'Your business name, products, sales and customers are stored for your business only. You own this data.';

  @override
  String get termsPrivacyTitle => 'Privacy';

  @override
  String get termsPrivacyBody =>
      'We never sell your email or phone number. We use your details to run this service only.';

  @override
  String get termsPaymentsTitle => 'Payments';

  @override
  String get termsPaymentsBody =>
      'If your business pays for the service, payments are handled by a licensed payment provider — we never store your card numbers or PINs.';

  @override
  String get termsOk => 'OK';

  @override
  String get languageSwahili => 'SW';

  @override
  String get languageEnglish => 'EN';

  @override
  String get registerTabOwner => 'Owner';

  @override
  String get registerTabStaff => 'Staff';

  @override
  String get inviteCodeLabel => 'Invitation code';

  @override
  String get inviteCodeHelper => 'Your employer supplied this code';

  @override
  String get inviteCodeRequired => 'Enter your invitation code';

  @override
  String get inviteCodeShort => 'The invitation code has 8 characters';

  @override
  String get staffTitle => 'Team';

  @override
  String get staffHeading => 'Invite a team member';

  @override
  String get staffSubtitle =>
      'Generate a one-time code and give it to your staff. They enter it when registering and join your business directly.';

  @override
  String get generateCode => 'Generate new code';

  @override
  String get generatingCode => 'Generating…';

  @override
  String get yourInviteCode => 'Your invitation code';

  @override
  String get inviteCodeExpires => 'Expires';

  @override
  String get inviteCodeCopied => 'Copied to clipboard';

  @override
  String get copyCode => 'Copy code';

  @override
  String get staffNote =>
      'The code is valid for 72 hours and can only be used once.';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navProducts => 'Products';

  @override
  String get navStock => 'Stock';

  @override
  String get navPOS => 'Sell';

  @override
  String get navReports => 'Reports';

  @override
  String get navMore => 'More';

  @override
  String get navSettings => 'Settings';

  @override
  String get navProfile => 'Profile';

  @override
  String get navUsers => 'Users';

  @override
  String get navRoles => 'Roles';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navSuppliers => 'Suppliers';

  @override
  String get navPurchases => 'Purchases';

  @override
  String get navExpenses => 'Expenses';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navSalesHistory => 'Sales';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardTodaySales => 'Today\'s Sales';

  @override
  String get dashboardTotalProducts => 'Products';

  @override
  String get dashboardRevenue => 'Revenue';

  @override
  String get dashboardQuickActions => 'Quick Actions';

  @override
  String get dashboardLowStock => 'Low Stock';

  @override
  String get dashboardRecentActivity => 'Recent Activity';

  @override
  String get dashboardSellNow => 'Sell now';

  @override
  String get dashboardAddCustomer => 'Add customer';

  @override
  String get dashboardAddExpense => 'Add expense';

  @override
  String get dashboardAddPurchase => 'Add purchase';

  @override
  String get dashboardViewStock => 'Stock';

  @override
  String get dashboardDays7 => '7 days';

  @override
  String get dashboardDays30 => '30 days';

  @override
  String get dashboardBranchInfo => 'Branch';

  @override
  String get dashboardRevenueTrend => 'Revenue Trend';

  @override
  String get dashboardItemsLeft => 'items left';

  @override
  String get dashboardNoActivity => 'No recent activity';

  @override
  String get dashboardErrorLoading => 'Could not load dashboard';

  @override
  String get dashboardTryAgain => 'Try again';

  @override
  String get dashboardGreetingMorning => 'Good morning';

  @override
  String get dashboardGreetingAfternoon => 'Good afternoon';

  @override
  String get dashboardGreetingEvening => 'Good evening';

  @override
  String get dashboardDefaultBranch => 'Your Store';

  @override
  String get dashboardPeriodDay => 'Day';

  @override
  String get dashboardPeriodWeek => 'Week';

  @override
  String get dashboardPeriodMonth => 'Month';

  @override
  String get dashboardPeriodYear => 'Year';

  @override
  String get dashboardPeriodToday => 'Today';

  @override
  String get dashboardPeriodThisMonth => 'This month';

  @override
  String get dashboardRevenueLabel => 'Revenue';

  @override
  String get dashboardTransactionsLabel => 'Transactions';

  @override
  String get dashboardTopProducts => 'Top Products';

  @override
  String get dashboardLowStockAlert => 'Low Stock';

  @override
  String get dashboardOutOfStock => 'Out of stock';

  @override
  String dashboardItemsRemaining(int count) {
    return '$count remaining';
  }

  @override
  String dashboardActivityAdded(String entity) {
    return 'Added $entity';
  }

  @override
  String dashboardActivityUpdated(String entity) {
    return 'Updated $entity';
  }

  @override
  String dashboardActivityDeleted(String entity) {
    return 'Deleted $entity';
  }

  @override
  String dashboardActivityDefault(String action, String entity) {
    return '$action $entity';
  }

  @override
  String dashboardUnitsSold(int count) {
    return '$count units';
  }

  @override
  String get dashboardEmptyTitle => 'Welcome to JOLINX!';

  @override
  String get dashboardEmptyMessage =>
      'Start by adding products and making sales.\nActivity will appear here.';

  @override
  String get dashboardItemUnits => 'units';

  @override
  String get posTitle => 'Point of Sale';

  @override
  String get posSearchProducts => 'Search products...';

  @override
  String get posNoProducts => 'No products yet';

  @override
  String get posNoProductsOffline => 'Products will appear when online';

  @override
  String get posNoSearchResults => 'Product not found';

  @override
  String get posOutOfStock => 'Out of stock';

  @override
  String get posNoPrice => 'No price set';

  @override
  String get posItemsInCart => 'items';

  @override
  String get posPay => 'Pay';

  @override
  String get posTotal => 'Total';

  @override
  String get posPaymentMethod => 'Payment method';

  @override
  String get posCash => 'Cash';

  @override
  String get posMobileMoney => 'Mobile Money';

  @override
  String get posSaleComplete => 'Sale complete';

  @override
  String get posSellAgain => 'Sell again';

  @override
  String get posPrintReceipt => 'Print receipt';

  @override
  String get posShare => 'Share';

  @override
  String get posReceipt => 'Receipt';

  @override
  String get posAmountPaid => 'Amount paid';

  @override
  String get posCashReceived => 'Cash received';

  @override
  String get posChange => 'Change';

  @override
  String get posChangeDue => 'Balance due';

  @override
  String get posCashReceivedHint => 'Enter the money handed over';

  @override
  String get posCart => 'Cart';

  @override
  String get posIncrease => 'Increase';

  @override
  String get posDecrease => 'Decrease';

  @override
  String get posRemove => 'Remove';

  @override
  String get posQuantity => 'Quantity';

  @override
  String get posSetQuantity => 'Set quantity';

  @override
  String get posPricesIncludeTax => 'Prices include tax.';

  @override
  String get posCartTotal => 'Total';

  @override
  String get posContinueToPayment => 'Continue to payment';

  @override
  String get posOfflineSale => 'Offline sale — will sync when online';

  @override
  String get posQuickSale => 'Quick Sale';

  @override
  String get posQuickSaleName => 'Product name';

  @override
  String get posQuickSaleNameRequired => 'Enter a name for this item.';

  @override
  String get posQuickSaleAmount => 'Amount';

  @override
  String get posQuickSaleAdd => 'Add to cart';

  @override
  String get posQuickSaleAddAnother => 'Add another';

  @override
  String get posQuickSaleSell => 'Sell';

  @override
  String get posQuickSaleSaveProduct => 'Save as a product';

  @override
  String get posQuickSaleRecent => 'Recent';

  @override
  String posQuickSaleAddedCount(int count) {
    return '$count added';
  }

  @override
  String get posQuickSaleProductSaved => 'Product saved';

  @override
  String get posQuickSaleProductExists =>
      'This product already exists — no need to save it again.';

  @override
  String posQuickSaleProductSaveFailed(String message) {
    return 'Could not save the product: $message';
  }

  @override
  String get posQuickSaleAmountRequired => 'Enter an amount above zero.';

  @override
  String get posQuickSaleNetFirstTime =>
      'Internet is needed the first time you use Quick Sale.';

  @override
  String get posQuickSaleHint =>
      'Sell any item without a product — set the price yourself';

  @override
  String get posCredit => 'Credit';

  @override
  String get posCreditCustomer => 'Customer';

  @override
  String get posCreditCustomerHint => 'Search customers...';

  @override
  String get posCreditReceived => 'Initial payment';

  @override
  String get posCreditOutstanding => 'Credit remaining';

  @override
  String get posCreditCustomerRequired =>
      'Choose a customer for this credit sale.';

  @override
  String get posCreditNoCustomers =>
      'No customers found. Add them from the Customers tab.';

  @override
  String get posCreditCustomersOffline =>
      'Internet is needed to choose a customer.';

  @override
  String get posEditPrice => 'Edit price';

  @override
  String get posEditPriceHint => 'Enter new price';

  @override
  String get posAddCustomer => 'Add customer';

  @override
  String get posAddCustomerName => 'Customer name';

  @override
  String get posAddCustomerPhone => 'Phone number (optional)';

  @override
  String get posAddCustomerSave => 'Save';

  @override
  String get saleVoid => 'Void sale';

  @override
  String get saleVoidFailed => 'Could not void the sale. Try again.';

  @override
  String get saleVoided => 'Sale voided';

  @override
  String get saleVoidConfirmTitle => 'Void this sale?';

  @override
  String get saleVoidConfirmMessage =>
      'Stock will be added back and the sale removed from your totals. The receipt number is kept for the record.';

  @override
  String get saleVoidReasonHint => 'Reason (required)';

  @override
  String get saleVoidReasonRequired => 'Enter a reason before voiding.';

  @override
  String get saleDetailTitle => 'Sale';

  @override
  String get saleDetailLoadFailed => 'Could not load receipt. Try again.';

  @override
  String get saleSummarySubtotal => 'Subtotal';

  @override
  String get saleSummaryTax => 'Tax (VAT)';

  @override
  String get saleSummaryDiscount => 'Discount';

  @override
  String get saleSummaryTotal => 'TOTAL';

  @override
  String get saleSummaryChange => 'Change';

  @override
  String get salePendingNumber => 'Will be ready later';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get receiptCopy => 'Copy';

  @override
  String get receiptSave => 'Save';

  @override
  String get receiptCopied => 'Receipt copied.';

  @override
  String receiptSaved(String path) {
    return 'Receipt saved: $path';
  }

  @override
  String get receiptSaveFailed => 'Could not save receipt.';

  @override
  String get posSyncPending => 'Sync pending';

  @override
  String get posOfflineProducts => 'Products will appear when online';

  @override
  String get productsTitle => 'Products';

  @override
  String get productsAdd => 'Add product';

  @override
  String get productsSearch => 'Search products...';

  @override
  String get productsEmpty => 'No products yet';

  @override
  String get productsEmptyMessage => 'Add your first product to start selling';

  @override
  String get productsNoResults => 'No products found';

  @override
  String get productsPrice => 'Price';

  @override
  String get productsPriceNotSet => 'Price not set';

  @override
  String get productsStock => 'Stock';

  @override
  String get productsNoStock => 'No stock';

  @override
  String get productsOutOfStock => 'Out of stock';

  @override
  String productsStockLabel(int count) {
    return 'Stock: $count';
  }

  @override
  String get productsClosed => 'Closed';

  @override
  String get productsSKU => 'SKU';

  @override
  String get productsAddStock => 'Add stock';

  @override
  String get productsStockHub => 'Stock';

  @override
  String get productsTotalStock => 'Total Stock';

  @override
  String get productsLowStockCount => 'Low Stock';

  @override
  String get productsZeroStockCount => 'No Stock';

  @override
  String get productsDetailsTitle => 'Product Details';

  @override
  String get productsNotFound => 'Product not found';

  @override
  String get productsRetailPrice => 'Retail Price';

  @override
  String get productsWholesalePrice => 'Wholesale Price';

  @override
  String get productsType => 'Type';

  @override
  String get productsCategory => 'Category';

  @override
  String get productsBrand => 'Brand';

  @override
  String get productsUnit => 'Unit';

  @override
  String get productsDescription => 'Description';

  @override
  String get addStockTitle => 'Add stock';

  @override
  String addStockProduct(String name) {
    return 'Product: $name';
  }

  @override
  String get addStockQuantity => 'Quantity';

  @override
  String get addStockWarehouse => 'Warehouse: Main Store';

  @override
  String get addStockSave => 'Save';

  @override
  String get addStockInvalidQuantity =>
      'Enter a valid quantity (greater than zero).';

  @override
  String get addStockWarehouseUnavailable =>
      'No storage location available. Try again.';

  @override
  String get stockPageTitle => 'Stock';

  @override
  String get stockPageEmpty => 'No stock yet. Start by adding products.';

  @override
  String get stockPageRetry => 'Try again';

  @override
  String get openingStockTitle => 'Opening Stock';

  @override
  String get openingStockReason => 'Opening stock';

  @override
  String get openingStockDuplicate =>
      'Opening stock has already been recorded for this product.';

  @override
  String get productFormTitleNew => 'New product';

  @override
  String get productFormTitleEdit => 'Edit product';

  @override
  String get productFormName => 'Product name';

  @override
  String get productFormNameHint => 'Example: Rice';

  @override
  String get productFormNameRequired => 'Name is required.';

  @override
  String get productFormPrice => 'Selling price';

  @override
  String get productFormPriceRequired =>
      'Enter a valid price (greater than zero).';

  @override
  String get productFormUnit => 'Unit';

  @override
  String get productFormUnitRequired => 'Choose a unit.';

  @override
  String get productFormGoods => 'Product';

  @override
  String get productFormService => 'Service';

  @override
  String get productFormAdvanced => 'Advanced (optional)';

  @override
  String get productFormWholesalePrice => 'Wholesale price';

  @override
  String get productFormCategory => 'Category';

  @override
  String get productFormBrand => 'Brand';

  @override
  String get productFormSku => 'SKU';

  @override
  String get productFormBarcode => 'Barcode';

  @override
  String get productFormOptional => 'Optional';

  @override
  String get productFormDescription => 'Description';

  @override
  String get productFormSave => 'Save';

  @override
  String get productFormSaveEdit => 'Save changes';

  @override
  String get productFormSaved => 'Saved!';

  @override
  String get productFormDuplicate =>
      'A product with this SKU or barcode already exists.';

  @override
  String get productFormForbidden =>
      'You do not have permission to change products.';

  @override
  String get productFormNetwork =>
      'No internet. Check your connection and try again.';

  @override
  String get customersTitle => 'Customers';

  @override
  String get customersAdd => 'Add customer';

  @override
  String get customersSearch => 'Search customers...';

  @override
  String get customersEmpty => 'No customers yet';

  @override
  String get customersEmptyMessage => 'Add your first customer to track sales';

  @override
  String get customersDebtors => 'Who owes you?';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsSalesSummary => 'Sales Summary';

  @override
  String get reportsPeriodToday => 'Today';

  @override
  String get reportsPeriodThisWeek => 'This week';

  @override
  String get reportsPeriodThisMonth => 'This month';

  @override
  String get reportsPeriodLastMonth => 'Last month';

  @override
  String get reportsRevenue => 'Revenue';

  @override
  String get reportsAverageSale => 'Average sale';

  @override
  String get reportsSaleCount => 'Sales count';

  @override
  String get reportsTrendLast7Days => 'Last 7 days';

  @override
  String get reportsSoldLabel => 'sold';

  @override
  String get dashboardCachedBanner =>
      'Viewing offline data (cached). Pull to refresh when connected.';

  @override
  String get dashboardUpdatedJustNow => 'Just now';

  @override
  String get reportsProfitLabel => 'Profit';

  @override
  String get reportsLossLabel => 'Loss';

  @override
  String get reportsCostLabel => 'Cost';

  @override
  String get reportsTopProducts => 'Top Products';

  @override
  String get reportsSeeAll => 'See all';

  @override
  String get reportsNoSalesData => 'No sales data yet';

  @override
  String get reportsQuickActions => 'Quick Actions';

  @override
  String get reportsPurchases => 'Purchases';

  @override
  String get reportsExpenses => 'Expenses';

  @override
  String get salesHistoryTitle => 'Sales';

  @override
  String get salesHistoryToday => 'Today';

  @override
  String get salesHistoryYesterday => 'Yesterday';

  @override
  String get salesHistoryPickDate => 'Pick a date';

  @override
  String get salesHistorySearchHint => 'Search receipt number';

  @override
  String get salesHistoryEmptyDay => 'No sales on this day.';

  @override
  String get salesHistoryEmptySearch => 'No sales match your search.';

  @override
  String get salesHistoryNoNumber => '(receipt pending)';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsBusinessInfo => 'Business Information';

  @override
  String get settingsBusinessName => 'Business name';

  @override
  String get settingsAddress => 'Address';

  @override
  String get settingsPhone => 'Phone';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsTax => 'Tax';

  @override
  String get settingsTIN => 'TIN';

  @override
  String get settingsCountry => 'Country';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get settingsPersonalInfo => 'Personal Information';

  @override
  String get settingsProfile => 'Profile';

  @override
  String get settingsEditProfile => 'Edit your profile';

  @override
  String get settingsChangePassword => 'Change Password';

  @override
  String get settingsUpdatePassword => 'Update your password';

  @override
  String get settingsApp => 'App';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsEditBusiness => 'Edit business information';

  @override
  String get settingsSaved => 'Saved!';

  @override
  String get moreTitle => 'More';

  @override
  String get moreQuickAccess => 'Quick Access';

  @override
  String get moreManagement => 'Management';

  @override
  String get moreTeam => 'Team';

  @override
  String get moreLogout => 'Sign out';

  @override
  String get moreLogoutConfirm => 'Sign out?';

  @override
  String get moreLogoutPendingSales =>
      'You have pending sales that will sync when online';

  @override
  String get moreLogoutMessage => 'Do you want to sign out?';

  @override
  String get moreLogoutStay => 'Stay';

  @override
  String get moreCopyright => '2026 Jolinx Business OS';

  @override
  String get moreTagline => 'Your business system, anywhere you go.';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonDone => 'Done';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get mfaTitle => 'Two-factor verification';

  @override
  String mfaCodeForAccount(Object email) {
    return 'Enter the code for $email';
  }

  @override
  String get mfaCodePrompt => 'Enter the code from your authenticator app.';

  @override
  String get mfaCodeLabel => 'Verification code';

  @override
  String get mfaRecoveryCodeLabel => 'Recovery code';

  @override
  String get mfaRecoveryCodeHint => 'Each recovery code works once.';

  @override
  String get mfaTotpHint => 'The code refreshes every 30 seconds.';

  @override
  String get mfaUseAuthenticator => 'I\'m using an authenticator app';

  @override
  String get mfaUseRecoveryCode => 'Locked out? Use a recovery code';

  @override
  String get mfaBackToLogin => 'Back to sign in';

  @override
  String get securityTitle => 'Security';

  @override
  String get securityTwoFactorSection => 'Two-factor verification';

  @override
  String get securityTwoFactorOn => 'On';

  @override
  String get securityTwoFactorOff => 'Off';

  @override
  String securityTwoFactorSince(Object date) {
    return 'On since $date';
  }

  @override
  String get securityTwoFactorRecommended => 'Recommended for your role';

  @override
  String get securityTwoFactorTurnOn => 'Turn on';

  @override
  String get securityTwoFactorTurnOff => 'Turn off';

  @override
  String get securityTwoFactorSetupTitle => 'Set up your authenticator';

  @override
  String get securityTwoFactorScanTitle =>
      'Scan this in your authenticator app';

  @override
  String get securityTwoFactorManualKey =>
      'Can\'t scan? Enter this key by hand:';

  @override
  String get securityTwoFactorThenConfirm =>
      'Then enter the 6-digit code it shows.';

  @override
  String get securityTwoFactorEnabled => 'Two-factor verification is on.';

  @override
  String get securityTwoFactorDisabled => 'Two-factor verification is off.';

  @override
  String get securityRecoveryCodesTitle => 'Recovery codes';

  @override
  String get securityRecoveryCodesIntro =>
      'Save these somewhere safe. Each one signs you in once if you lose your device.';

  @override
  String get securityRecoveryCodesSaved => 'I have saved my codes';

  @override
  String securityRecoveryCodesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count codes left',
      one: '1 code left',
      zero: 'No codes left',
    );
    return '$_temp0';
  }

  @override
  String get securitySessionsSection => 'Signed-in devices';

  @override
  String get securitySessionsIntro =>
      'If you do not recognise a device, sign it out.';

  @override
  String get securitySessionCurrent => 'This device';

  @override
  String get securitySessionSignOut => 'Sign out';

  @override
  String get securitySessionSignOutAll => 'Sign out of all devices';

  @override
  String get securitySessionsEmpty => 'No other devices are signed in.';

  @override
  String get securityDisableConfirm => 'Enter a current code to turn this off.';

  @override
  String get splashStarting => 'Starting up...';

  @override
  String get splashAppName => 'JOLINX Business OS';

  @override
  String get splashTagline => 'Your business, your way';

  @override
  String get splashOffline => 'Offline';

  @override
  String get splashOfflineMessage => 'Products will load when you are online';

  @override
  String get expenseTitle => 'Expenses';

  @override
  String get expenseSearchHint => 'Search expenses...';

  @override
  String get expenseToday => 'Today';

  @override
  String get expenseYesterday => 'Yesterday';

  @override
  String get expenseThisMonth => 'This month';

  @override
  String get expenseAllTime => 'All time';

  @override
  String get expensePickRange => 'Pick date range';

  @override
  String get expenseSummaryTitle => 'Spending summary';

  @override
  String get expenseSummaryEmpty => 'No spending in this period';

  @override
  String get expenseEmpty => 'No expenses yet';

  @override
  String get expenseEmptyMessage =>
      'Record your daily outflows and keep track of cash.';

  @override
  String get expenseEmptySearch => 'No expenses match your search';

  @override
  String get expenseAdd => 'Add expense';

  @override
  String get expenseAddTitle => 'Add expense';

  @override
  String get expenseEditTitle => 'Edit expense';

  @override
  String get expenseDescription => 'Description *';

  @override
  String get expenseDescriptionRequired => 'Description is required';

  @override
  String get expenseAmount => 'Amount *';

  @override
  String get expenseAmountRequired => 'Amount is required';

  @override
  String get expenseAmountInvalid => 'Invalid amount';

  @override
  String get expenseDate => 'Date';

  @override
  String get expenseCategory => 'Category';

  @override
  String get expenseCategoryNone => 'No category';

  @override
  String get expenseCategoryAdd => 'Add category';

  @override
  String get expenseNewCategoryTitle => 'New category';

  @override
  String get expenseCategoryName => 'Category name';

  @override
  String get expenseCategoryRequired => 'Category name is required';

  @override
  String get expensePaymentMethod => 'Payment method';

  @override
  String get expenseReference => 'Reference';

  @override
  String get expenseNotes => 'Additional notes';

  @override
  String get expenseDeleteConfirmTitle => 'Delete this expense?';

  @override
  String get expenseDeleteConfirmMessage => 'This cannot be undone.';

  @override
  String get expenseSaved => 'Expense saved';

  @override
  String get expenseLoadMore => 'Loading more...';

  @override
  String get posPrintSuccess => 'Receipt sent to printer.';

  @override
  String get posPrintFailed => 'Printing failed. Check printer connection.';

  @override
  String get posShareText => 'Copy receipt (text)';

  @override
  String get reportsHubTitle => 'Reports';

  @override
  String get reportsBusinessOverview => 'Business Overview';

  @override
  String get reportsSales => 'Sales';

  @override
  String get reportsStock => 'Stock';

  @override
  String get reportsMoney => 'Money';

  @override
  String get reportsPurchasesReport => 'Purchases';

  @override
  String get reportsExpensesReport => 'Expenses';

  @override
  String get reportsGrossProfit => 'Gross Profit';

  @override
  String get reportsExpensesLabel => 'Expenses';

  @override
  String get reportsMoneyBalance => 'Money Balance';

  @override
  String get reportsSalesPerformance => 'Sales Performance';

  @override
  String get reportsStockOverview => 'Stock Overview';

  @override
  String get reportsMoneyMovement => 'Money Movement';

  @override
  String get reportsPurchasesOverview => 'Purchases Overview';

  @override
  String get reportsExpensesOverview => 'Expenses Overview';

  @override
  String get reportsByPaymentMethod => 'By Payment Method';

  @override
  String get reportsByCategory => 'By Category';

  @override
  String get reportsByStaff => 'By Staff';

  @override
  String get reportsByCustomer => 'By Customer';

  @override
  String get reportsBySupplier => 'By Supplier';

  @override
  String get reportsStartingBalance => 'Starting Balance';

  @override
  String get reportsMoneyIn => 'Money In';

  @override
  String get reportsMoneyOut => 'Money Out';

  @override
  String get reportsCurrentBalance => 'Current Balance';

  @override
  String get reportsTotalPurchased => 'Total Purchased';

  @override
  String get reportsSuppliers => 'Suppliers';

  @override
  String get reportsItemsReceived => 'Items Received';

  @override
  String get reportsTopSupplier => 'Top Supplier';

  @override
  String get reportsPendingOrders => 'Pending Orders';

  @override
  String get reportsReceivedOrders => 'Received Orders';

  @override
  String get reportsTotalExpenses => 'Total Expenses';

  @override
  String get reportsCategoryBreakdown => 'Category Breakdown';

  @override
  String get reportsTrend => 'Trend';

  @override
  String get reportsStockSummary => 'Stock Summary';

  @override
  String get reportsOpening => 'Opening';

  @override
  String get reportsPurchased => 'Purchased';

  @override
  String get reportsSold => 'Sold';

  @override
  String get reportsAdjusted => 'Adjusted';

  @override
  String get reportsClosing => 'Closing';

  @override
  String get reportsLowStock => 'Low Stock';

  @override
  String get reportsStockVelocity => 'Stock Velocity';

  @override
  String get reportsMovementType => 'Movement Type';

  @override
  String get reportsMovementCount => 'Count';

  @override
  String get reportsTotalQuantity => 'Total Quantity';

  @override
  String get reportsOnHand => 'On Hand';

  @override
  String get reportsVelocityPerDay => 'Per Day';

  @override
  String get reportsExportCsv => 'Export CSV';

  @override
  String get reportsExportPdf => 'Export PDF';

  @override
  String get reportsNoData => 'No data available';

  @override
  String get reportsComparedTo => 'compared to';

  @override
  String get reportsPreviousPeriod => 'previous period';

  @override
  String get reportsSeeDetails => 'See details';

  @override
  String get reportsViewAll => 'View all';

  @override
  String get reportsFilterPeriod => 'Period';

  @override
  String get reportsFilterLocation => 'Location';

  @override
  String get reportsFilterStaff => 'Staff';

  @override
  String get reportsFilterCategory => 'Category';

  @override
  String get reportsFilterPayment => 'Payment';

  @override
  String get reportsAllLocations => 'All Locations';

  @override
  String get reportsAllStaff => 'All Staff';

  @override
  String get reportsAllCategories => 'All Categories';

  @override
  String get reportsAllMethods => 'All Methods';

  @override
  String get reportsCustomRange => 'Custom Range';

  @override
  String get reportsReceipt => 'Receipt';

  @override
  String get reportsCustomer => 'Customer';

  @override
  String get reportsAmount => 'Amount';

  @override
  String get reportsProduct => 'Product';

  @override
  String get reportsQuantity => 'Quantity';

  @override
  String get reportsRevenueLabel => 'Revenue';

  @override
  String get reportsCash => 'Cash';

  @override
  String get reportsMobileMoney => 'Mobile Money';

  @override
  String get reportsCredit => 'Credit';

  @override
  String get reportsWalkIn => 'Walk-in';

  @override
  String get stockReasonRequired => 'Please select a reason for adding stock';

  @override
  String get stockReasonLabel => 'Reason';

  @override
  String get stockUnitCostOptional => 'Unit cost (optional)';

  @override
  String get productFormCostPrice => 'Cost price';

  @override
  String get productFormCostPriceHint => 'How much you pay to buy this product';

  @override
  String get productFormCostPriceInvalid => 'Cost price cannot be negative';

  @override
  String get productFormCostPriceGuidance => 'Required to calculate real profit and inventory valuation.';

  @override
  String get navHome => 'Home';

  @override
  String get navPos => 'Sell';

  @override
  String get navInvoices => 'Invoices';

  @override
  String get invoicesTitle => 'Invoices';

  @override
  String get invoicesEmpty => 'No invoices yet';

  @override
  String get invoicesEmptyMessage =>
      'Invoices you issue for your customers appear here.';

  @override
  String get invoicesAdd => 'New invoice';

  @override
  String get invoicesSearch => 'Search customer or number';

  @override
  String get invoicesFilterAll => 'All';

  @override
  String get invoiceStatusUnpaid => 'Unpaid';

  @override
  String get invoiceStatusPartial => 'Partially paid';

  @override
  String get invoiceStatusPaid => 'Paid';

  @override
  String get invoiceStatusVoid => 'Void';

  @override
  String get invoiceNumber => 'Number';

  @override
  String get invoiceCustomer => 'Customer';

  @override
  String get invoiceWalkIn => 'Walk-in customer';

  @override
  String get invoiceBalance => 'Balance';

  @override
  String get invoiceTotal => 'Total';

  @override
  String get invoiceNewTitle => 'New invoice';

  @override
  String get invoiceLineDescription => 'Description';

  @override
  String get invoiceLineQuantity => 'Quantity';

  @override
  String get invoiceLineUnitPrice => 'Unit price';

  @override
  String get invoiceLineTaxRate => 'Tax %';

  @override
  String get invoiceAddLine => 'Add line';

  @override
  String get invoiceRemoveLine => 'Remove line';

  @override
  String get invoiceNotes => 'Notes';

  @override
  String get invoiceDueDate => 'Due date';

  @override
  String get invoiceSave => 'Save invoice';

  @override
  String get invoiceDetailTitle => 'Invoice';

  @override
  String get invoiceRecordPayment => 'Record payment';

  @override
  String get invoicePaymentAmount => 'Amount paid';

  @override
  String get invoicePaymentMethod => 'Method';

  @override
  String get invoicePaymentReference => 'Reference';

  @override
  String get invoiceVoid => 'Void invoice';

  @override
  String get invoiceVoidConfirm =>
      'Void this invoice? Money still outstanding is written off.';

  @override
  String get packagesTitle => 'Add-ons';

  @override
  String get packagesActive => 'Active add-ons';

  @override
  String get packagesAvailable => 'Available add-ons';

  @override
  String get packagesActivate => 'Activate';

  @override
  String get packagesRemove => 'Remove';

  @override
  String get packagesNone => 'No add-on is active on this workspace.';

  @override
  String get packagesInvoiceManagerName => 'Invoicing';

  @override
  String get packagesInvoiceManagerDescription =>
      'Bill customers with invoices, take part payments and void mistakes.';

  @override
  String get packagesRequiresBillingManage =>
      'You need the Billing.Manage permission to change add-ons.';

  @override
  String get moduleLockedTitle => 'Module not available';

  @override
  String get moduleLockedMessage =>
      'This part of the app needs a package that is not active on this workspace.';

  @override
  String get moduleLockedGoToBilling => 'Go to billing';

  @override
  String get moduleLockedBack => 'Back';

  @override
  String get capabilitiesOffline => 'Showing the modules from your last sync.';

  @override
  String get packageInvoiceManagerRequired =>
      'Invoicing needs the invoice-manager add-on.';

  @override
  String get commonOther => 'Other';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonChange => 'Change';

  @override
  String get commonAmount => 'Amount';

  @override
  String commonWithError(String error) {
    return 'Error: $error';
  }

  @override
  String get profileTitle => 'My Profile';

  @override
  String get profileChangeName => 'Change Name';

  @override
  String get profileChangeNameTitle => 'Change Name';

  @override
  String get profileCurrentName => 'Current Name';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profileNameRequired => 'Name is required';

  @override
  String get profileAddPhone => 'Add Phone';

  @override
  String get profileBusiness => 'Business';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileChangePhoneTitle => 'Change Phone';

  @override
  String get profileCurrentPhone => 'Current Phone';

  @override
  String get profilePhoneRequired => 'Phone number is required';

  @override
  String get profileChangePasswordTitle => 'Change Password';

  @override
  String get profileCurrentPassword => 'Current Password';

  @override
  String get profileNewPassword => 'New Password';

  @override
  String get profileRepeatPassword => 'Repeat Password';

  @override
  String get profilePasswordsMismatch => 'Passwords do not match or are empty';

  @override
  String get profileChangeAction => 'Change';

  @override
  String get profileSaved => 'Saved!';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeSystem => 'Follow device';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsTimezone => 'Timezone';

  @override
  String get settingsPhoneEmail => 'Phone and Email';

  @override
  String get settingsAppearancePicker => 'Choose Appearance';

  @override
  String get settingsThemeAlwaysLight => 'Always light';

  @override
  String get settingsThemeAlwaysDark => 'Always dark';

  @override
  String get settingsLanguagePicker => 'Choose Language';

  @override
  String get purchasesTitle => 'Purchases';

  @override
  String get purchasesSearchHint => 'Search purchases...';

  @override
  String get purchasesAdd => 'Add Purchase';

  @override
  String get purchasesReference => 'Reference';

  @override
  String get purchasesNotes => 'Notes';

  @override
  String get purchasesEmptyLines => 'No products added yet';

  @override
  String get purchasesLinesRequired => 'Add at least one product';

  @override
  String get purchasesSupplier => 'Supplier *';

  @override
  String get purchasesSupplierRequired => 'Supplier is required';

  @override
  String get purchasesOffice => 'Office *';

  @override
  String get purchasesOfficeRequired => 'Office is required';

  @override
  String get purchasesLineQuantity => 'Quantity';

  @override
  String get purchasesLineUnitPrice => 'Unit Price';

  @override
  String get purchasesSaved => 'Saved!';

  @override
  String get purchasesDetailTitle => 'Purchase Details';

  @override
  String get purchasesDetailNotFound => 'Purchase not found';

  @override
  String get purchasesOrderLabel => 'Order';

  @override
  String get purchasesEmpty => 'No purchases yet';

  @override
  String get purchasesEmptyMessage => 'Start buying products from suppliers.';

  @override
  String get purchasesDetailDate => 'Date';

  @override
  String get purchasesDetailOffice => 'Office';

  @override
  String get purchasesDetailProducts => 'Products';

  @override
  String get purchasesSubmit => 'Submit';

  @override
  String get purchasesSubmitted => 'Submitted!';

  @override
  String get purchasesCancelled => 'Cancelled!';

  @override
  String get pinSave => 'Save PIN';

  @override
  String get pinUnlock => 'Unlock';

  @override
  String get pinTitle => 'Enter your PIN';

  @override
  String get pinUnlockTitle => 'Unlock with PIN';

  @override
  String get pinSetupTitle => 'Set Your PIN';

  @override
  String get pinSetupHint =>
      'This PIN unlocks the app quickly. It is not used for your online account.';

  @override
  String get pinLabel => 'PIN';

  @override
  String get pinHint => 'Enter your 4 to 6 digit PIN.';

  @override
  String get pinRepeat => 'Repeat PIN';

  @override
  String get pinMismatch => 'PINs do not match.';

  @override
  String get pinLengthError => 'PIN must be 4 to 6 digits.';

  @override
  String get pinRequired => 'Enter your PIN.';

  @override
  String get pinSaved => 'PIN saved.';

  @override
  String get supplierFormTitleAdd => 'Add Supplier';

  @override
  String get supplierFormTitleEdit => 'Edit Supplier';

  @override
  String get supplierFormName => 'Supplier Name *';

  @override
  String get supplierFormNameRequired => 'Name is required';

  @override
  String get supplierFormContact => 'Contact Name';

  @override
  String get suppliersSearchHint => 'Search suppliers...';

  @override
  String get supplierFormSaved => 'Saved!';

  @override
  String get suppliersTitle => 'Suppliers';

  @override
  String get suppliersAdd => 'Add Supplier';

  @override
  String get suppliersEmpty => 'No suppliers yet';

  @override
  String get suppliersEmptyMessage => 'Add suppliers to start buying products.';

  @override
  String get customerFormTitleAdd => 'Add Customer';

  @override
  String get customerFormTitleEdit => 'Edit Customer';

  @override
  String get customerFormName => 'Customer Name *';

  @override
  String get customerFormNameRequired => 'Name is required';

  @override
  String get customerFormVatRegistered => 'VAT Registered';

  @override
  String get customerFormSaved => 'Saved!';

  @override
  String get customerDetailTitle => 'Customer Details';

  @override
  String get customerDetailNotFound => 'Customer not found';

  @override
  String get customerDetailDebt => 'Debt';

  @override
  String get customerDetailDebtTitle => 'Customer Debt';

  @override
  String get customerDetailLimit => 'Limit';

  @override
  String get customerDetailNoNotes => 'No notes';

  @override
  String get customerDetailPayDebt => 'Pay Debt';

  @override
  String get customerDetailSales => 'Customer Sales';

  @override
  String get customerDetailNoSales => 'No sales yet';

  @override
  String get customerDetailAddSale => 'Add sale';

  @override
  String get customerDebtPaid => 'Debt paid';

  @override
  String get userFormTitleAdd => 'Add User';

  @override
  String get userFormTitleEdit => 'Edit User';

  @override
  String get userFormEmail => 'Email *';

  @override
  String get userFormEmailRequired => 'Email is required';

  @override
  String get userFormName => 'Full Name *';

  @override
  String get userFormNameRequired => 'Name is required';

  @override
  String get userFormNameTooLong => 'Name is too long';

  @override
  String get userFormRoles => 'Roles';

  @override
  String get userFormNoRoles => 'No roles found';

  @override
  String get userFormSaved => 'Saved!';

  @override
  String get roleFormTitleAdd => 'Add Role';

  @override
  String get roleFormTitleEdit => 'Edit Role';

  @override
  String get roleFormName => 'Role Name *';

  @override
  String get roleFormNameRequired => 'Name is required';

  @override
  String get roleFormDescription => 'Description';

  @override
  String get roleFormPermissions => 'Permissions';

  @override
  String get roleFormNoPermissions => 'No permissions found';

  @override
  String get roleFormSystemAdminNote =>
      'Administrator is a system role. You cannot rename or delete it. Change its permissions carefully; removing admin permissions may lock you out of managing this business.';

  @override
  String get roleFormSystemNote =>
      'This is a system role. You cannot rename or delete it, but you can adjust its permissions.';

  @override
  String get roleFormSaved => 'Saved!';

  @override
  String get usersTitle => 'Users';

  @override
  String get usersActivate => 'Activate';

  @override
  String get usersDeactivate => 'Deactivate';

  @override
  String get usersDelete => 'Delete';

  @override
  String get usersDeleteTitle => 'Delete User?';

  @override
  String usersDeleteMessage(String name) {
    return 'Are you sure you want to delete $name?';
  }

  @override
  String get usersDeleteConfirm => 'Delete';

  @override
  String get rolesStarterBadge => 'Starter role — you can edit or delete it';

  @override
  String rolesPermissionCount(String count) {
    return '$count permissions';
  }

  @override
  String get rolesDeleteTitle => 'Delete Role?';

  @override
  String rolesDeleteMessage(String name) {
    return 'Are you sure you want to delete the role \"$name\"? Users with this role will be unassigned.';
  }

  @override
  String get recordIncomeTitle => 'Add Income';

  @override
  String get recordExpenseTitle => 'Add Expense';

  @override
  String get recordExpenseSuccess => 'Expense recorded';

  @override
  String get recordIncomeSuccess => 'Income recorded';

  @override
  String get recordAmountLabel => 'Amount (TSh) *';

  @override
  String get recordAmountRequired => 'Enter the amount';

  @override
  String get recordAmountPositive => 'Amount must be positive';

  @override
  String get recordDescriptionLabel => 'Description *';

  @override
  String get recordDescriptionRequired => 'Enter a description';

  @override
  String get recordNotes => 'Notes';

  @override
  String get recordPaymentTitle => 'Pay Debt';

  @override
  String get recordPaymentAmountLabel => 'Amount (TSh)';

  @override
  String get recordPaymentExceeds => 'Amount cannot exceed the debt';

  @override
  String get recordPaymentConfirm => 'Confirm Payment';

  @override
  String get recordPay => 'Pay';

  @override
  String get recordPaymentSuccess => 'Payment recorded';

  @override
  String get outstandingTitle => 'Who owes you?';

  @override
  String get outstandingEmpty => 'No debt yet';

  @override
  String get outstandingTotal => 'Total Debt';

  @override
  String outstandingCustomer(String id) {
    return 'Customer $id';
  }

  @override
  String outstandingLastPayment(String date) {
    return 'Last payment: $date';
  }

  @override
  String get outstandingError => 'Could not load outstanding credits.';

  @override
  String get outstandingPay => 'Pay';

  @override
  String get verifyTitle => 'Verify';

  @override
  String get verifyProgress => 'Verifying...';

  @override
  String get verifyResend => 'Send again';

  @override
  String verifyResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get verifyCodeHint => 'Enter the code sent to your email';

  @override
  String get verifyIncorrect => 'Your account is not verified yet.';

  @override
  String get createBusinessTitle => 'Start Business';

  @override
  String get createBusinessName => 'Business Name *';

  @override
  String get createBusinessNameRequired => 'Business name is required';

  @override
  String get createBusinessType => 'Business Type';

  @override
  String get createBusinessTypeRequired => 'Choose a business type';

  @override
  String get createBusinessCountry => 'Country';

  @override
  String get createBusinessCurrency => 'Currency';

  @override
  String get createBusinessPhone => 'Contact Phone';

  @override
  String get createBusinessTin => 'TIN (optional)';

  @override
  String get createBusinessStart => 'Complete';

  @override
  String get createBusinessSaved => 'Success!';

  @override
  String get businessTypeRetail => 'Retail';

  @override
  String get businessTypeWholesale => 'Wholesale';

  @override
  String get businessTypeServices => 'Services';

  @override
  String get businessTypeHospitality => 'Hospitality';

  @override
  String get businessTypeAgriculture => 'Agriculture';

  @override
  String get businessTypeOther => 'Other';

  @override
  String get businessSetupTitle => 'Let\'s Set Up Your Business';

  @override
  String get businessSetupWelcome =>
      'Welcome! Your business has been registered.';

  @override
  String get businessSetupBusiness => 'Business';

  @override
  String get businessSetupType => 'Type';

  @override
  String get businessSetupUnitsReady =>
      'Units of measure and warehouse are ready.';

  @override
  String get businessSetupUnitsFailed =>
      'Failed to prepare units of measure. Try again later.';

  @override
  String get businessSetupPreparing => 'Preparing standard units of measure…';

  @override
  String get businessSetupAddProducts => 'Start Adding Products';

  @override
  String get businessSetupLater => 'Later';

  @override
  String get businessSetupSuccess => 'Success!';

  @override
  String get zeroWorkspaceTitle => 'You Haven\'t Started a Business Yet';

  @override
  String get zeroWorkspaceBody =>
      'Start by filling in your business details — name, business type, country and currency.';

  @override
  String get zeroWorkspaceStart => 'Start Business';

  @override
  String get workspacePickerTitle => 'Your Businesses';

  @override
  String get workspacePickerIncomplete => 'Incomplete';

  @override
  String get splashNetworkError => 'Network Error';

  @override
  String get loginAnotherUser => 'Someone else? ';

  @override
  String get loginUseBiometricPin => 'Use Fingerprint or PIN';

  @override
  String get loginOtherAccount => 'Someone else? Sign in to your account';

  @override
  String loginGreeting(String name) {
    return 'Hello, $name!';
  }

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginVerifyIdentity => 'Verify your identity to sign in';

  @override
  String get lockWelcomeBack => 'Welcome Back';

  @override
  String get lockLocked => 'App is locked for security';

  @override
  String get lockVerifyToContinue => 'Verify your identity to continue';

  @override
  String get lockUnlockFailed => 'Not able to unlock. Try your password.';

  @override
  String get lockSignInPassword => 'Sign in with password';

  @override
  String get lockPasswordOrPin => 'Sign in with password or PIN';

  @override
  String get lockUsePin => 'Use PIN';

  @override
  String get lockUseFingerprint => 'Use Fingerprint';

  @override
  String get lockSwitchMethod => 'Switch method';

  @override
  String get fastUnlockFingerprint => 'Unlock with Fingerprint';

  @override
  String get fastUnlockVerifying => 'Verifying…';

  @override
  String get fastUnlockBiometricHint => 'Use fingerprint or face';

  @override
  String get fastUnlockOrPin => 'or enter your PIN';

  @override
  String get fastUnlockEnterPin => 'Enter your PIN';

  @override
  String get verifyEmailTitle => 'Verify email';

  @override
  String get verifyEmailIntro => 'We sent a verification code to:';

  @override
  String get verifyEmailCodeLabel => 'Verification code';

  @override
  String get verifyEmailCodeInvalid => 'Enter the 6-digit code';

  @override
  String get verifyEmailResendNew => 'Send a new code';

  @override
  String verifyEmailResendNewCountdown(String seconds) {
    return 'Send a new code (${seconds}s)';
  }

  @override
  String get verifyEmailNewCodeSent =>
      'A new code has been sent to your email.';

  @override
  String get verifyEmailRateLimited =>
      'Please wait before requesting another code.';

  @override
  String get syncStatusAvailable => 'Internet: Available';

  @override
  String get syncStatusOffline => 'Internet: Offline';

  @override
  String get syncStatusUnreachable => 'Internet: Unreachable';

  @override
  String get syncStatusChecking => 'Internet: Checking...';

  @override
  String get posCard => 'Card';

  @override
  String get posBankTransfer => 'Bank Transfer';

  @override
  String get posOther => 'Other';

  @override
  String get entitySale => 'Sale';

  @override
  String get entityProduct => 'Product';

  @override
  String get entityCustomer => 'Customer';

  @override
  String get entityExpense => 'Expense';

  @override
  String get entityPurchase => 'Purchase';

  @override
  String get permAccounting => 'Accounting';

  @override
  String get permAudit => 'Audit';

  @override
  String get permBranches => 'Branches';

  @override
  String get permBrands => 'Brands';

  @override
  String get permCategories => 'Categories';

  @override
  String get permCustomers => 'Customers';

  @override
  String get permDashboard => 'Dashboard';

  @override
  String get permExpenses => 'Expenses';

  @override
  String get permInventory => 'Inventory';

  @override
  String get permOrganizations => 'Organizations';

  @override
  String get permPricing => 'Pricing';

  @override
  String get permProducts => 'Products';

  @override
  String get permPurchasing => 'Purchasing';

  @override
  String get permReceipts => 'Receipts';

  @override
  String get permRoles => 'Roles';

  @override
  String get permSales => 'Sales';

  @override
  String get permUnits => 'Units';

  @override
  String get permUsers => 'Users';

  @override
  String get permWarehouses => 'Warehouses';

  @override
  String get moneyAccountsTitle => 'Money Accounts';

  @override
  String get moneyAccountsSearchHint => 'Search accounts...';

  @override
  String get moneyAccountsTotalBalance => 'Total Balance';

  @override
  String get moneyAccountsEmpty => 'No money accounts yet';

  @override
  String get moneyAccountsEmptyMessage => 'Add a cash, M-Pesa or bank account.';

  @override
  String get moneyAccountsInactive => 'Inactive';

  @override
  String get moneyAccountTitle => 'Account';

  @override
  String get moneyAccountNotFound => 'Account not found';

  @override
  String get moneyAccountInactive => 'Account inactive';

  @override
  String get moneyAccountRecentActivity => 'Recent Transactions';

  @override
  String get moneyAccountAddIncome => 'Add Income';

  @override
  String get moneyAccountAddExpense => 'Add Expense';

  @override
  String get moneyAccountTransfer => 'Transfer Money';

  @override
  String get moneyAccountUpdate => 'Update';

  @override
  String get moneyAccountNoActivity => 'No transactions yet';

  @override
  String get moneyAccountBalance => 'Balance';

  @override
  String get moneyAccountSaved => 'Account added!';

  @override
  String get moneyTransactionIncoming => 'Incoming';

  @override
  String get moneyTransactionOutgoing => 'Outgoing';

  @override
  String get moneyTransactionTransfer => 'Transfer';

  @override
  String get cashTitle => 'Cash Session';

  @override
  String get cashOpenNew => 'Open New Session';

  @override
  String get cashCloseDialogHint => 'Enter the cash you have left.';

  @override
  String get cashOpenInstructions =>
      'Enter the cash you have before you start selling.';

  @override
  String get cashOpenBadge => 'Session Open';

  @override
  String get cashOpeningAmount => 'Opening Amount';

  @override
  String cashOpenedAt(String time) {
    return 'Opened: $time';
  }

  @override
  String get cashCloseSession => 'Close Session';

  @override
  String get cashClosedHeader => 'Session Closed';

  @override
  String get cashClosedBadge => 'Closed';

  @override
  String get cashClosingAmount => 'Closing Amount';

  @override
  String get cashExpected => 'Expected';

  @override
  String get cashDifference => 'Difference';

  @override
  String cashClosedAt(String time) {
    return 'Closed: $time';
  }

  @override
  String get cashAmountRequired => 'Enter the amount';

  @override
  String get cashAmountInvalid => 'Invalid amount';

  @override
  String get cashNotesOptional => 'Notes (optional)';

  @override
  String get cashOpeningInput => 'Opening Amount (TSh) *';

  @override
  String get cashClosingInput => 'Closing Amount (TSh) *';

  @override
  String get cashCloseButton => 'Close';

  @override
  String get cashOpenedSuccess => 'Session opened!';

  @override
  String get cashClosedBalanced => 'Session closed. Balance is correct!';

  @override
  String cashClosedVariance(String amount) {
    return 'Session closed. Difference: $amount';
  }

  @override
  String get createAccountTitle => 'Add Account';

  @override
  String get createAccountNameLabel => 'Account Name *';

  @override
  String get createAccountNameHint => 'e.g. M-Pesa Shop, National Bank';

  @override
  String get createAccountNameRequired => 'Account name is required';

  @override
  String get createAccountTypeLabel => 'Account Type';

  @override
  String get createAccountReferenceLabel => 'Account Number (optional)';

  @override
  String get createAccountReferenceHint => 'e.g. 0712345678, 1234567890';

  @override
  String get createAccountSave => 'Add Account';

  @override
  String get transferTitle => 'Transfer Money';

  @override
  String get transferAmountLabel => 'Amount (TSh) *';

  @override
  String get transferAmountRequired => 'Enter the amount';

  @override
  String get transferAmountPositive => 'Amount must be positive';

  @override
  String get transferFromLabel => 'Account to transfer from *';

  @override
  String get transferFromRequired => 'Choose an account to transfer from';

  @override
  String get transferToLabel => 'Account to deposit into *';

  @override
  String get transferToRequired => 'Choose an account to deposit into';

  @override
  String get transferDescriptionLabel => 'Description *';

  @override
  String get transferDescriptionRequired => 'Enter a description';

  @override
  String get transferSubmit => 'Transfer Money';

  @override
  String get transferSuccess => 'Money transferred!';

  @override
  String get navBilling => 'Subscription';

  @override
  String get billingTitle => 'Subscription & billing';

  @override
  String get billingIntro =>
      'Manage your plan, renew access, and view invoices.';

  @override
  String get billingCurrentPlan => 'Current plan';

  @override
  String get billingStatus => 'Status';

  @override
  String get billingStatusTrial => 'Trial';

  @override
  String get billingStatusActive => 'Active';

  @override
  String get billingStatusDebt => 'Payment needed';

  @override
  String get billingFullAccess => 'Full access';

  @override
  String get billingBackstopAccess => 'POS and inventory access';

  @override
  String get billingNextDue => 'Next due';

  @override
  String get billingNoDueDate => 'No payment due';

  @override
  String get billingPlans => 'Plans';

  @override
  String get billingFree => 'Free';

  @override
  String get billingPro => 'Pro';

  @override
  String get billingPerMonth => 'per month';

  @override
  String get billingVoucherTitle => 'Redeem a voucher';

  @override
  String get billingVoucherIntro =>
      'Enter the code supplied with your payment.';

  @override
  String get billingVoucherLabel => 'Voucher code';

  @override
  String get billingVoucherHint => 'XXXX-XXXX-XXXX';

  @override
  String get billingRedeem => 'Redeem';

  @override
  String get billingInvoices => 'Invoices';

  @override
  String get billingNoInvoices => 'No invoices yet';

  @override
  String get billingInvoiceOpen => 'Open';

  @override
  String get billingInvoicePaid => 'Paid';

  @override
  String get billingInvoiceCancelled => 'Cancelled';

  @override
  String get billingShare => 'Share PDF';

  @override
  String get billingEvaluate => 'Check subscription';

  @override
  String get billingChecking => 'Checking...';

  @override
  String get billingLoading => 'Loading subscription...';

  @override
  String get billingLoadError => 'Could not load billing information.';

  @override
  String get billingRetry => 'Try again';

  @override
  String billingQuotaBranches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count branches',
      one: '1 branch',
    );
    return '$_temp0';
  }

  @override
  String billingQuotaUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count users',
      one: '1 user',
    );
    return '$_temp0';
  }

  @override
  String billingQuotaProducts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return '$_temp0';
  }

  @override
  String get billingBackstopMessage =>
      'POS and inventory remain available while payment is pending.';

  @override
  String get billingVoucherRequired => 'Enter a voucher code.';

  @override
  String get billingVoucherSuccess => 'Voucher redeemed successfully.';

  @override
  String get billingShareSuccess => 'Invoice ready to share.';

  @override
  String get billingShareError => 'Could not share this invoice.';

  @override
  String get billingInvoiceIssued => 'Issued';

  @override
  String get billingInvoicePeriod => 'Period';

  @override
  String get billingInvoiceNumber => 'Invoice number';

  @override
  String get billingInvoiceDescription => 'Description';

  @override
  String get billingInvoiceAmountDue => 'Amount due';

  @override
  String get billingInvoiceReference => 'Payment reference';

  @override
  String get billingInvoicePaidAt => 'Paid on';

  @override
  String get billingPriceLocked => 'Selling price (renewal required)';

  @override
  String get billingPriceLockedMessage =>
      'Renew your subscription to set selling and wholesale prices.';
}
