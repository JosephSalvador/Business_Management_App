import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/loc.dart';
import '../../../../l10n/payment_labels.dart';
import '../../data/money_account_providers.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';

class CreateAccountPage extends ConsumerStatefulWidget {
  const CreateAccountPage({super.key});

  @override
  ConsumerState<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends ConsumerState<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _referenceController = TextEditingController();
  int _selectedType = 0;
  bool _saving = false;

  final List<(IconData, int)> _accountTypes = [
    (Icons.payments, 0),
    (Icons.phone_android, 1),
    (Icons.account_balance, 2),
    (Icons.more_horiz, 3),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.createAccountTitle),
      ),
      body: WaveBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: loc.createAccountNameLabel,
                  hintText: loc.createAccountNameHint,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? loc.createAccountNameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                loc.createAccountTypeLabel,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _accountTypes.map((t) {
                  final (icon, value) = t;
                  final selected = _selectedType == value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF0066FF).withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF0066FF)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon,
                              size: 18,
                              color: selected
                                  ? const Color(0xFF0066FF)
                                  : Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            moneyAccountTypeLabel(loc, value),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? const Color(0xFF0066FF)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: loc.createAccountReferenceLabel,
                  hintText: loc.createAccountReferenceHint,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(loc.createAccountSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await ref.read(moneyAccountsControllerProvider.notifier).createAccount({
        'name': _nameController.text.trim(),
        'type': _selectedType,
        if (_referenceController.text.isNotEmpty)
          'reference': _referenceController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.moneyAccountSaved)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError('$e'))),
        );
      }
    }
  }
}
