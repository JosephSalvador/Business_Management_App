import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/storage/locale_store.dart';
import '../../../../core/storage/theme_store.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/settings_controller.dart';
import '../../data/organization_repository.dart';
import '../../../authentication/presentation/widgets/quick_pin_setup_sheet.dart';
import '../../../receipts/domain/receipt_format.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(title: Text(loc.settingsTitle)),
      body: WaveBackground(
        child: switch (settings) {
          SettingsLoading() => const Center(child: CircularProgressIndicator()),
          final SettingsFailure failure => Center(
              child: Text(failure.message,
                  style: TextStyle(
                      color: AppColors.resolveTextSecondary(context))),
            ),
          final SettingsLoaded loaded =>
            _buildBody(context, ref, loaded.organization),
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    Organization organization,
  ) {
    final loc = context.loc;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: loc.settingsBusinessInfo,
          children: [
            _SettingsTile(
              icon: Icons.store_outlined,
              title: loc.settingsBusinessName,
              subtitle: organization.name ?? '-',
              onTap: () => _editOrganization(context, ref, organization),
            ),
            _SettingsTile(
              icon: Icons.location_on_outlined,
              title: loc.settingsAddress,
              subtitle: organization.address ?? '-',
              onTap: () => _editOrganization(context, ref, organization),
            ),
            _SettingsTile(
              icon: Icons.phone_outlined,
              title: loc.settingsPhone,
              subtitle: organization.phone ?? '-',
              onTap: () => _editOrganization(context, ref, organization),
            ),
            _SettingsTile(
              icon: Icons.email_outlined,
              title: loc.settingsEmail,
              subtitle: organization.email ?? '-',
              onTap: () => _editOrganization(context, ref, organization),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: loc.settingsTax,
          children: [
            _SettingsTile(
              icon: Icons.receipt_outlined,
              title: loc.settingsTIN,
              subtitle: organization.taxId ?? '-',
              onTap: () => _editOrganization(context, ref, organization),
            ),
            _SettingsTile(
              icon: Icons.public_outlined,
              title: loc.settingsCountry,
              subtitle: organization.countryCode ?? 'TZ',
              onTap: () => _editOrganization(context, ref, organization),
            ),
            _SettingsTile(
              icon: Icons.attach_money_outlined,
              title: loc.settingsCurrency,
              subtitle: organization.currency ?? 'TZS',
              onTap: () => _editOrganization(context, ref, organization),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: loc.settingsPersonalInfo,
          children: [
            _SettingsTile(
              icon: Icons.person_outline,
              title: loc.settingsProfile,
              subtitle: loc.settingsEditProfile,
              onTap: () => context.push('/profile'),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: loc.settingsChangePassword,
              subtitle: loc.settingsUpdatePassword,
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.phonelink_lock_outlined,
              title: loc.securityTwoFactorSection,
              subtitle: loc.securitySessionsIntro,
              onTap: () => context.push(Routes.security),
            ),
            const _QuickPinSettingsTile(),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: loc.settingsApp,
          children: [
            _ThemeModeTile(),
            _LanguageTile(),
            const _PrinterPaperSizeTile(),
            _SettingsTile(
              icon: Icons.access_time_outlined,
              title: loc.settingsTimezone,
              subtitle: AppConfig.instance.timezone,
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: loc.settingsNotifications,
              subtitle: loc.settingsPhoneEmail,
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: loc.settingsAbout,
              subtitle: 'JOLINX Business OS v1.0.0',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  void _editOrganization(
    BuildContext context,
    WidgetRef ref,
    Organization organization,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditOrgSheet(
        organization: organization,
        onSave: (body) => ref
            .read(settingsControllerProvider.notifier)
            .updateOrganization(body),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.resolveTextSecondary(context),
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(child: Column(children: children)),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
            color: AppColors.resolveTextSecondary(context), fontSize: 13),
      ),
      trailing: Icon(Icons.chevron_right,
          color: AppColors.resolveTextTertiary(context), size: 20),
      onTap: onTap,
    );
  }
}

class _EditOrgSheet extends StatefulWidget {
  const _EditOrgSheet({required this.organization, required this.onSave});
  final Organization organization;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  @override
  State<_EditOrgSheet> createState() => _EditOrgSheetState();
}

class _EditOrgSheetState extends State<_EditOrgSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _taxIdController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.organization.name ?? '');
    _addressController =
        TextEditingController(text: widget.organization.address ?? '');
    _phoneController =
        TextEditingController(text: widget.organization.phone ?? '');
    _emailController =
        TextEditingController(text: widget.organization.email ?? '');
    _taxIdController =
        TextEditingController(text: widget.organization.taxId ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _addressController,
      _phoneController,
      _emailController,
      _taxIdController
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.settingsEditBusiness,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.resolveTextPrimary(context),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
                controller: _nameController,
                decoration:
                    InputDecoration(labelText: loc.settingsBusinessName)),
            const SizedBox(height: 14),
            TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: loc.settingsAddress)),
            const SizedBox(height: 14),
            TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: loc.settingsPhone)),
            const SizedBox(height: 14),
            TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: loc.settingsEmail)),
            const SizedBox(height: 14),
            TextFormField(
                controller: _taxIdController,
                decoration: InputDecoration(labelText: loc.settingsTIN)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary),
                      )
                    : Text(loc.commonSave),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'name': _nameController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'taxId': _taxIdController.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.settingsSaved)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ThemeModeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeControllerProvider);
    final loc = context.loc;
    final label = switch (currentMode) {
      ThemeMode.system => loc.settingsThemeSystem,
      ThemeMode.light => loc.settingsThemeLight,
      ThemeMode.dark => loc.settingsThemeDark,
    };
    final icon = switch (currentMode) {
      ThemeMode.system => Icons.brightness_auto,
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
    };
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        loc.settingsAppearance,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        label,
        style: TextStyle(
            color: AppColors.resolveTextSecondary(context), fontSize: 13),
      ),
      trailing: Icon(Icons.chevron_right,
          color: AppColors.resolveTextTertiary(context), size: 20),
      onTap: () => _showThemePicker(context, ref, currentMode),
    );
  }

  void _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) {
    final loc = context.loc;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.settingsAppearancePicker,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.resolveTextPrimary(context),
                  ),
                ),
              ),
            ),
            _ThemeOption(
              icon: Icons.brightness_auto,
              title: loc.settingsThemeSystem,
              subtitle: loc.settingsThemeSystem,
              selected: current == ThemeMode.system,
              onTap: () {
                ref
                    .read(themeModeControllerProvider.notifier)
                    .setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              icon: Icons.light_mode,
              title: loc.settingsThemeLight,
              subtitle: loc.settingsThemeAlwaysLight,
              selected: current == ThemeMode.light,
              onTap: () {
                ref
                    .read(themeModeControllerProvider.notifier)
                    .setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              icon: Icons.dark_mode,
              title: loc.settingsThemeDark,
              subtitle: loc.settingsThemeAlwaysDark,
              selected: current == ThemeMode.dark,
              onTap: () {
                ref
                    .read(themeModeControllerProvider.notifier)
                    .setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: selected
              ? AppColors.primary
              : AppColors.resolveTextSecondary(context),
          size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: selected
              ? AppColors.primary
              : AppColors.resolveTextPrimary(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
            color: AppColors.resolveTextSecondary(context), fontSize: 13),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeControllerProvider);
    final label = switch (current.languageCode) {
      'sw' => 'Kiswahili',
      'en' => 'English',
      _ => current.languageCode,
    };
    return ListTile(
      leading:
          Icon(Icons.language_outlined, color: AppColors.primary, size: 22),
      title: Text(
        context.loc.settingsLanguage,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        label,
        style: TextStyle(
            color: AppColors.resolveTextSecondary(context), fontSize: 13),
      ),
      trailing: Icon(Icons.chevron_right,
          color: AppColors.resolveTextTertiary(context), size: 20),
      onTap: () => _showLanguagePicker(context, ref, current),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    Locale current,
  ) {
    final loc = context.loc;
    final options = [
      (locale: const Locale('sw'), name: 'Kiswahili', native: 'Kiswahili'),
      (locale: const Locale('en'), name: 'English', native: 'English'),
    ];
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.settingsLanguagePicker,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.resolveTextPrimary(context),
                  ),
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(
                  Icons.translate,
                  color: current == option.locale
                      ? AppColors.primary
                      : AppColors.resolveTextSecondary(context),
                  size: 22,
                ),
                title: Text(
                  option.native,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: current == option.locale
                        ? AppColors.primary
                        : AppColors.resolveTextPrimary(context),
                  ),
                ),
                subtitle: Text(
                  option.name,
                  style: TextStyle(
                    color: AppColors.resolveTextSecondary(context),
                    fontSize: 13,
                  ),
                ),
                trailing: current == option.locale
                    ? const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 20)
                    : null,
                onTap: () {
                  ref
                      .read(localeControllerProvider.notifier)
                      .setLocale(option.locale);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PrinterPaperSizeTile extends ConsumerWidget {
  const _PrinterPaperSizeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(receiptPaperWidthProvider);
    final isSw = Localizations.localeOf(context).languageCode == 'sw';

    final label = switch (current) {
      ReceiptPaperWidth.mm58 => isSw
          ? '58 mm (POS / Handheld ya Mkononi)'
          : '58 mm (Handheld POS)',
      ReceiptPaperWidth.mm80 => isSw
          ? '80 mm (Printi ya Kaunta / Desktop)'
          : '80 mm (Counter / Desktop)',
    };

    return ListTile(
      leading:
          const Icon(Icons.print_outlined, color: AppColors.primary, size: 22),
      title: Text(
        isSw ? 'Ukubwa wa Karatasi ya Risiti' : 'Receipt Paper Size',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        label,
        style: TextStyle(
          color: AppColors.resolveTextSecondary(context),
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.resolveTextTertiary(context),
        size: 20,
      ),
      onTap: () => _showPicker(context, ref, current, isSw),
    );
  }

  void _showPicker(
    BuildContext context,
    WidgetRef ref,
    ReceiptPaperWidth current,
    bool isSw,
  ) {
    final options = [
      (
        width: ReceiptPaperWidth.mm80,
        name: isSw ? '80 mm (Printi ya Kaunta)' : '80 mm (Counter Printer)',
        desc: isSw
            ? 'Printi ya kawaida ya mezani/kaunta (safu 42 za herufi)'
            : 'Standard counter thermal printer (42 columns)',
        icon: Icons.receipt_long,
      ),
      (
        width: ReceiptPaperWidth.mm58,
        name: isSw ? '58 mm (POS ya Mkononi)' : '58 mm (Handheld POS)',
        desc: isSw
            ? 'Printi ndogo ya Bluetooth ya mkononi (safu 32 za herufi)'
            : 'Portable handheld Bluetooth printer (32 columns)',
        icon: Icons.receipt,
      ),
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isSw
                      ? 'Chagua Ukubwa wa Karatasi ya Risiti'
                      : 'Choose Receipt Paper Size',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.resolveTextPrimary(context),
                  ),
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(
                  option.icon,
                  color: current == option.width
                      ? AppColors.primary
                      : AppColors.resolveTextSecondary(context),
                  size: 22,
                ),
                title: Text(
                  option.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: current == option.width
                        ? AppColors.primary
                        : AppColors.resolveTextPrimary(context),
                  ),
                ),
                subtitle: Text(
                  option.desc,
                  style: TextStyle(
                    color: AppColors.resolveTextSecondary(context),
                    fontSize: 12.5,
                  ),
                ),
                trailing: current == option.width
                    ? const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 20)
                    : null,
                onTap: () {
                  ref
                      .read(receiptPaperWidthProvider.notifier)
                      .setWidth(option.width);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _QuickPinSettingsTile extends ConsumerStatefulWidget {
  const _QuickPinSettingsTile();

  @override
  ConsumerState<_QuickPinSettingsTile> createState() =>
      _QuickPinSettingsTileState();
}

class _QuickPinSettingsTileState extends ConsumerState<_QuickPinSettingsTile> {
  bool _loading = true;
  bool _hasPin = false;
  bool _biometricHardware = false;
  String _biometricLabel = 'Alama ya Kidole au Uso';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final store = ref.read(offlineCredentialStoreProvider);
    final gate = ref.read(biometricAuthGateProvider);
    final hasPin = await store.hasUnlockPin();
    final hardware = await gate.isAvailable();
    final label = await gate.biometricLabel();

    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _biometricHardware = hardware;
        _biometricLabel = label;
        _loading = false;
      });
    }
  }

  Future<void> _setupOrChangePin() async {
    final ok = await showQuickPinSetupSheet(
      context,
      biometricSupported: _biometricHardware,
      biometricLabel: _biometricLabel,
      onSave: ({required pin, required enableBiometric}) async {
        await ref.read(authControllerProvider.notifier).enableQuickPin(
              pin: pin,
              enableBiometric: enableBiometric,
            );
      },
    );
    if (ok) {
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN ya haraka imewekwa kikamilifu!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _disablePin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zima PIN ya Haraka?'),
        content: const Text(
          'Utahitaji kuingiza nenosiri kamili la akaunti yako kila wakati unapoingia kwenye kifaa hiki.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zima PIN'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authControllerProvider.notifier).disableQuickPin();
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN ya haraka imezimwa.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return ListTile(
      leading: Icon(
        Icons.pin_outlined,
        color: _hasPin ? AppColors.success : AppColors.primary,
        size: 22,
      ),
      title: const Text(
        'PIN ya Haraka na Biometrics',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _hasPin
            ? 'Imewashwa ($_biometricLabel)'
            : 'Weka PIN ya tarakimu 4 kufungua app haraka',
        style: TextStyle(
          color: _hasPin
              ? AppColors.success
              : AppColors.resolveTextSecondary(context),
          fontSize: 13,
        ),
      ),
      trailing: _hasPin
          ? PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'change') _setupOrChangePin();
                if (val == 'disable') _disablePin();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'change',
                  child: Text('Badili PIN'),
                ),
                const PopupMenuItem(
                  value: 'disable',
                  child: Text('Zima PIN'),
                ),
              ],
            )
          : TextButton(
              onPressed: _setupOrChangePin,
              child: const Text('Weka Sasa'),
            ),
      onTap: _hasPin ? null : _setupOrChangePin,
    );
  }
}

