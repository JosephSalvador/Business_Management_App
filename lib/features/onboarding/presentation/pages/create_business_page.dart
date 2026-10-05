import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/workspace_repository.dart';

const _businessTypeKeys = <String>[
  'retail',
  'wholesale',
  'services',
  'hospitality',
  'agriculture',
  'other',
];

const _countries = <String, String>{
  'TZ': 'Tanzania',
  'KE': 'Kenya',
  'UG': 'Uganda',
  'RW': 'Rwanda',
  'BI': 'Burundi',
};

const _currencies = ['TZS', 'KES', 'UGX', 'RWF', 'BIF', 'USD'];

String? _businessTypeLabel(AppLocalizations loc, String key) => switch (key) {
      'retail' => loc.businessTypeRetail,
      'wholesale' => loc.businessTypeWholesale,
      'services' => loc.businessTypeServices,
      'hospitality' => loc.businessTypeHospitality,
      'agriculture' => loc.businessTypeAgriculture,
      'other' => loc.businessTypeOther,
      _ => null,
    };

/// Onboarding wizard: name / type / country / currency / tax identity.
class CreateBusinessPage extends ConsumerStatefulWidget {
  const CreateBusinessPage({super.key});

  @override
  ConsumerState<CreateBusinessPage> createState() => _CreateBusinessPageState();
}

class _CreateBusinessPageState extends ConsumerState<CreateBusinessPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxIdController = TextEditingController();
  String _businessType = 'retail';
  String _countryCode = 'TZ';
  String _currency = 'TZS';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nameController, _phoneController, _taxIdController]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(workspaceControllerProvider.notifier).createBusiness(
            OnboardingDraft(
              name: _nameController.text,
              businessType: _businessType,
              countryCode: _countryCode,
              currency: _currency,
              contactPhone: _phoneController.text,
              taxId: _taxIdController.text,
            ),
          );
      if (mounted) context.go('/setup');
    } on AppException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(title: Text(loc.createBusinessTitle)),
      body: WaveBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress indicator
                      LinearProgressIndicator(
                        value: 0.5,
                        minHeight: 3,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                      ),
                      const SizedBox(height: 32),

                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: loc.createBusinessName,
                          prefixIcon:
                              const Icon(Icons.store_outlined, size: 20),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? loc.createBusinessNameRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _businessType,
                        decoration: InputDecoration(
                          labelText: loc.createBusinessType,
                          prefixIcon:
                              const Icon(Icons.category_outlined, size: 20),
                        ),
                        items: [
                          for (final key in _businessTypeKeys)
                            DropdownMenuItem(
                                value: key,
                                child: Text(_businessTypeLabel(loc, key)!)),
                        ],
                        onChanged: (value) =>
                            setState(() => _businessType = value ?? 'retail'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _countryCode,
                        decoration: InputDecoration(
                          labelText: loc.createBusinessCountry,
                          prefixIcon:
                              const Icon(Icons.public_outlined, size: 20),
                        ),
                        items: [
                          for (final entry in _countries.entries)
                            DropdownMenuItem(
                                value: entry.key, child: Text(entry.value)),
                        ],
                        onChanged: (value) => setState(() {
                          _countryCode = value ?? 'TZ';
                          if (_countryCode == 'TZ') _currency = 'TZS';
                        }),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: InputDecoration(
                          labelText: loc.createBusinessCurrency,
                          prefixIcon:
                              const Icon(Icons.attach_money_outlined, size: 20),
                        ),
                        items: [
                          for (final currency in _currencies)
                            DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _currency = value ?? 'TZS'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: loc.createBusinessPhone,
                          prefixIcon:
                              const Icon(Icons.phone_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _taxIdController,
                        decoration: InputDecoration(
                          labelText: loc.createBusinessTin,
                          prefixIcon:
                              const Icon(Icons.receipt_outlined, size: 20),
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : Text(loc.createBusinessStart),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
