import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'JOLINX Business OS'**
  String get appTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your business'**
  String get loginSubtitle;

  /// No description provided for @identifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Email or phone number'**
  String get identifierLabel;

  /// No description provided for @identifierRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email or phone number'**
  String get identifierRequired;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordRequired;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Register'**
  String get noAccount;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @registerHeading.
  ///
  /// In en, this message translates to:
  /// **'Start your business'**
  String get registerHeading;

  /// No description provided for @businessNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Business name (optional)'**
  String get businessNameOptional;

  /// No description provided for @businessNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Not decided yet? We will use a placeholder — rename it later'**
  String get businessNameHelper;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get fullNameLabel;

  /// No description provided for @fullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get fullNameRequired;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'That email is not valid'**
  String get emailInvalid;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// No description provided for @phoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Example: 0712345678 or +255712345678'**
  String get phoneHelper;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get phoneRequired;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'That phone number is not valid'**
  String get phoneInvalid;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHelper;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password is too short (at least 8 characters)'**
  String get passwordTooShort;

  /// No description provided for @passwordRequiresUppercase.
  String get passwordRequiresUppercase;

  /// No description provided for @passwordRequiresLowercase.
  String get passwordRequiresLowercase;

  /// No description provided for @passwordRequiresDigit.
  String get passwordRequiresDigit;

  /// No description provided for @passwordRequiresSpecial.
  String get passwordRequiresSpecial;

  /// No description provided for @passwordRuleLength.
  String get passwordRuleLength;

  /// No description provided for @passwordRuleUppercase.
  String get passwordRuleUppercase;

  /// No description provided for @passwordRuleLowercase.
  String get passwordRuleLowercase;

  /// No description provided for @passwordRuleDigit.
  String get passwordRuleDigit;

  /// No description provided for @passwordRuleSpecial.
  String get passwordRuleSpecial;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDiffer;

  /// No description provided for @acceptTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'I accept the '**
  String get acceptTermsPrefix;

  /// No description provided for @acceptTermsLink.
  ///
  /// In en, this message translates to:
  /// **'terms and privacy policy'**
  String get acceptTermsLink;

  /// No description provided for @acceptTermsSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get acceptTermsSuffix;

  /// No description provided for @acceptTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'Accept the terms of service to continue.'**
  String get acceptTermsRequired;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotTitle;

  /// No description provided for @forgotIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you registered with. We will send you a reset code.'**
  String get forgotIntro;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToLogin;

  /// No description provided for @resetSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get resetSentTitle;

  /// No description provided for @resetSentBody.
  ///
  /// In en, this message translates to:
  /// **'If an account with this email exists, a reset code has been sent to it. Check your inbox (and spam folder).'**
  String get resetSentBody;

  /// No description provided for @enterResetCode.
  ///
  /// In en, this message translates to:
  /// **'Enter reset code'**
  String get enterResetCode;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetTitle;

  /// No description provided for @resetIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we emailed you, then choose a new password.'**
  String get resetIntro;

  /// No description provided for @emailLabelPlain.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabelPlain;

  /// No description provided for @emailInvalidShort.
  ///
  /// In en, this message translates to:
  /// **'That email is not valid'**
  String get emailInvalidShort;

  /// No description provided for @resetCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get resetCodeLabel;

  /// No description provided for @resetCodeDigits.
  ///
  /// In en, this message translates to:
  /// **'The code has 6 digits'**
  String get resetCodeDigits;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @resetSubmit.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetSubmit;

  /// No description provided for @resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Please sign in again.'**
  String get resetSuccess;

  /// No description provided for @strengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get strengthWeak;

  /// No description provided for @strengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get strengthFair;

  /// No description provided for @strengthGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get strengthGood;

  /// No description provided for @strengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get strengthStrong;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hidePassword;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms and Privacy'**
  String get termsTitle;

  /// No description provided for @termsAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get termsAccountTitle;

  /// No description provided for @termsAccountBody.
  ///
  /// In en, this message translates to:
  /// **'You are responsible for keeping your password safe. All activity on your account is considered yours.'**
  String get termsAccountBody;

  /// No description provided for @termsDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Business data'**
  String get termsDataTitle;

  /// No description provided for @termsDataBody.
  ///
  /// In en, this message translates to:
  /// **'Your business name, products, sales and customers are stored for your business only. You own this data.'**
  String get termsDataBody;

  /// No description provided for @termsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get termsPrivacyTitle;

  /// No description provided for @termsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'We never sell your email or phone number. We use your details to run this service only.'**
  String get termsPrivacyBody;

  /// No description provided for @termsPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get termsPaymentsTitle;

  /// No description provided for @termsPaymentsBody.
  ///
  /// In en, this message translates to:
  /// **'If your business pays for the service, payments are handled by a licensed payment provider — we never store your card numbers or PINs.'**
  String get termsPaymentsBody;

  /// No description provided for @termsOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get termsOk;

  /// No description provided for @languageSwahili.
  ///
  /// In en, this message translates to:
  /// **'SW'**
  String get languageSwahili;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get languageEnglish;

  /// No description provided for @registerTabOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get registerTabOwner;

  /// No description provided for @registerTabStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get registerTabStaff;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invitation code'**
  String get inviteCodeLabel;

  /// No description provided for @inviteCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Your employer supplied this code'**
  String get inviteCodeHelper;

  /// No description provided for @inviteCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your invitation code'**
  String get inviteCodeRequired;

  /// No description provided for @inviteCodeShort.
  ///
  /// In en, this message translates to:
  /// **'The invitation code has 8 characters'**
  String get inviteCodeShort;

  /// No description provided for @staffTitle.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get staffTitle;

  /// No description provided for @staffHeading.
  ///
  /// In en, this message translates to:
  /// **'Invite a team member'**
  String get staffHeading;

  /// No description provided for @staffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate a one-time code and give it to your staff. They enter it when registering and join your business directly.'**
  String get staffSubtitle;

  /// No description provided for @generateCode.
  ///
  /// In en, this message translates to:
  /// **'Generate new code'**
  String get generateCode;

  /// No description provided for @generatingCode.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generatingCode;

  /// No description provided for @yourInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Your invitation code'**
  String get yourInviteCode;

  /// No description provided for @inviteCodeExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get inviteCodeExpires;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get inviteCodeCopied;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @staffNote.
  ///
  /// In en, this message translates to:
  /// **'The code is valid for 72 hours and can only be used once.'**
  String get staffNote;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get navProducts;

  /// No description provided for @navStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get navStock;

  /// No description provided for @navPOS.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get navPOS;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get navUsers;

  /// No description provided for @navRoles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get navRoles;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get navSuppliers;

  /// No description provided for @navPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get navPurchases;

  /// No description provided for @navExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get navExpenses;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navSalesHistory.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get navSalesHistory;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardTodaySales.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Sales'**
  String get dashboardTodaySales;

  /// No description provided for @dashboardTotalProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get dashboardTotalProducts;

  /// No description provided for @dashboardRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get dashboardRevenue;

  /// No description provided for @dashboardQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashboardQuickActions;

  /// No description provided for @dashboardLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get dashboardLowStock;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardSellNow.
  ///
  /// In en, this message translates to:
  /// **'Sell now'**
  String get dashboardSellNow;

  /// No description provided for @dashboardAddCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get dashboardAddCustomer;

  /// No description provided for @dashboardAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get dashboardAddExpense;

  /// No description provided for @dashboardAddPurchase.
  ///
  /// In en, this message translates to:
  /// **'Add purchase'**
  String get dashboardAddPurchase;

  /// No description provided for @dashboardViewStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get dashboardViewStock;

  /// No description provided for @dashboardDays7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get dashboardDays7;

  /// No description provided for @dashboardDays30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get dashboardDays30;

  /// No description provided for @dashboardBranchInfo.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get dashboardBranchInfo;

  /// No description provided for @dashboardRevenueTrend.
  ///
  /// In en, this message translates to:
  /// **'Revenue Trend'**
  String get dashboardRevenueTrend;

  /// No description provided for @dashboardItemsLeft.
  ///
  /// In en, this message translates to:
  /// **'items left'**
  String get dashboardItemsLeft;

  /// No description provided for @dashboardNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get dashboardNoActivity;

  /// No description provided for @dashboardErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Could not load dashboard'**
  String get dashboardErrorLoading;

  /// No description provided for @dashboardTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get dashboardTryAgain;

  /// No description provided for @dashboardGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get dashboardGreetingMorning;

  /// No description provided for @dashboardGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get dashboardGreetingAfternoon;

  /// No description provided for @dashboardGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get dashboardGreetingEvening;

  /// No description provided for @dashboardDefaultBranch.
  ///
  /// In en, this message translates to:
  /// **'Your Store'**
  String get dashboardDefaultBranch;

  /// No description provided for @dashboardPeriodDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dashboardPeriodDay;

  /// No description provided for @dashboardPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get dashboardPeriodWeek;

  /// No description provided for @dashboardPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get dashboardPeriodMonth;

  /// No description provided for @dashboardPeriodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get dashboardPeriodYear;

  /// No description provided for @dashboardPeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardPeriodToday;

  /// No description provided for @dashboardPeriodThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get dashboardPeriodThisMonth;

  /// No description provided for @dashboardRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get dashboardRevenueLabel;

  /// No description provided for @dashboardTransactionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get dashboardTransactionsLabel;

  /// No description provided for @dashboardTopProducts.
  ///
  /// In en, this message translates to:
  /// **'Top Products'**
  String get dashboardTopProducts;

  /// No description provided for @dashboardLowStockAlert.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get dashboardLowStockAlert;

  /// No description provided for @dashboardOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get dashboardOutOfStock;

  /// No description provided for @dashboardItemsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining'**
  String dashboardItemsRemaining(int count);

  /// No description provided for @dashboardActivityAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {entity}'**
  String dashboardActivityAdded(String entity);

  /// No description provided for @dashboardActivityUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {entity}'**
  String dashboardActivityUpdated(String entity);

  /// No description provided for @dashboardActivityDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {entity}'**
  String dashboardActivityDeleted(String entity);

  /// No description provided for @dashboardActivityDefault.
  ///
  /// In en, this message translates to:
  /// **'{action} {entity}'**
  String dashboardActivityDefault(String action, String entity);

  /// No description provided for @dashboardUnitsSold.
  ///
  /// In en, this message translates to:
  /// **'{count} units'**
  String dashboardUnitsSold(int count);

  /// No description provided for @dashboardEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to JOLINX!'**
  String get dashboardEmptyTitle;

  /// No description provided for @dashboardEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Start by adding products and making sales.\nActivity will appear here.'**
  String get dashboardEmptyMessage;

  /// No description provided for @dashboardItemUnits.
  ///
  /// In en, this message translates to:
  /// **'units'**
  String get dashboardItemUnits;

  /// No description provided for @posTitle.
  ///
  /// In en, this message translates to:
  /// **'Point of Sale'**
  String get posTitle;

  /// No description provided for @posSearchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get posSearchProducts;

  /// No description provided for @posNoProducts.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get posNoProducts;

  /// No description provided for @posNoProductsOffline.
  ///
  /// In en, this message translates to:
  /// **'Products will appear when online'**
  String get posNoProductsOffline;

  /// No description provided for @posNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get posNoSearchResults;

  /// No description provided for @posOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get posOutOfStock;

  /// No description provided for @posNoPrice.
  ///
  /// In en, this message translates to:
  /// **'No price set'**
  String get posNoPrice;

  /// No description provided for @posItemsInCart.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get posItemsInCart;

  /// No description provided for @posPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get posPay;

  /// No description provided for @posTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get posTotal;

  /// No description provided for @posPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get posPaymentMethod;

  /// No description provided for @posCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get posCash;

  /// No description provided for @posMobileMoney.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money'**
  String get posMobileMoney;

  /// No description provided for @posSaleComplete.
  ///
  /// In en, this message translates to:
  /// **'Sale complete'**
  String get posSaleComplete;

  /// No description provided for @posSellAgain.
  ///
  /// In en, this message translates to:
  /// **'Sell again'**
  String get posSellAgain;

  /// No description provided for @posPrintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print receipt'**
  String get posPrintReceipt;

  /// No description provided for @posShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get posShare;

  /// No description provided for @posReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get posReceipt;

  /// No description provided for @posAmountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get posAmountPaid;

  /// No description provided for @posCashReceived.
  ///
  /// In en, this message translates to:
  /// **'Cash received'**
  String get posCashReceived;

  /// No description provided for @posChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get posChange;

  /// No description provided for @posChangeDue.
  ///
  /// In en, this message translates to:
  /// **'Balance due'**
  String get posChangeDue;

  /// No description provided for @posCashReceivedHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the money handed over'**
  String get posCashReceivedHint;

  /// No description provided for @posCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get posCart;

  /// No description provided for @posIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get posIncrease;

  /// No description provided for @posDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get posDecrease;

  /// No description provided for @posRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get posRemove;

  /// No description provided for @posQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get posQuantity;

  /// No description provided for @posSetQuantity.
  ///
  /// In en, this message translates to:
  /// **'Set quantity'**
  String get posSetQuantity;

  /// No description provided for @posCartTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get posCartTotal;

  /// No description provided for @posContinueToPayment.
  ///
  /// In en, this message translates to:
  /// **'Continue to payment'**
  String get posContinueToPayment;

  /// No description provided for @posOfflineSale.
  ///
  /// In en, this message translates to:
  /// **'Offline sale — will sync when online'**
  String get posOfflineSale;

  /// No description provided for @posQuickSale.
  ///
  /// In en, this message translates to:
  /// **'Quick Sale'**
  String get posQuickSale;

  /// No description provided for @posQuickSaleName.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get posQuickSaleName;

  /// No description provided for @posQuickSaleNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this item.'**
  String get posQuickSaleNameRequired;

  /// No description provided for @posQuickSaleAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get posQuickSaleAmount;

  /// No description provided for @posQuickSaleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get posQuickSaleAdd;

  /// No description provided for @posQuickSaleAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get posQuickSaleAddAnother;

  /// No description provided for @posQuickSaleSell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get posQuickSaleSell;

  /// No description provided for @posQuickSaleSaveProduct.
  ///
  /// In en, this message translates to:
  /// **'Save as a product'**
  String get posQuickSaleSaveProduct;

  /// No description provided for @posQuickSaleRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get posQuickSaleRecent;

  /// No description provided for @posQuickSaleAddedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} added'**
  String posQuickSaleAddedCount(int count);

  /// No description provided for @posQuickSaleProductSaved.
  ///
  /// In en, this message translates to:
  /// **'Product saved'**
  String get posQuickSaleProductSaved;

  /// No description provided for @posQuickSaleProductExists.
  ///
  /// In en, this message translates to:
  /// **'This product already exists — no need to save it again.'**
  String get posQuickSaleProductExists;

  /// No description provided for @posQuickSaleProductSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the product: {message}'**
  String posQuickSaleProductSaveFailed(String message);

  /// No description provided for @posQuickSaleAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero.'**
  String get posQuickSaleAmountRequired;

  /// No description provided for @posQuickSaleNetFirstTime.
  ///
  /// In en, this message translates to:
  /// **'Internet is needed the first time you use Quick Sale.'**
  String get posQuickSaleNetFirstTime;

  /// No description provided for @posQuickSaleHint.
  ///
  /// In en, this message translates to:
  /// **'Sell any item without a product — set the price yourself'**
  String get posQuickSaleHint;

  /// No description provided for @posCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get posCredit;

  /// No description provided for @posCreditCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get posCreditCustomer;

  /// No description provided for @posCreditCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Search customers...'**
  String get posCreditCustomerHint;

  /// No description provided for @posCreditReceived.
  ///
  /// In en, this message translates to:
  /// **'Initial payment'**
  String get posCreditReceived;

  /// No description provided for @posCreditOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Credit remaining'**
  String get posCreditOutstanding;

  /// No description provided for @posCreditCustomerRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a customer for this credit sale.'**
  String get posCreditCustomerRequired;

  /// No description provided for @posCreditNoCustomers.
  ///
  /// In en, this message translates to:
  /// **'No customers found. Add them from the Customers tab.'**
  String get posCreditNoCustomers;

  /// No description provided for @posCreditCustomersOffline.
  ///
  /// In en, this message translates to:
  /// **'Internet is needed to choose a customer.'**
  String get posCreditCustomersOffline;

  /// No description provided for @posEditPrice.
  ///
  /// In en, this message translates to:
  /// **'Edit price'**
  String get posEditPrice;

  /// No description provided for @posEditPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter new price'**
  String get posEditPriceHint;

  /// No description provided for @posAddCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get posAddCustomer;

  /// No description provided for @posAddCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get posAddCustomerName;

  /// No description provided for @posAddCustomerPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number (optional)'**
  String get posAddCustomerPhone;

  /// No description provided for @posAddCustomerSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get posAddCustomerSave;

  /// No description provided for @saleVoid.
  ///
  /// In en, this message translates to:
  /// **'Void sale'**
  String get saleVoid;

  /// No description provided for @saleVoidFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not void the sale. Try again.'**
  String get saleVoidFailed;

  /// No description provided for @saleVoided.
  ///
  /// In en, this message translates to:
  /// **'Sale voided'**
  String get saleVoided;

  /// No description provided for @saleVoidConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Void this sale?'**
  String get saleVoidConfirmTitle;

  /// No description provided for @saleVoidConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Stock will be added back and the sale removed from your totals. The receipt number is kept for the record.'**
  String get saleVoidConfirmMessage;

  /// No description provided for @saleVoidReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (required)'**
  String get saleVoidReasonHint;

  /// No description provided for @saleVoidReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a reason before voiding.'**
  String get saleVoidReasonRequired;

  /// No description provided for @saleDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get saleDetailTitle;

  /// No description provided for @saleDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load receipt. Try again.'**
  String get saleDetailLoadFailed;

  /// No description provided for @saleSummarySubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get saleSummarySubtotal;

  /// No description provided for @saleSummaryDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get saleSummaryDiscount;

  /// No description provided for @saleSummaryTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get saleSummaryTotal;

  /// No description provided for @saleSummaryChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get saleSummaryChange;

  /// No description provided for @salePendingNumber.
  ///
  /// In en, this message translates to:
  /// **'Will be ready later'**
  String get salePendingNumber;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// No description provided for @receiptCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get receiptCopy;

  /// No description provided for @receiptSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get receiptSave;

  /// No description provided for @receiptCopied.
  ///
  /// In en, this message translates to:
  /// **'Receipt copied.'**
  String get receiptCopied;

  /// No description provided for @receiptSaved.
  ///
  /// In en, this message translates to:
  /// **'Receipt saved: {path}'**
  String receiptSaved(String path);

  /// No description provided for @receiptSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save receipt.'**
  String get receiptSaveFailed;

  /// No description provided for @posSyncPending.
  ///
  /// In en, this message translates to:
  /// **'Sync pending'**
  String get posSyncPending;

  /// No description provided for @posOfflineProducts.
  ///
  /// In en, this message translates to:
  /// **'Products will appear when online'**
  String get posOfflineProducts;

  /// No description provided for @productsTitle.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsTitle;

  /// No description provided for @productsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get productsAdd;

  /// No description provided for @productsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get productsSearch;

  /// No description provided for @productsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get productsEmpty;

  /// No description provided for @productsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your first product to start selling'**
  String get productsEmptyMessage;

  /// No description provided for @productsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get productsNoResults;

  /// No description provided for @productsPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get productsPrice;

  /// No description provided for @productsPriceNotSet.
  ///
  /// In en, this message translates to:
  /// **'Price not set'**
  String get productsPriceNotSet;

  /// No description provided for @productsStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get productsStock;

  /// No description provided for @productsNoStock.
  ///
  /// In en, this message translates to:
  /// **'No stock'**
  String get productsNoStock;

  /// No description provided for @productsOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get productsOutOfStock;

  /// No description provided for @productsStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock: {count}'**
  String productsStockLabel(int count);

  /// No description provided for @productsClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get productsClosed;

  /// No description provided for @productsSKU.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get productsSKU;

  /// No description provided for @productsAddStock.
  ///
  /// In en, this message translates to:
  /// **'Add stock'**
  String get productsAddStock;

  /// No description provided for @productsStockHub.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get productsStockHub;

  /// No description provided for @productsTotalStock.
  ///
  /// In en, this message translates to:
  /// **'Total Stock'**
  String get productsTotalStock;

  /// No description provided for @productsLowStockCount.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get productsLowStockCount;

  /// No description provided for @productsZeroStockCount.
  ///
  /// In en, this message translates to:
  /// **'No Stock'**
  String get productsZeroStockCount;

  /// No description provided for @productsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Details'**
  String get productsDetailsTitle;

  /// No description provided for @productsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get productsNotFound;

  /// No description provided for @productsRetailPrice.
  ///
  /// In en, this message translates to:
  /// **'Retail Price'**
  String get productsRetailPrice;

  /// No description provided for @productsWholesalePrice.
  ///
  /// In en, this message translates to:
  /// **'Wholesale Price'**
  String get productsWholesalePrice;

  /// No description provided for @productsType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get productsType;

  /// No description provided for @productsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get productsCategory;

  /// No description provided for @productsBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get productsBrand;

  /// No description provided for @productsUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get productsUnit;

  /// No description provided for @productsDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get productsDescription;

  /// No description provided for @addStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Add stock'**
  String get addStockTitle;

  /// No description provided for @addStockProduct.
  ///
  /// In en, this message translates to:
  /// **'Product: {name}'**
  String addStockProduct(String name);

  /// No description provided for @addStockQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get addStockQuantity;

  /// No description provided for @addStockWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse: Main Store'**
  String get addStockWarehouse;

  /// No description provided for @addStockSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get addStockSave;

  /// No description provided for @addStockInvalidQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity (greater than zero).'**
  String get addStockInvalidQuantity;

  /// No description provided for @addStockWarehouseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No storage location available. Try again.'**
  String get addStockWarehouseUnavailable;

  /// No description provided for @stockPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stockPageTitle;

  /// No description provided for @stockPageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stock yet. Start by adding products.'**
  String get stockPageEmpty;

  /// No description provided for @stockPageRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get stockPageRetry;

  /// No description provided for @openingStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Opening Stock'**
  String get openingStockTitle;

  /// No description provided for @openingStockReason.
  ///
  /// In en, this message translates to:
  /// **'Opening stock'**
  String get openingStockReason;

  /// No description provided for @openingStockDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Opening stock has already been recorded for this product.'**
  String get openingStockDuplicate;

  /// No description provided for @productFormTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get productFormTitleNew;

  /// No description provided for @productFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get productFormTitleEdit;

  /// No description provided for @productFormName.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productFormName;

  /// No description provided for @productFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Rice'**
  String get productFormNameHint;

  /// No description provided for @productFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get productFormNameRequired;

  /// No description provided for @productFormPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get productFormPrice;

  /// No description provided for @productFormPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price (greater than zero).'**
  String get productFormPriceRequired;

  /// No description provided for @productFormUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get productFormUnit;

  /// No description provided for @productFormUnitRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a unit.'**
  String get productFormUnitRequired;

  /// No description provided for @productFormGoods.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productFormGoods;

  /// No description provided for @productFormService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get productFormService;

  /// No description provided for @productFormAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced (optional)'**
  String get productFormAdvanced;

  /// No description provided for @productFormWholesalePrice.
  ///
  /// In en, this message translates to:
  /// **'Wholesale price'**
  String get productFormWholesalePrice;

  /// No description provided for @productFormCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get productFormCategory;

  /// No description provided for @productFormBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get productFormBrand;

  /// No description provided for @productFormSku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get productFormSku;

  /// No description provided for @productFormBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get productFormBarcode;

  /// No description provided for @productFormOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get productFormOptional;

  /// No description provided for @productFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get productFormDescription;

  /// No description provided for @productFormSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get productFormSave;

  /// No description provided for @productFormSaveEdit.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get productFormSaveEdit;

  /// No description provided for @productFormSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get productFormSaved;

  /// No description provided for @productFormDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A product with this SKU or barcode already exists.'**
  String get productFormDuplicate;

  /// No description provided for @productFormForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to change products.'**
  String get productFormForbidden;

  /// No description provided for @productFormNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet. Check your connection and try again.'**
  String get productFormNetwork;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @customersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get customersAdd;

  /// No description provided for @customersSearch.
  ///
  /// In en, this message translates to:
  /// **'Search customers...'**
  String get customersSearch;

  /// No description provided for @customersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get customersEmpty;

  /// No description provided for @customersEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your first customer to track sales'**
  String get customersEmptyMessage;

  /// No description provided for @customersDebtors.
  ///
  /// In en, this message translates to:
  /// **'Who owes you?'**
  String get customersDebtors;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsSalesSummary.
  ///
  /// In en, this message translates to:
  /// **'Sales Summary'**
  String get reportsSalesSummary;

  /// No description provided for @reportsPeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get reportsPeriodToday;

  /// No description provided for @reportsPeriodThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get reportsPeriodThisWeek;

  /// No description provided for @reportsPeriodThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get reportsPeriodThisMonth;

  /// No description provided for @reportsPeriodLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get reportsPeriodLastMonth;

  /// No description provided for @reportsRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportsRevenue;

  /// No description provided for @reportsAverageSale.
  ///
  /// In en, this message translates to:
  /// **'Average sale'**
  String get reportsAverageSale;

  /// No description provided for @reportsSaleCount.
  ///
  /// In en, this message translates to:
  /// **'Sales count'**
  String get reportsSaleCount;

  /// No description provided for @reportsTrendLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get reportsTrendLast7Days;

  /// No description provided for @reportsSoldLabel.
  ///
  /// In en, this message translates to:
  /// **'sold'**
  String get reportsSoldLabel;

  /// No description provided for @dashboardCachedBanner.
  ///
  /// In en, this message translates to:
  /// **'Viewing offline data (cached). Pull to refresh when connected.'**
  String get dashboardCachedBanner;

  /// No description provided for @dashboardUpdatedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get dashboardUpdatedJustNow;

  /// No description provided for @reportsProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get reportsProfitLabel;

  /// No description provided for @reportsLossLabel.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get reportsLossLabel;

  /// No description provided for @reportsCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get reportsCostLabel;

  /// No description provided for @reportsTopProducts.
  ///
  /// In en, this message translates to:
  /// **'Top Products'**
  String get reportsTopProducts;

  /// No description provided for @reportsSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get reportsSeeAll;

  /// No description provided for @reportsNoSalesData.
  ///
  /// In en, this message translates to:
  /// **'No sales data yet'**
  String get reportsNoSalesData;

  /// No description provided for @reportsQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get reportsQuickActions;

  /// No description provided for @reportsPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get reportsPurchases;

  /// No description provided for @reportsExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get reportsExpenses;

  /// No description provided for @salesHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get salesHistoryTitle;

  /// No description provided for @salesHistoryToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get salesHistoryToday;

  /// No description provided for @salesHistoryYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get salesHistoryYesterday;

  /// No description provided for @salesHistoryPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get salesHistoryPickDate;

  /// No description provided for @salesHistorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search receipt number'**
  String get salesHistorySearchHint;

  /// No description provided for @salesHistoryEmptyDay.
  ///
  /// In en, this message translates to:
  /// **'No sales on this day.'**
  String get salesHistoryEmptyDay;

  /// No description provided for @salesHistoryEmptySearch.
  ///
  /// In en, this message translates to:
  /// **'No sales match your search.'**
  String get salesHistoryEmptySearch;

  /// No description provided for @salesHistoryNoNumber.
  ///
  /// In en, this message translates to:
  /// **'(receipt pending)'**
  String get salesHistoryNoNumber;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsBusinessInfo.
  ///
  /// In en, this message translates to:
  /// **'Business Information'**
  String get settingsBusinessInfo;

  /// No description provided for @settingsBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get settingsBusinessName;

  /// No description provided for @settingsAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get settingsAddress;

  /// No description provided for @settingsPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get settingsPhone;

  /// No description provided for @settingsEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsEmail;

  /// No description provided for @settingsTIN.
  ///
  /// In en, this message translates to:
  /// **'TIN'**
  String get settingsTIN;

  /// No description provided for @settingsCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get settingsCountry;

  /// No description provided for @settingsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

  /// No description provided for @settingsPersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get settingsPersonalInfo;

  /// No description provided for @settingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit your profile'**
  String get settingsEditProfile;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get settingsChangePassword;

  /// No description provided for @settingsUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update your password'**
  String get settingsUpdatePassword;

  /// No description provided for @settingsApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsApp;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsEditBusiness.
  ///
  /// In en, this message translates to:
  /// **'Edit business information'**
  String get settingsEditBusiness;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get settingsSaved;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// No description provided for @moreQuickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get moreQuickAccess;

  /// No description provided for @moreManagement.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get moreManagement;

  /// No description provided for @moreTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get moreTeam;

  /// No description provided for @moreLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get moreLogout;

  /// No description provided for @moreLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get moreLogoutConfirm;

  /// No description provided for @moreLogoutPendingSales.
  ///
  /// In en, this message translates to:
  /// **'You have pending sales that will sync when online'**
  String get moreLogoutPendingSales;

  /// No description provided for @moreLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to sign out?'**
  String get moreLogoutMessage;

  /// No description provided for @moreLogoutStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get moreLogoutStay;

  /// No description provided for @moreCopyright.
  ///
  /// In en, this message translates to:
  /// **'2026 Jolinx Business OS'**
  String get moreCopyright;

  /// No description provided for @moreTagline.
  ///
  /// In en, this message translates to:
  /// **'Your business system, anywhere you go.'**
  String get moreTagline;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @mfaTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor verification'**
  String get mfaTitle;

  /// No description provided for @mfaCodeForAccount.
  ///
  /// In en, this message translates to:
  /// **'Enter the code for {email}'**
  String mfaCodeForAccount(Object email);

  /// No description provided for @mfaCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your authenticator app.'**
  String get mfaCodePrompt;

  /// No description provided for @mfaCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get mfaCodeLabel;

  /// No description provided for @mfaRecoveryCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get mfaRecoveryCodeLabel;

  /// No description provided for @mfaRecoveryCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Each recovery code works once.'**
  String get mfaRecoveryCodeHint;

  /// No description provided for @mfaTotpHint.
  ///
  /// In en, this message translates to:
  /// **'The code refreshes every 30 seconds.'**
  String get mfaTotpHint;

  /// No description provided for @mfaUseAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'I\'m using an authenticator app'**
  String get mfaUseAuthenticator;

  /// No description provided for @mfaUseRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Locked out? Use a recovery code'**
  String get mfaUseRecoveryCode;

  /// No description provided for @mfaBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get mfaBackToLogin;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// No description provided for @securityTwoFactorSection.
  ///
  /// In en, this message translates to:
  /// **'Two-factor verification'**
  String get securityTwoFactorSection;

  /// No description provided for @securityTwoFactorOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get securityTwoFactorOn;

  /// No description provided for @securityTwoFactorOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get securityTwoFactorOff;

  /// No description provided for @securityTwoFactorSince.
  ///
  /// In en, this message translates to:
  /// **'On since {date}'**
  String securityTwoFactorSince(Object date);

  /// No description provided for @securityTwoFactorRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended for your role'**
  String get securityTwoFactorRecommended;

  /// No description provided for @securityTwoFactorTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get securityTwoFactorTurnOn;

  /// No description provided for @securityTwoFactorTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get securityTwoFactorTurnOff;

  /// No description provided for @securityTwoFactorSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your authenticator'**
  String get securityTwoFactorSetupTitle;

  /// No description provided for @securityTwoFactorScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan this in your authenticator app'**
  String get securityTwoFactorScanTitle;

  /// No description provided for @securityTwoFactorManualKey.
  ///
  /// In en, this message translates to:
  /// **'Can\'t scan? Enter this key by hand:'**
  String get securityTwoFactorManualKey;

  /// No description provided for @securityTwoFactorThenConfirm.
  ///
  /// In en, this message translates to:
  /// **'Then enter the 6-digit code it shows.'**
  String get securityTwoFactorThenConfirm;

  /// No description provided for @securityTwoFactorEnabled.
  ///
  /// In en, this message translates to:
  /// **'Two-factor verification is on.'**
  String get securityTwoFactorEnabled;

  /// No description provided for @securityTwoFactorDisabled.
  ///
  /// In en, this message translates to:
  /// **'Two-factor verification is off.'**
  String get securityTwoFactorDisabled;

  /// No description provided for @securityRecoveryCodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery codes'**
  String get securityRecoveryCodesTitle;

  /// No description provided for @securityRecoveryCodesIntro.
  ///
  /// In en, this message translates to:
  /// **'Save these somewhere safe. Each one signs you in once if you lose your device.'**
  String get securityRecoveryCodesIntro;

  /// No description provided for @securityRecoveryCodesSaved.
  ///
  /// In en, this message translates to:
  /// **'I have saved my codes'**
  String get securityRecoveryCodesSaved;

  /// No description provided for @securityRecoveryCodesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No codes left} =1{1 code left} other{{count} codes left}}'**
  String securityRecoveryCodesLeft(int count);

  /// No description provided for @securitySessionsSection.
  ///
  /// In en, this message translates to:
  /// **'Signed-in devices'**
  String get securitySessionsSection;

  /// No description provided for @securitySessionsIntro.
  ///
  /// In en, this message translates to:
  /// **'If you do not recognise a device, sign it out.'**
  String get securitySessionsIntro;

  /// No description provided for @securitySessionCurrent.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get securitySessionCurrent;

  /// No description provided for @securitySessionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get securitySessionSignOut;

  /// No description provided for @securitySessionSignOutAll.
  ///
  /// In en, this message translates to:
  /// **'Sign out of all devices'**
  String get securitySessionSignOutAll;

  /// No description provided for @securitySessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No other devices are signed in.'**
  String get securitySessionsEmpty;

  /// No description provided for @securityDisableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Enter a current code to turn this off.'**
  String get securityDisableConfirm;

  /// No description provided for @splashStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting up...'**
  String get splashStarting;

  /// No description provided for @splashAppName.
  ///
  /// In en, this message translates to:
  /// **'JOLINX Business OS'**
  String get splashAppName;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Your business, your way'**
  String get splashTagline;

  /// No description provided for @splashOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get splashOffline;

  /// No description provided for @splashOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Products will load when you are online'**
  String get splashOfflineMessage;

  /// No description provided for @expenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenseTitle;

  /// No description provided for @expenseSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search expenses...'**
  String get expenseSearchHint;

  /// No description provided for @expenseToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get expenseToday;

  /// No description provided for @expenseYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get expenseYesterday;

  /// No description provided for @expenseThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get expenseThisMonth;

  /// No description provided for @expenseAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get expenseAllTime;

  /// No description provided for @expensePickRange.
  ///
  /// In en, this message translates to:
  /// **'Pick date range'**
  String get expensePickRange;

  /// No description provided for @expenseSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Spending summary'**
  String get expenseSummaryTitle;

  /// No description provided for @expenseSummaryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No spending in this period'**
  String get expenseSummaryEmpty;

  /// No description provided for @expenseEmpty.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get expenseEmpty;

  /// No description provided for @expenseEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Record your daily outflows and keep track of cash.'**
  String get expenseEmptyMessage;

  /// No description provided for @expenseEmptySearch.
  ///
  /// In en, this message translates to:
  /// **'No expenses match your search'**
  String get expenseEmptySearch;

  /// No description provided for @expenseAdd.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expenseAdd;

  /// No description provided for @expenseAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expenseAddTitle;

  /// No description provided for @expenseEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get expenseEditTitle;

  /// No description provided for @expenseDescription.
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get expenseDescription;

  /// No description provided for @expenseDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get expenseDescriptionRequired;

  /// No description provided for @expenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount *'**
  String get expenseAmount;

  /// No description provided for @expenseAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Amount is required'**
  String get expenseAmountRequired;

  /// No description provided for @expenseAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get expenseAmountInvalid;

  /// No description provided for @expenseDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get expenseDate;

  /// No description provided for @expenseCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expenseCategory;

  /// No description provided for @expenseCategoryNone.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get expenseCategoryNone;

  /// No description provided for @expenseCategoryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get expenseCategoryAdd;

  /// No description provided for @expenseNewCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get expenseNewCategoryTitle;

  /// No description provided for @expenseCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get expenseCategoryName;

  /// No description provided for @expenseCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Category name is required'**
  String get expenseCategoryRequired;

  /// No description provided for @expensePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get expensePaymentMethod;

  /// No description provided for @expenseReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get expenseReference;

  /// No description provided for @expenseNotes.
  ///
  /// In en, this message translates to:
  /// **'Additional notes'**
  String get expenseNotes;

  /// No description provided for @expenseDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this expense?'**
  String get expenseDeleteConfirmTitle;

  /// No description provided for @expenseDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get expenseDeleteConfirmMessage;

  /// No description provided for @expenseSaved.
  ///
  /// In en, this message translates to:
  /// **'Expense saved'**
  String get expenseSaved;

  /// No description provided for @expenseLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more...'**
  String get expenseLoadMore;

  /// No description provided for @posPrintSuccess.
  ///
  /// In en, this message translates to:
  /// **'Receipt sent to printer.'**
  String get posPrintSuccess;

  /// No description provided for @posPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Printing failed. Check printer connection.'**
  String get posPrintFailed;

  /// No description provided for @posShareText.
  ///
  /// In en, this message translates to:
  /// **'Copy receipt (text)'**
  String get posShareText;

  /// No description provided for @reportsHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsHubTitle;

  /// No description provided for @reportsBusinessOverview.
  ///
  /// In en, this message translates to:
  /// **'Business Overview'**
  String get reportsBusinessOverview;

  /// No description provided for @reportsSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get reportsSales;

  /// No description provided for @reportsStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get reportsStock;

  /// No description provided for @reportsMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get reportsMoney;

  /// No description provided for @reportsPurchasesReport.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get reportsPurchasesReport;

  /// No description provided for @reportsExpensesReport.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get reportsExpensesReport;

  /// No description provided for @reportsGrossProfit.
  ///
  /// In en, this message translates to:
  /// **'Gross Profit'**
  String get reportsGrossProfit;

  /// No description provided for @reportsExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get reportsExpensesLabel;

  /// No description provided for @reportsMoneyBalance.
  ///
  /// In en, this message translates to:
  /// **'Money Balance'**
  String get reportsMoneyBalance;

  /// No description provided for @reportsSalesPerformance.
  ///
  /// In en, this message translates to:
  /// **'Sales Performance'**
  String get reportsSalesPerformance;

  /// No description provided for @reportsStockOverview.
  ///
  /// In en, this message translates to:
  /// **'Stock Overview'**
  String get reportsStockOverview;

  /// No description provided for @reportsMoneyMovement.
  ///
  /// In en, this message translates to:
  /// **'Money Movement'**
  String get reportsMoneyMovement;

  /// No description provided for @reportsPurchasesOverview.
  ///
  /// In en, this message translates to:
  /// **'Purchases Overview'**
  String get reportsPurchasesOverview;

  /// No description provided for @reportsExpensesOverview.
  ///
  /// In en, this message translates to:
  /// **'Expenses Overview'**
  String get reportsExpensesOverview;

  /// No description provided for @reportsByPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'By Payment Method'**
  String get reportsByPaymentMethod;

  /// No description provided for @reportsByCategory.
  ///
  /// In en, this message translates to:
  /// **'By Category'**
  String get reportsByCategory;

  /// No description provided for @reportsByStaff.
  ///
  /// In en, this message translates to:
  /// **'By Staff'**
  String get reportsByStaff;

  /// No description provided for @reportsByCustomer.
  ///
  /// In en, this message translates to:
  /// **'By Customer'**
  String get reportsByCustomer;

  /// No description provided for @reportsBySupplier.
  ///
  /// In en, this message translates to:
  /// **'By Supplier'**
  String get reportsBySupplier;

  /// No description provided for @reportsStartingBalance.
  ///
  /// In en, this message translates to:
  /// **'Starting Balance'**
  String get reportsStartingBalance;

  /// No description provided for @reportsMoneyIn.
  ///
  /// In en, this message translates to:
  /// **'Money In'**
  String get reportsMoneyIn;

  /// No description provided for @reportsMoneyOut.
  ///
  /// In en, this message translates to:
  /// **'Money Out'**
  String get reportsMoneyOut;

  /// No description provided for @reportsCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get reportsCurrentBalance;

  /// No description provided for @reportsTotalPurchased.
  ///
  /// In en, this message translates to:
  /// **'Total Purchased'**
  String get reportsTotalPurchased;

  /// No description provided for @reportsSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get reportsSuppliers;

  /// No description provided for @reportsItemsReceived.
  ///
  /// In en, this message translates to:
  /// **'Items Received'**
  String get reportsItemsReceived;

  /// No description provided for @reportsTopSupplier.
  ///
  /// In en, this message translates to:
  /// **'Top Supplier'**
  String get reportsTopSupplier;

  /// No description provided for @reportsPendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Pending Orders'**
  String get reportsPendingOrders;

  /// No description provided for @reportsReceivedOrders.
  ///
  /// In en, this message translates to:
  /// **'Received Orders'**
  String get reportsReceivedOrders;

  /// No description provided for @reportsTotalExpenses.
  ///
  /// In en, this message translates to:
  /// **'Total Expenses'**
  String get reportsTotalExpenses;

  /// No description provided for @reportsCategoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get reportsCategoryBreakdown;

  /// No description provided for @reportsTrend.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get reportsTrend;

  /// No description provided for @reportsStockSummary.
  ///
  /// In en, this message translates to:
  /// **'Stock Summary'**
  String get reportsStockSummary;

  /// No description provided for @reportsOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get reportsOpening;

  /// No description provided for @reportsPurchased.
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get reportsPurchased;

  /// No description provided for @reportsSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get reportsSold;

  /// No description provided for @reportsAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Adjusted'**
  String get reportsAdjusted;

  /// No description provided for @reportsClosing.
  ///
  /// In en, this message translates to:
  /// **'Closing'**
  String get reportsClosing;

  /// No description provided for @reportsLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get reportsLowStock;

  /// No description provided for @reportsStockVelocity.
  ///
  /// In en, this message translates to:
  /// **'Stock Velocity'**
  String get reportsStockVelocity;

  /// No description provided for @reportsMovementType.
  ///
  /// In en, this message translates to:
  /// **'Movement Type'**
  String get reportsMovementType;

  /// No description provided for @reportsMovementCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get reportsMovementCount;

  /// No description provided for @reportsTotalQuantity.
  ///
  /// In en, this message translates to:
  /// **'Total Quantity'**
  String get reportsTotalQuantity;

  /// No description provided for @reportsOnHand.
  ///
  /// In en, this message translates to:
  /// **'On Hand'**
  String get reportsOnHand;

  /// No description provided for @reportsVelocityPerDay.
  ///
  /// In en, this message translates to:
  /// **'Per Day'**
  String get reportsVelocityPerDay;

  /// No description provided for @reportsExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get reportsExportCsv;

  /// No description provided for @reportsExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get reportsExportPdf;

  /// No description provided for @reportsNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get reportsNoData;

  /// No description provided for @reportsComparedTo.
  ///
  /// In en, this message translates to:
  /// **'compared to'**
  String get reportsComparedTo;

  /// No description provided for @reportsPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'previous period'**
  String get reportsPreviousPeriod;

  /// No description provided for @reportsSeeDetails.
  ///
  /// In en, this message translates to:
  /// **'See details'**
  String get reportsSeeDetails;

  /// No description provided for @reportsViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get reportsViewAll;

  /// No description provided for @reportsFilterPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get reportsFilterPeriod;

  /// No description provided for @reportsFilterLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get reportsFilterLocation;

  /// No description provided for @reportsFilterStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get reportsFilterStaff;

  /// No description provided for @reportsFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get reportsFilterCategory;

  /// No description provided for @reportsFilterPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get reportsFilterPayment;

  /// No description provided for @reportsAllLocations.
  ///
  /// In en, this message translates to:
  /// **'All Locations'**
  String get reportsAllLocations;

  /// No description provided for @reportsAllStaff.
  ///
  /// In en, this message translates to:
  /// **'All Staff'**
  String get reportsAllStaff;

  /// No description provided for @reportsAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get reportsAllCategories;

  /// No description provided for @reportsAllMethods.
  ///
  /// In en, this message translates to:
  /// **'All Methods'**
  String get reportsAllMethods;

  /// No description provided for @reportsCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom Range'**
  String get reportsCustomRange;

  /// No description provided for @reportsReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get reportsReceipt;

  /// No description provided for @reportsCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get reportsCustomer;

  /// No description provided for @reportsAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get reportsAmount;

  /// No description provided for @reportsProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get reportsProduct;

  /// No description provided for @reportsQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get reportsQuantity;

  /// No description provided for @reportsRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportsRevenueLabel;

  /// No description provided for @reportsCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get reportsCash;

  /// No description provided for @reportsMobileMoney.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money'**
  String get reportsMobileMoney;

  /// No description provided for @reportsCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get reportsCredit;

  /// No description provided for @reportsWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get reportsWalkIn;

  /// No description provided for @stockReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a reason for adding stock'**
  String get stockReasonRequired;

  /// No description provided for @stockReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get stockReasonLabel;

  /// No description provided for @stockUnitCostOptional.
  ///
  /// In en, this message translates to:
  /// **'Unit cost (optional)'**
  String get stockUnitCostOptional;

  /// No description provided for @productFormCostPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get productFormCostPrice;

  /// No description provided for @productFormCostPriceHint.
  ///
  /// In en, this message translates to:
  /// **'How much you pay to buy this product'**
  String get productFormCostPriceHint;

  /// No description provided for @productFormCostPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Cost price cannot be negative'**
  String get productFormCostPriceInvalid;

  /// No description provided for @productFormCostPriceGuidance.
  ///
  /// In en, this message translates to:
  /// **'Required to calculate real profit and inventory valuation.'**
  String get productFormCostPriceGuidance;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navPos.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get navPos;

  /// No description provided for @navInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get navInvoices;

  /// No description provided for @invoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoicesTitle;

  /// No description provided for @invoicesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet'**
  String get invoicesEmpty;

  /// No description provided for @invoicesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Invoices you issue for your customers appear here.'**
  String get invoicesEmptyMessage;

  /// No description provided for @invoicesAdd.
  ///
  /// In en, this message translates to:
  /// **'New invoice'**
  String get invoicesAdd;

  /// No description provided for @invoicesSearch.
  ///
  /// In en, this message translates to:
  /// **'Search customer or number'**
  String get invoicesSearch;

  /// No description provided for @invoicesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get invoicesFilterAll;

  /// No description provided for @invoiceStatusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get invoiceStatusUnpaid;

  /// No description provided for @invoiceStatusPartial.
  ///
  /// In en, this message translates to:
  /// **'Partially paid'**
  String get invoiceStatusPartial;

  /// No description provided for @invoiceStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get invoiceStatusPaid;

  /// No description provided for @invoiceStatusVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get invoiceStatusVoid;

  /// No description provided for @invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get invoiceNumber;

  /// No description provided for @invoiceCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get invoiceCustomer;

  /// No description provided for @invoiceWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in customer'**
  String get invoiceWalkIn;

  /// No description provided for @invoiceBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get invoiceBalance;

  /// No description provided for @invoiceTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get invoiceTotal;

  /// No description provided for @invoiceNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New invoice'**
  String get invoiceNewTitle;

  /// No description provided for @invoiceLineDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get invoiceLineDescription;

  /// No description provided for @invoiceLineQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get invoiceLineQuantity;

  /// No description provided for @invoiceLineUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get invoiceLineUnitPrice;

  /// No description provided for @invoiceAddLine.
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get invoiceAddLine;

  /// No description provided for @invoiceRemoveLine.
  ///
  /// In en, this message translates to:
  /// **'Remove line'**
  String get invoiceRemoveLine;

  /// No description provided for @invoiceNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get invoiceNotes;

  /// No description provided for @invoiceDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get invoiceDueDate;

  /// No description provided for @invoiceSave.
  ///
  /// In en, this message translates to:
  /// **'Save invoice'**
  String get invoiceSave;

  /// No description provided for @invoiceDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceDetailTitle;

  /// No description provided for @invoiceRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get invoiceRecordPayment;

  /// No description provided for @invoicePaymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get invoicePaymentAmount;

  /// No description provided for @invoicePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get invoicePaymentMethod;

  /// No description provided for @invoicePaymentReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get invoicePaymentReference;

  /// No description provided for @invoiceVoid.
  ///
  /// In en, this message translates to:
  /// **'Void invoice'**
  String get invoiceVoid;

  /// No description provided for @invoiceVoidConfirm.
  ///
  /// In en, this message translates to:
  /// **'Void this invoice? Money still outstanding is written off.'**
  String get invoiceVoidConfirm;

  /// No description provided for @packagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Add-ons'**
  String get packagesTitle;

  /// No description provided for @packagesActive.
  ///
  /// In en, this message translates to:
  /// **'Active add-ons'**
  String get packagesActive;

  /// No description provided for @packagesAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available add-ons'**
  String get packagesAvailable;

  /// No description provided for @packagesActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get packagesActivate;

  /// No description provided for @packagesRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get packagesRemove;

  /// No description provided for @packagesNone.
  ///
  /// In en, this message translates to:
  /// **'No add-on is active on this workspace.'**
  String get packagesNone;

  /// No description provided for @packagesInvoiceManagerName.
  ///
  /// In en, this message translates to:
  /// **'Invoicing'**
  String get packagesInvoiceManagerName;

  /// No description provided for @packagesInvoiceManagerDescription.
  ///
  /// In en, this message translates to:
  /// **'Bill customers with invoices, take part payments and void mistakes.'**
  String get packagesInvoiceManagerDescription;

  /// No description provided for @packagesRequiresBillingManage.
  ///
  /// In en, this message translates to:
  /// **'You need the Billing.Manage permission to change add-ons.'**
  String get packagesRequiresBillingManage;

  /// No description provided for @moduleLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Module not available'**
  String get moduleLockedTitle;

  /// No description provided for @moduleLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'This part of the app needs a package that is not active on this workspace.'**
  String get moduleLockedMessage;

  /// No description provided for @moduleLockedGoToBilling.
  ///
  /// In en, this message translates to:
  /// **'Go to billing'**
  String get moduleLockedGoToBilling;

  /// No description provided for @moduleLockedBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get moduleLockedBack;

  /// No description provided for @capabilitiesOffline.
  ///
  /// In en, this message translates to:
  /// **'Showing the modules from your last sync.'**
  String get capabilitiesOffline;

  /// No description provided for @packageInvoiceManagerRequired.
  ///
  /// In en, this message translates to:
  /// **'Invoicing needs the invoice-manager add-on.'**
  String get packageInvoiceManagerRequired;

  /// No description provided for @commonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get commonOther;

  /// No description provided for @commonTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get commonTotal;

  /// No description provided for @commonChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get commonChange;

  /// No description provided for @commonAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get commonAmount;

  /// No description provided for @commonWithError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonWithError(String error);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profileTitle;

  /// No description provided for @profileChangeName.
  ///
  /// In en, this message translates to:
  /// **'Change Name'**
  String get profileChangeName;

  /// No description provided for @profileChangeNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Name'**
  String get profileChangeNameTitle;

  /// No description provided for @profileCurrentName.
  ///
  /// In en, this message translates to:
  /// **'Current Name'**
  String get profileCurrentName;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileNameLabel;

  /// No description provided for @profileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get profileNameRequired;

  /// No description provided for @profileAddPhone.
  ///
  /// In en, this message translates to:
  /// **'Add Phone'**
  String get profileAddPhone;

  /// No description provided for @profileBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get profileBusiness;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOut;

  /// No description provided for @profileChangePhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Phone'**
  String get profileChangePhoneTitle;

  /// No description provided for @profileCurrentPhone.
  ///
  /// In en, this message translates to:
  /// **'Current Phone'**
  String get profileCurrentPhone;

  /// No description provided for @profilePhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get profilePhoneRequired;

  /// No description provided for @profileChangePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get profileChangePasswordTitle;

  /// No description provided for @profileCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get profileCurrentPassword;

  /// No description provided for @profileNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get profileNewPassword;

  /// No description provided for @profileRepeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat Password'**
  String get profileRepeatPassword;

  /// No description provided for @profilePasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match or are empty'**
  String get profilePasswordsMismatch;

  /// No description provided for @profileChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get profileChangeAction;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get profileSaved;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow device'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get settingsTimezone;

  /// No description provided for @settingsPhoneEmail.
  ///
  /// In en, this message translates to:
  /// **'Phone and Email'**
  String get settingsPhoneEmail;

  /// No description provided for @settingsAppearancePicker.
  ///
  /// In en, this message translates to:
  /// **'Choose Appearance'**
  String get settingsAppearancePicker;

  /// No description provided for @settingsThemeAlwaysLight.
  ///
  /// In en, this message translates to:
  /// **'Always light'**
  String get settingsThemeAlwaysLight;

  /// No description provided for @settingsThemeAlwaysDark.
  ///
  /// In en, this message translates to:
  /// **'Always dark'**
  String get settingsThemeAlwaysDark;

  /// No description provided for @settingsLanguagePicker.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get settingsLanguagePicker;

  /// No description provided for @purchasesTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get purchasesTitle;

  /// No description provided for @purchasesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search purchases...'**
  String get purchasesSearchHint;

  /// No description provided for @purchasesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Purchase'**
  String get purchasesAdd;

  /// No description provided for @purchasesReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get purchasesReference;

  /// No description provided for @purchasesNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get purchasesNotes;

  /// No description provided for @purchasesEmptyLines.
  ///
  /// In en, this message translates to:
  /// **'No products added yet'**
  String get purchasesEmptyLines;

  /// No description provided for @purchasesLinesRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one product'**
  String get purchasesLinesRequired;

  /// No description provided for @purchasesSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier *'**
  String get purchasesSupplier;

  /// No description provided for @purchasesSupplierRequired.
  ///
  /// In en, this message translates to:
  /// **'Supplier is required'**
  String get purchasesSupplierRequired;

  /// No description provided for @purchasesOffice.
  ///
  /// In en, this message translates to:
  /// **'Office *'**
  String get purchasesOffice;

  /// No description provided for @purchasesOfficeRequired.
  ///
  /// In en, this message translates to:
  /// **'Office is required'**
  String get purchasesOfficeRequired;

  /// No description provided for @purchasesLineQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get purchasesLineQuantity;

  /// No description provided for @purchasesLineUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit Price'**
  String get purchasesLineUnitPrice;

  /// No description provided for @purchasesSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get purchasesSaved;

  /// No description provided for @purchasesDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase Details'**
  String get purchasesDetailTitle;

  /// No description provided for @purchasesDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Purchase not found'**
  String get purchasesDetailNotFound;

  /// No description provided for @purchasesOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get purchasesOrderLabel;

  /// No description provided for @purchasesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No purchases yet'**
  String get purchasesEmpty;

  /// No description provided for @purchasesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Start buying products from suppliers.'**
  String get purchasesEmptyMessage;

  /// No description provided for @purchasesDetailDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get purchasesDetailDate;

  /// No description provided for @purchasesDetailOffice.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get purchasesDetailOffice;

  /// No description provided for @purchasesDetailProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get purchasesDetailProducts;

  /// No description provided for @purchasesSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get purchasesSubmit;

  /// No description provided for @purchasesSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted!'**
  String get purchasesSubmitted;

  /// No description provided for @purchasesCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled!'**
  String get purchasesCancelled;

  /// No description provided for @pinSave.
  ///
  /// In en, this message translates to:
  /// **'Save PIN'**
  String get pinSave;

  /// No description provided for @pinUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get pinUnlock;

  /// No description provided for @pinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get pinTitle;

  /// No description provided for @pinUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with PIN'**
  String get pinUnlockTitle;

  /// No description provided for @pinSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Your PIN'**
  String get pinSetupTitle;

  /// No description provided for @pinSetupHint.
  ///
  /// In en, this message translates to:
  /// **'This PIN unlocks the app quickly. It is not used for your online account.'**
  String get pinSetupHint;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinLabel;

  /// No description provided for @pinHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4 to 6 digit PIN.'**
  String get pinHint;

  /// No description provided for @pinRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat PIN'**
  String get pinRepeat;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match.'**
  String get pinMismatch;

  /// No description provided for @pinLengthError.
  ///
  /// In en, this message translates to:
  /// **'PIN must be 4 to 6 digits.'**
  String get pinLengthError;

  /// No description provided for @pinRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN.'**
  String get pinRequired;

  /// No description provided for @pinSaved.
  ///
  /// In en, this message translates to:
  /// **'PIN saved.'**
  String get pinSaved;

  /// No description provided for @supplierFormTitleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Supplier'**
  String get supplierFormTitleAdd;

  /// No description provided for @supplierFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Supplier'**
  String get supplierFormTitleEdit;

  /// No description provided for @supplierFormName.
  ///
  /// In en, this message translates to:
  /// **'Supplier Name *'**
  String get supplierFormName;

  /// No description provided for @supplierFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get supplierFormNameRequired;

  /// No description provided for @supplierFormContact.
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get supplierFormContact;

  /// No description provided for @suppliersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search suppliers...'**
  String get suppliersSearchHint;

  /// No description provided for @supplierFormSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get supplierFormSaved;

  /// No description provided for @suppliersTitle.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliersTitle;

  /// No description provided for @suppliersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Supplier'**
  String get suppliersAdd;

  /// No description provided for @suppliersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No suppliers yet'**
  String get suppliersEmpty;

  /// No description provided for @suppliersEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add suppliers to start buying products.'**
  String get suppliersEmptyMessage;

  /// No description provided for @customerFormTitleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get customerFormTitleAdd;

  /// No description provided for @customerFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Customer'**
  String get customerFormTitleEdit;

  /// No description provided for @customerFormName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name *'**
  String get customerFormName;

  /// No description provided for @customerFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get customerFormNameRequired;

  /// No description provided for @customerFormSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get customerFormSaved;

  /// No description provided for @customerDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetailTitle;

  /// No description provided for @customerDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Customer not found'**
  String get customerDetailNotFound;

  /// No description provided for @customerDetailDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get customerDetailDebt;

  /// No description provided for @customerDetailDebtTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Debt'**
  String get customerDetailDebtTitle;

  /// No description provided for @customerDetailLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get customerDetailLimit;

  /// No description provided for @customerDetailNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get customerDetailNoNotes;

  /// No description provided for @customerDetailPayDebt.
  ///
  /// In en, this message translates to:
  /// **'Pay Debt'**
  String get customerDetailPayDebt;

  /// No description provided for @customerDetailSales.
  ///
  /// In en, this message translates to:
  /// **'Customer Sales'**
  String get customerDetailSales;

  /// No description provided for @customerDetailNoSales.
  ///
  /// In en, this message translates to:
  /// **'No sales yet'**
  String get customerDetailNoSales;

  /// No description provided for @customerDetailAddSale.
  ///
  /// In en, this message translates to:
  /// **'Add sale'**
  String get customerDetailAddSale;

  /// No description provided for @customerDebtPaid.
  ///
  /// In en, this message translates to:
  /// **'Debt paid'**
  String get customerDebtPaid;

  /// No description provided for @userFormTitleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add User'**
  String get userFormTitleAdd;

  /// No description provided for @userFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit User'**
  String get userFormTitleEdit;

  /// No description provided for @userFormEmail.
  ///
  /// In en, this message translates to:
  /// **'Email *'**
  String get userFormEmail;

  /// No description provided for @userFormEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get userFormEmailRequired;

  /// No description provided for @userFormName.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get userFormName;

  /// No description provided for @userFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get userFormNameRequired;

  /// No description provided for @userFormNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Name is too long'**
  String get userFormNameTooLong;

  /// No description provided for @userFormRoles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get userFormRoles;

  /// No description provided for @userFormNoRoles.
  ///
  /// In en, this message translates to:
  /// **'No roles found'**
  String get userFormNoRoles;

  /// No description provided for @userFormSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get userFormSaved;

  /// No description provided for @roleFormTitleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Role'**
  String get roleFormTitleAdd;

  /// No description provided for @roleFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Role'**
  String get roleFormTitleEdit;

  /// No description provided for @roleFormName.
  ///
  /// In en, this message translates to:
  /// **'Role Name *'**
  String get roleFormName;

  /// No description provided for @roleFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get roleFormNameRequired;

  /// No description provided for @roleFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get roleFormDescription;

  /// No description provided for @roleFormPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get roleFormPermissions;

  /// No description provided for @roleFormNoPermissions.
  ///
  /// In en, this message translates to:
  /// **'No permissions found'**
  String get roleFormNoPermissions;

  /// No description provided for @roleFormSystemAdminNote.
  ///
  /// In en, this message translates to:
  /// **'Administrator is a system role. You cannot rename or delete it. Change its permissions carefully; removing admin permissions may lock you out of managing this business.'**
  String get roleFormSystemAdminNote;

  /// No description provided for @roleFormSystemNote.
  ///
  /// In en, this message translates to:
  /// **'This is a system role. You cannot rename or delete it, but you can adjust its permissions.'**
  String get roleFormSystemNote;

  /// No description provided for @roleFormSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get roleFormSaved;

  /// No description provided for @usersTitle.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get usersTitle;

  /// No description provided for @usersActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get usersActivate;

  /// No description provided for @usersDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get usersDeactivate;

  /// No description provided for @usersDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get usersDelete;

  /// No description provided for @usersDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete User?'**
  String get usersDeleteTitle;

  /// No description provided for @usersDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}?'**
  String usersDeleteMessage(String name);

  /// No description provided for @usersDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get usersDeleteConfirm;

  /// No description provided for @rolesStarterBadge.
  ///
  /// In en, this message translates to:
  /// **'Starter role — you can edit or delete it'**
  String get rolesStarterBadge;

  /// No description provided for @rolesPermissionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} permissions'**
  String rolesPermissionCount(String count);

  /// No description provided for @rolesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Role?'**
  String get rolesDeleteTitle;

  /// No description provided for @rolesDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the role \"{name}\"? Users with this role will be unassigned.'**
  String rolesDeleteMessage(String name);

  /// No description provided for @recordIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Income'**
  String get recordIncomeTitle;

  /// No description provided for @recordExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get recordExpenseTitle;

  /// No description provided for @recordExpenseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Expense recorded'**
  String get recordExpenseSuccess;

  /// No description provided for @recordIncomeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Income recorded'**
  String get recordIncomeSuccess;

  /// No description provided for @recordAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (TSh) *'**
  String get recordAmountLabel;

  /// No description provided for @recordAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount'**
  String get recordAmountRequired;

  /// No description provided for @recordAmountPositive.
  ///
  /// In en, this message translates to:
  /// **'Amount must be positive'**
  String get recordAmountPositive;

  /// No description provided for @recordDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get recordDescriptionLabel;

  /// No description provided for @recordDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a description'**
  String get recordDescriptionRequired;

  /// No description provided for @recordNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get recordNotes;

  /// No description provided for @recordPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay Debt'**
  String get recordPaymentTitle;

  /// No description provided for @recordPaymentAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (TSh)'**
  String get recordPaymentAmountLabel;

  /// No description provided for @recordPaymentExceeds.
  ///
  /// In en, this message translates to:
  /// **'Amount cannot exceed the debt'**
  String get recordPaymentExceeds;

  /// No description provided for @recordPaymentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get recordPaymentConfirm;

  /// No description provided for @recordPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get recordPay;

  /// No description provided for @recordPaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get recordPaymentSuccess;

  /// No description provided for @outstandingTitle.
  ///
  /// In en, this message translates to:
  /// **'Who owes you?'**
  String get outstandingTitle;

  /// No description provided for @outstandingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No debt yet'**
  String get outstandingEmpty;

  /// No description provided for @outstandingTotal.
  ///
  /// In en, this message translates to:
  /// **'Total Debt'**
  String get outstandingTotal;

  /// No description provided for @outstandingCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer {id}'**
  String outstandingCustomer(String id);

  /// No description provided for @outstandingLastPayment.
  ///
  /// In en, this message translates to:
  /// **'Last payment: {date}'**
  String outstandingLastPayment(String date);

  /// No description provided for @outstandingError.
  ///
  /// In en, this message translates to:
  /// **'Could not load outstanding credits.'**
  String get outstandingError;

  /// No description provided for @outstandingPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get outstandingPay;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyTitle;

  /// No description provided for @verifyProgress.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifyProgress;

  /// No description provided for @verifyResend.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get verifyResend;

  /// No description provided for @verifyResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String verifyResendIn(int seconds);

  /// No description provided for @verifyCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to your email'**
  String get verifyCodeHint;

  /// No description provided for @verifyIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Your account is not verified yet.'**
  String get verifyIncorrect;

  /// No description provided for @createBusinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Start Business'**
  String get createBusinessTitle;

  /// No description provided for @createBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Business Name *'**
  String get createBusinessName;

  /// No description provided for @createBusinessNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Business name is required'**
  String get createBusinessNameRequired;

  /// No description provided for @createBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Business Type'**
  String get createBusinessType;

  /// No description provided for @createBusinessTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a business type'**
  String get createBusinessTypeRequired;

  /// No description provided for @createBusinessCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get createBusinessCountry;

  /// No description provided for @createBusinessCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get createBusinessCurrency;

  /// No description provided for @createBusinessPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact Phone'**
  String get createBusinessPhone;

  /// No description provided for @createBusinessTin.
  ///
  /// In en, this message translates to:
  /// **'TIN (optional)'**
  String get createBusinessTin;

  /// No description provided for @createBusinessStart.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get createBusinessStart;

  /// No description provided for @createBusinessSaved.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get createBusinessSaved;

  /// No description provided for @businessTypeRetail.
  ///
  /// In en, this message translates to:
  /// **'Retail'**
  String get businessTypeRetail;

  /// No description provided for @businessTypeWholesale.
  ///
  /// In en, this message translates to:
  /// **'Wholesale'**
  String get businessTypeWholesale;

  /// No description provided for @businessTypeServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get businessTypeServices;

  /// No description provided for @businessTypeHospitality.
  ///
  /// In en, this message translates to:
  /// **'Hospitality'**
  String get businessTypeHospitality;

  /// No description provided for @businessTypeAgriculture.
  ///
  /// In en, this message translates to:
  /// **'Agriculture'**
  String get businessTypeAgriculture;

  /// No description provided for @businessTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get businessTypeOther;

  /// No description provided for @businessSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Set Up Your Business'**
  String get businessSetupTitle;

  /// No description provided for @businessSetupWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome! Your business has been registered.'**
  String get businessSetupWelcome;

  /// No description provided for @businessSetupBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get businessSetupBusiness;

  /// No description provided for @businessSetupType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get businessSetupType;

  /// No description provided for @businessSetupUnitsReady.
  ///
  /// In en, this message translates to:
  /// **'Units of measure and warehouse are ready.'**
  String get businessSetupUnitsReady;

  /// No description provided for @businessSetupUnitsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to prepare units of measure. Try again later.'**
  String get businessSetupUnitsFailed;

  /// No description provided for @businessSetupPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing standard units of measure…'**
  String get businessSetupPreparing;

  /// No description provided for @businessSetupAddProducts.
  ///
  /// In en, this message translates to:
  /// **'Start Adding Products'**
  String get businessSetupAddProducts;

  /// No description provided for @businessSetupLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get businessSetupLater;

  /// No description provided for @businessSetupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get businessSetupSuccess;

  /// No description provided for @zeroWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'You Haven\'t Started a Business Yet'**
  String get zeroWorkspaceTitle;

  /// No description provided for @zeroWorkspaceBody.
  ///
  /// In en, this message translates to:
  /// **'Start by filling in your business details — name, business type, country and currency.'**
  String get zeroWorkspaceBody;

  /// No description provided for @zeroWorkspaceStart.
  ///
  /// In en, this message translates to:
  /// **'Start Business'**
  String get zeroWorkspaceStart;

  /// No description provided for @workspacePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Businesses'**
  String get workspacePickerTitle;

  /// No description provided for @workspacePickerIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get workspacePickerIncomplete;

  /// No description provided for @splashNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network Error'**
  String get splashNetworkError;

  /// No description provided for @loginAnotherUser.
  ///
  /// In en, this message translates to:
  /// **'Someone else? '**
  String get loginAnotherUser;

  /// No description provided for @loginUseBiometricPin.
  ///
  /// In en, this message translates to:
  /// **'Use Fingerprint or PIN'**
  String get loginUseBiometricPin;

  /// No description provided for @loginOtherAccount.
  ///
  /// In en, this message translates to:
  /// **'Someone else? Sign in to your account'**
  String get loginOtherAccount;

  /// No description provided for @loginGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}!'**
  String loginGreeting(String name);

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginVerifyIdentity.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to sign in'**
  String get loginVerifyIdentity;

  /// No description provided for @lockWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get lockWelcomeBack;

  /// No description provided for @lockLocked.
  ///
  /// In en, this message translates to:
  /// **'App is locked for security'**
  String get lockLocked;

  /// No description provided for @lockVerifyToContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to continue'**
  String get lockVerifyToContinue;

  /// No description provided for @lockUnlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Not able to unlock. Try your password.'**
  String get lockUnlockFailed;

  /// No description provided for @lockSignInPassword.
  ///
  /// In en, this message translates to:
  /// **'Sign in with password'**
  String get lockSignInPassword;

  /// No description provided for @lockPasswordOrPin.
  ///
  /// In en, this message translates to:
  /// **'Sign in with password or PIN'**
  String get lockPasswordOrPin;

  /// No description provided for @lockUsePin.
  ///
  /// In en, this message translates to:
  /// **'Use PIN'**
  String get lockUsePin;

  /// No description provided for @lockUseFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Use Fingerprint'**
  String get lockUseFingerprint;

  /// No description provided for @lockSwitchMethod.
  ///
  /// In en, this message translates to:
  /// **'Switch method'**
  String get lockSwitchMethod;

  /// No description provided for @fastUnlockFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Fingerprint'**
  String get fastUnlockFingerprint;

  /// No description provided for @fastUnlockVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get fastUnlockVerifying;

  /// No description provided for @fastUnlockBiometricHint.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face'**
  String get fastUnlockBiometricHint;

  /// No description provided for @fastUnlockOrPin.
  ///
  /// In en, this message translates to:
  /// **'or enter your PIN'**
  String get fastUnlockOrPin;

  /// No description provided for @fastUnlockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get fastUnlockEnterPin;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailIntro.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification code to:'**
  String get verifyEmailIntro;

  /// No description provided for @verifyEmailCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verifyEmailCodeLabel;

  /// No description provided for @verifyEmailCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get verifyEmailCodeInvalid;

  /// No description provided for @verifyEmailResendNew.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get verifyEmailResendNew;

  /// No description provided for @verifyEmailResendNewCountdown.
  ///
  /// In en, this message translates to:
  /// **'Send a new code ({seconds}s)'**
  String verifyEmailResendNewCountdown(String seconds);

  /// No description provided for @verifyEmailNewCodeSent.
  ///
  /// In en, this message translates to:
  /// **'A new code has been sent to your email.'**
  String get verifyEmailNewCodeSent;

  /// No description provided for @verifyEmailRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Please wait before requesting another code.'**
  String get verifyEmailRateLimited;

  /// No description provided for @syncStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Internet: Available'**
  String get syncStatusAvailable;

  /// No description provided for @syncStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Internet: Offline'**
  String get syncStatusOffline;

  /// No description provided for @syncStatusUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Internet: Unreachable'**
  String get syncStatusUnreachable;

  /// No description provided for @syncStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Internet: Checking...'**
  String get syncStatusChecking;

  /// No description provided for @posCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get posCard;

  /// No description provided for @posBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get posBankTransfer;

  /// No description provided for @posOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get posOther;

  /// No description provided for @entitySale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get entitySale;

  /// No description provided for @entityProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get entityProduct;

  /// No description provided for @entityCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get entityCustomer;

  /// No description provided for @entityExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get entityExpense;

  /// No description provided for @entityPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get entityPurchase;

  /// No description provided for @permAccounting.
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get permAccounting;

  /// No description provided for @permAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get permAudit;

  /// No description provided for @permBranches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get permBranches;

  /// No description provided for @permBrands.
  ///
  /// In en, this message translates to:
  /// **'Brands'**
  String get permBrands;

  /// No description provided for @permCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get permCategories;

  /// No description provided for @permCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get permCustomers;

  /// No description provided for @permDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get permDashboard;

  /// No description provided for @permExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get permExpenses;

  /// No description provided for @permInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get permInventory;

  /// No description provided for @permOrganizations.
  ///
  /// In en, this message translates to:
  /// **'Organizations'**
  String get permOrganizations;

  /// No description provided for @permPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get permPricing;

  /// No description provided for @permProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get permProducts;

  /// No description provided for @permPurchasing.
  ///
  /// In en, this message translates to:
  /// **'Purchasing'**
  String get permPurchasing;

  /// No description provided for @permReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get permReceipts;

  /// No description provided for @permRoles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get permRoles;

  /// No description provided for @permSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get permSales;

  /// No description provided for @permUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get permUnits;

  /// No description provided for @permUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get permUsers;

  /// No description provided for @permWarehouses.
  ///
  /// In en, this message translates to:
  /// **'Warehouses'**
  String get permWarehouses;

  /// No description provided for @moneyAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Money Accounts'**
  String get moneyAccountsTitle;

  /// No description provided for @moneyAccountsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search accounts...'**
  String get moneyAccountsSearchHint;

  /// No description provided for @moneyAccountsTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get moneyAccountsTotalBalance;

  /// No description provided for @moneyAccountsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No money accounts yet'**
  String get moneyAccountsEmpty;

  /// No description provided for @moneyAccountsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a cash, M-Pesa or bank account.'**
  String get moneyAccountsEmptyMessage;

  /// No description provided for @moneyAccountsInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get moneyAccountsInactive;

  /// No description provided for @moneyAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get moneyAccountTitle;

  /// No description provided for @moneyAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get moneyAccountNotFound;

  /// No description provided for @moneyAccountInactive.
  ///
  /// In en, this message translates to:
  /// **'Account inactive'**
  String get moneyAccountInactive;

  /// No description provided for @moneyAccountRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get moneyAccountRecentActivity;

  /// No description provided for @moneyAccountAddIncome.
  ///
  /// In en, this message translates to:
  /// **'Add Income'**
  String get moneyAccountAddIncome;

  /// No description provided for @moneyAccountAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get moneyAccountAddExpense;

  /// No description provided for @moneyAccountTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer Money'**
  String get moneyAccountTransfer;

  /// No description provided for @moneyAccountUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get moneyAccountUpdate;

  /// No description provided for @moneyAccountNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get moneyAccountNoActivity;

  /// No description provided for @moneyAccountBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get moneyAccountBalance;

  /// No description provided for @moneyAccountSaved.
  ///
  /// In en, this message translates to:
  /// **'Account added!'**
  String get moneyAccountSaved;

  /// No description provided for @moneyTransactionIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get moneyTransactionIncoming;

  /// No description provided for @moneyTransactionOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get moneyTransactionOutgoing;

  /// No description provided for @moneyTransactionTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get moneyTransactionTransfer;

  /// No description provided for @cashTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash Session'**
  String get cashTitle;

  /// No description provided for @cashOpenNew.
  ///
  /// In en, this message translates to:
  /// **'Open New Session'**
  String get cashOpenNew;

  /// No description provided for @cashCloseDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the cash you have left.'**
  String get cashCloseDialogHint;

  /// No description provided for @cashOpenInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the cash you have before you start selling.'**
  String get cashOpenInstructions;

  /// No description provided for @cashOpenBadge.
  ///
  /// In en, this message translates to:
  /// **'Session Open'**
  String get cashOpenBadge;

  /// No description provided for @cashOpeningAmount.
  ///
  /// In en, this message translates to:
  /// **'Opening Amount'**
  String get cashOpeningAmount;

  /// No description provided for @cashOpenedAt.
  ///
  /// In en, this message translates to:
  /// **'Opened: {time}'**
  String cashOpenedAt(String time);

  /// No description provided for @cashCloseSession.
  ///
  /// In en, this message translates to:
  /// **'Close Session'**
  String get cashCloseSession;

  /// No description provided for @cashClosedHeader.
  ///
  /// In en, this message translates to:
  /// **'Session Closed'**
  String get cashClosedHeader;

  /// No description provided for @cashClosedBadge.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get cashClosedBadge;

  /// No description provided for @cashClosingAmount.
  ///
  /// In en, this message translates to:
  /// **'Closing Amount'**
  String get cashClosingAmount;

  /// No description provided for @cashExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get cashExpected;

  /// No description provided for @cashDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get cashDifference;

  /// No description provided for @cashClosedAt.
  ///
  /// In en, this message translates to:
  /// **'Closed: {time}'**
  String cashClosedAt(String time);

  /// No description provided for @cashAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount'**
  String get cashAmountRequired;

  /// No description provided for @cashAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get cashAmountInvalid;

  /// No description provided for @cashNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get cashNotesOptional;

  /// No description provided for @cashOpeningInput.
  ///
  /// In en, this message translates to:
  /// **'Opening Amount (TSh) *'**
  String get cashOpeningInput;

  /// No description provided for @cashClosingInput.
  ///
  /// In en, this message translates to:
  /// **'Closing Amount (TSh) *'**
  String get cashClosingInput;

  /// No description provided for @cashCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get cashCloseButton;

  /// No description provided for @cashOpenedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Session opened!'**
  String get cashOpenedSuccess;

  /// No description provided for @cashClosedBalanced.
  ///
  /// In en, this message translates to:
  /// **'Session closed. Balance is correct!'**
  String get cashClosedBalanced;

  /// No description provided for @cashClosedVariance.
  ///
  /// In en, this message translates to:
  /// **'Session closed. Difference: {amount}'**
  String cashClosedVariance(String amount);

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get createAccountTitle;

  /// No description provided for @createAccountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Name *'**
  String get createAccountNameLabel;

  /// No description provided for @createAccountNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. M-Pesa Shop, National Bank'**
  String get createAccountNameHint;

  /// No description provided for @createAccountNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Account name is required'**
  String get createAccountNameRequired;

  /// No description provided for @createAccountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get createAccountTypeLabel;

  /// No description provided for @createAccountReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Number (optional)'**
  String get createAccountReferenceLabel;

  /// No description provided for @createAccountReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 0712345678, 1234567890'**
  String get createAccountReferenceHint;

  /// No description provided for @createAccountSave.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get createAccountSave;

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer Money'**
  String get transferTitle;

  /// No description provided for @transferAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (TSh) *'**
  String get transferAmountLabel;

  /// No description provided for @transferAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount'**
  String get transferAmountRequired;

  /// No description provided for @transferAmountPositive.
  ///
  /// In en, this message translates to:
  /// **'Amount must be positive'**
  String get transferAmountPositive;

  /// No description provided for @transferFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Account to transfer from *'**
  String get transferFromLabel;

  /// No description provided for @transferFromRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose an account to transfer from'**
  String get transferFromRequired;

  /// No description provided for @transferToLabel.
  ///
  /// In en, this message translates to:
  /// **'Account to deposit into *'**
  String get transferToLabel;

  /// No description provided for @transferToRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose an account to deposit into'**
  String get transferToRequired;

  /// No description provided for @transferDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get transferDescriptionLabel;

  /// No description provided for @transferDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a description'**
  String get transferDescriptionRequired;

  /// No description provided for @transferSubmit.
  ///
  /// In en, this message translates to:
  /// **'Transfer Money'**
  String get transferSubmit;

  /// No description provided for @transferSuccess.
  ///
  /// In en, this message translates to:
  /// **'Money transferred!'**
  String get transferSuccess;

  /// No description provided for @navBilling.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get navBilling;

  /// No description provided for @billingTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription & billing'**
  String get billingTitle;

  /// No description provided for @billingIntro.
  ///
  /// In en, this message translates to:
  /// **'Manage your plan, renew access, and view invoices.'**
  String get billingIntro;

  /// No description provided for @billingCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get billingCurrentPlan;

  /// No description provided for @billingStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get billingStatus;

  /// No description provided for @billingStatusTrial.
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get billingStatusTrial;

  /// No description provided for @billingStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get billingStatusActive;

  /// No description provided for @billingStatusDebt.
  ///
  /// In en, this message translates to:
  /// **'Payment needed'**
  String get billingStatusDebt;

  /// No description provided for @billingFullAccess.
  ///
  /// In en, this message translates to:
  /// **'Full access'**
  String get billingFullAccess;

  /// No description provided for @billingBackstopAccess.
  ///
  /// In en, this message translates to:
  /// **'POS and inventory access'**
  String get billingBackstopAccess;

  /// No description provided for @billingNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due'**
  String get billingNextDue;

  /// No description provided for @billingNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No payment due'**
  String get billingNoDueDate;

  /// No description provided for @billingPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get billingPlans;

  /// No description provided for @billingFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get billingFree;

  /// No description provided for @billingPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get billingPro;

  /// No description provided for @billingPerMonth.
  ///
  /// In en, this message translates to:
  /// **'per month'**
  String get billingPerMonth;

  /// No description provided for @billingVoucherTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem a voucher'**
  String get billingVoucherTitle;

  /// No description provided for @billingVoucherIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the code supplied with your payment.'**
  String get billingVoucherIntro;

  /// No description provided for @billingVoucherLabel.
  ///
  /// In en, this message translates to:
  /// **'Voucher code'**
  String get billingVoucherLabel;

  /// No description provided for @billingVoucherHint.
  ///
  /// In en, this message translates to:
  /// **'XXXX-XXXX-XXXX'**
  String get billingVoucherHint;

  /// No description provided for @billingRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get billingRedeem;

  /// No description provided for @billingInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get billingInvoices;

  /// No description provided for @billingNoInvoices.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet'**
  String get billingNoInvoices;

  /// No description provided for @billingInvoiceOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get billingInvoiceOpen;

  /// No description provided for @billingInvoicePaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get billingInvoicePaid;

  /// No description provided for @billingInvoiceCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get billingInvoiceCancelled;

  /// No description provided for @billingShare.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get billingShare;

  /// No description provided for @billingEvaluate.
  ///
  /// In en, this message translates to:
  /// **'Check subscription'**
  String get billingEvaluate;

  /// No description provided for @billingChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get billingChecking;

  /// No description provided for @billingLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading subscription...'**
  String get billingLoading;

  /// No description provided for @billingLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load billing information.'**
  String get billingLoadError;

  /// No description provided for @billingRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get billingRetry;

  /// No description provided for @billingQuotaBranches.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 branch} other{{count} branches}}'**
  String billingQuotaBranches(int count);

  /// No description provided for @billingQuotaUsers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 user} other{{count} users}}'**
  String billingQuotaUsers(int count);

  /// No description provided for @billingQuotaProducts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 product} other{{count} products}}'**
  String billingQuotaProducts(int count);

  /// No description provided for @billingBackstopMessage.
  ///
  /// In en, this message translates to:
  /// **'POS and inventory remain available while payment is pending.'**
  String get billingBackstopMessage;

  /// No description provided for @billingVoucherRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a voucher code.'**
  String get billingVoucherRequired;

  /// No description provided for @billingVoucherSuccess.
  ///
  /// In en, this message translates to:
  /// **'Voucher redeemed successfully.'**
  String get billingVoucherSuccess;

  /// No description provided for @billingShareSuccess.
  ///
  /// In en, this message translates to:
  /// **'Invoice ready to share.'**
  String get billingShareSuccess;

  /// No description provided for @billingShareError.
  ///
  /// In en, this message translates to:
  /// **'Could not share this invoice.'**
  String get billingShareError;

  /// No description provided for @billingInvoiceIssued.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get billingInvoiceIssued;

  /// No description provided for @billingInvoicePeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get billingInvoicePeriod;

  /// No description provided for @billingInvoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get billingInvoiceNumber;

  /// No description provided for @billingInvoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get billingInvoiceDescription;

  /// No description provided for @billingInvoiceAmountDue.
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get billingInvoiceAmountDue;

  /// No description provided for @billingInvoiceReference.
  ///
  /// In en, this message translates to:
  /// **'Payment reference'**
  String get billingInvoiceReference;

  /// No description provided for @billingInvoicePaidAt.
  ///
  /// In en, this message translates to:
  /// **'Paid on'**
  String get billingInvoicePaidAt;

  /// No description provided for @billingPriceLocked.
  ///
  /// In en, this message translates to:
  /// **'Selling price (renewal required)'**
  String get billingPriceLocked;

  /// No description provided for @billingPriceLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Renew your subscription to set selling and wholesale prices.'**
  String get billingPriceLockedMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
