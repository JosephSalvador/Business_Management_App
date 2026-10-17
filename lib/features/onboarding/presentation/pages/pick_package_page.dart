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
        final basePlans = plans.where((p) => !p.isPackage).toList();
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
    final basePlans = _plans.where((p) => !p.isPackage).toList();
    final packages = _plans.where((p) => p.isPackage).toList();

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

                  // Plans selection
                  if (basePlans.isNotEmpty) ...[
                    Text(
                      'Mpango wa Msingi (Base Plan)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...basePlans.map((plan) {
                      final isSelected = _selectedPlanCode == plan.code;
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            plan.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Matawi: ${plan.maxBranches ?? "Bila kikomo"} • Watumiaji: ${plan.maxUsers ?? "Bila kikomo"}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${plan.currency} ${plan.monthlyPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const Text(
                                '/mwezi',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          leading: Radio<String>(
                            value: plan.code,
                            groupValue: _selectedPlanCode,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedPlanCode = val);
                              }
                            },
                          ),
                          onTap: () {
                            setState(() => _selectedPlanCode = plan.code);
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Packages selection
                  if (packages.isNotEmpty) ...[
                    Text(
                      'Vifurushi vya Ziada (Add-on Modules)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...packages.map((pkg) {
                      final isChecked =
                          _selectedPackages.contains(pkg.code.toLowerCase());
                      return Card(
                        child: CheckboxListTile(
                          value: isChecked,
                          title: Text(
                            pkg.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '+${pkg.currency} ${pkg.monthlyPrice.toStringAsFixed(0)} /mwezi',
                          ),
                          secondary: const Icon(Icons.extension_outlined),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedPackages.add(pkg.code.toLowerCase());
                              } else {
                                _selectedPackages
                                    .remove(pkg.code.toLowerCase());
                              }
                            });
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

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
