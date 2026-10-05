import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/money_account_providers.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';

class RecordIncomePage extends ConsumerStatefulWidget {
  const RecordIncomePage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<RecordIncomePage> createState() => _RecordIncomePageState();
}

class _RecordIncomePageState extends ConsumerState<RecordIncomePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.recordIncomeTitle),
      ),
      body: WaveBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.loc.recordAmountLabel,
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return context.loc.recordAmountRequired;
                  }
                  final amount = double.tryParse(v.trim());
                  if (amount == null || amount <= 0) {
                    return context.loc.recordAmountPositive;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: context.loc.recordDescriptionLabel,
                  prefixIcon: const Icon(Icons.description),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? context.loc.recordDescriptionRequired
                    : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.loc.recordIncomeTitle),
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
      await ref.read(moneyAccountsControllerProvider.notifier).recordIncome({
        'accountId': widget.accountId,
        'amount': double.parse(_amountController.text.trim()),
        'description': _descriptionController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.recordIncomeSuccess),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError(e.toString()))),
        );
      }
    }
  }
}
