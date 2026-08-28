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
}
