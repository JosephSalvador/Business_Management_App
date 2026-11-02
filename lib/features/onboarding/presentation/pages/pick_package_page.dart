import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/design_system/responsive.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../billing/application/billing_providers.dart';
import '../../../billing/data/billing_providers.dart';
import '../../../billing/domain/billing.dart';

class PickPackagePage extends ConsumerStatefulWidget {
  const PickPackagePage({super.key});

  @override
  ConsumerState<PickPackagePage> createState() => _PickPackagePageState();
}

class _PickPackagePageState extends ConsumerState<PickPackagePage> {
  final _voucherController = TextEditingController();
  List<BillingPlan> _plans = const [];
  bool _isLoading = true;
  String? _selectedPlanCode;
  final Set<String> _selectedPackages = {};
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(billingRepositoryProvider);
      final plans = await repo.listPlans();

      if (!mounted) return;
      setState(() {
        _plans = plans;
        final basePlans = _plans
            .where((p) => !p.isPackage && p.code.toLowerCase() != 'free')
            .toList();
        if (basePlans.isNotEmpty) {
          _selectedPlanCode = basePlans.first.code;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Imeshindwa kupakia vifurushi. Unaweza kuendelea na kusanidi baadaye.';
      });
    }
  }

  Future<void> _pasteVoucher() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty) {
        final normalized = VoucherCode.normalize(text);
        setState(() {
          _voucherController.text = normalized;
        });
        _showMessage('Vocha imebandikwa: $normalized');
      }
    } catch (_) {}
  }

  Future<void> _redeemVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(billingControllerProvider.notifier).redeemVoucher(code);
      if (!mounted) return;
      _showMessage('Vocha imetumika kikamilifu!');
      context.go(Routes.setup);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Hitilafu kwenye vocha. Tafadhali hakiki.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _continue() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(billingControllerProvider.notifier);
      for (final pkg in _selectedPackages) {
        await notifier.activatePackage(pkg);
      }
      if (!mounted) return;
      context.go(Routes.setup);
    } catch (e) {
      if (!mounted) return;
      context.go(Routes.setup);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final basePlans = _plans
        .where((p) => !p.isPackage && p.code.toLowerCase() != 'free')
        .toList();
    final packages = _plans
        .where((p) => p.isPackage && p.code.toLowerCase() != 'free')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chagua Kifurushi'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => context.go(Routes.setup),
            child: const Text('Ruka (Skip)'),
          ),
        ],
      ),
      body: WaveBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: Responsive.getPagePadding(context),
                children: [
                  LinearProgressIndicator(
                    value: 0.66,
                    minHeight: 4,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  const SizedBox(height: 20),

                  // Free trial banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded,
                            color: Colors.white, size: 36),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Majaribio ya Siku 14 Bure!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Anza kutumia mfumo bure bila malipo ya awali wala kadi ya benki.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Business Persona Selection
                  Text(
                    'Biashara yako inafanya nini zaidi?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chagua ili mfumo ujipange kiotomatiki kwa mahitaji yako:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Persona 1: Invoicing & Services
                  _PersonaCard(
                    title: '1. Huduma & Ankara (Invoicing)',
                    tag: 'Inashauriwa kwa Mafundi, Washauri & Wasambazaji',
                    description:
                        'Utoaji wa Ankara za PDF & Mashine ya POS, Nukuu (Quotes), Proforma, na usimamizi wa wateja.',
                    icon: Icons.receipt_long_rounded,
                    accentColor: const Color(0xFF0D9488),
                    isSelected: _selectedPackages.contains('invoice-manager') &&
                        _selectedPlanCode != 'Pro',
                    priceText: 'TZS 15,000 / mwezi',
                    onTap: () {
                      setState(() {
                        _selectedPlanCode = 'Free';
                        _selectedPackages.clear();
                        _selectedPackages.add('invoice-manager');
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Persona 2: Retail Shop & POS
                  _PersonaCard(
                    title: '2. Duka & Mauzo ya Rejareja (Retail Shop)',
                    tag: 'Inashauriwa kwa Maduka ya Mtaani, Vyakula & Bidhaa',
                    description:
                        'Mauzo ya haraka ya POS, kukata risiti za wateja, kuhesabu stoo (stokisi) na kurekodi faida.',
                    icon: Icons.point_of_sale_rounded,
                    accentColor: const Color(0xFF1565C0),
                    isSelected: _selectedPlanCode == 'Pro' &&
                        !_selectedPackages.contains('invoice-manager'),
                    priceText: 'Siku 14 Bure (Kisha TZS 25,000/mwezi)',
                    onTap: () {
                      setState(() {
                        _selectedPlanCode = 'Pro';
                        _selectedPackages.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Persona 3: All-In-One Enterprise
                  _PersonaCard(
                    title: '3. Mfumo Kamili (Duka + Ankara Kubwa)',
                    tag: 'Maduka Makubwa, Ya Jumla & Kampuni',
                    description:
                        'Kila kitu kimefunguliwa: Mauzo ya POS, Stoo ya bidhaa, Ankara za kampuni, Matawi 3 na Ripoti kamili.',
                    icon: Icons.business_center_rounded,
                    accentColor: const Color(0xFF6366F1),
                    isSelected: _selectedPlanCode == 'Pro' &&
                        _selectedPackages.contains('invoice-manager'),
                    priceText: 'Siku 14 Bure kwa Vyote',
                    onTap: () {
                      setState(() {
                        _selectedPlanCode = 'Pro';
                        _selectedPackages.clear();
                        _selectedPackages.add('invoice-manager');
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Voucher input
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.confirmation_num_outlined,
                                  color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Una Vocha ya Malipo?',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Kama ulishafanya malipo kupitia benki au simu, weka nambari ya vocha uliyopewa hapa:',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _voucherController,
                                  decoration: InputDecoration(
                                    hintText: 'JLX-XXXX-XXXX',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.paste_rounded,
                                          size: 18),
                                      tooltip: 'Bandika',
                                      onPressed: _pasteVoucher,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: _isSaving ? null : _redeemVoucher,
                                child: const Text('Thibitisha'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSaving ? null : _continue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Endelea na Mipangilio (Siku 14 Bure)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.title,
    required this.tag,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.priceText,
    required this.onTap,
  });

  final String title;
  final String tag;
  final String description;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final String priceText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.resolveCardBackground(context)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accentColor : AppColors.resolveBorder(context),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_off,
                    color: isSelected
                        ? accentColor
                        : AppColors.resolveTextTertiary(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.resolveTextSecondary(context),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.resolveSurfaceSecondary(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on_rounded,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      priceText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
