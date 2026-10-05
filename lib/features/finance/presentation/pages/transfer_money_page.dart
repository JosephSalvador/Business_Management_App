import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/loc.dart';
import '../../data/money_account_providers.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';

class TransferMoneyPage extends ConsumerStatefulWidget {
  const TransferMoneyPage({super.key, this.fromAccountId});

  final String? fromAccountId;

  @override
  ConsumerState<TransferMoneyPage> createState() => _TransferMoneyPageState();
}

class _TransferMoneyPageState extends ConsumerState<TransferMoneyPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _fromAccountId;
  String? _toAccountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fromAccountId = widget.fromAccountId;
    Future.microtask(
        () => ref.read(moneyAccountsControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(moneyAccountsControllerProvider);
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.transferTitle),
      ),
      body: WaveBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (accountsState is MoneyAccountsLoaded) ...[
                DropdownButtonFormField<String>(
                  initialValue: _fromAccountId,
                  decoration: InputDecoration(
                    labelText: loc.transferFromLabel,
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                  ),
                  items: accountsState.accounts
                      .where((a) => (a['isActive'] ?? true))
                      .map<DropdownMenuItem<String>>((a) {
                    return DropdownMenuItem(
                      value: a['id'] as String,
                      child: Text(a['name'] as String),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _fromAccountId = v;
                    if (v != null && _toAccountId == v) _toAccountId = null;
                  }),
                  validator: (v) => v == null ? loc.transferFromRequired : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _toAccountId,
                  decoration: InputDecoration(
                    labelText: loc.transferToLabel,
                    prefixIcon:
                        const Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: accountsState.accounts
                      .where((a) =>
                          (a['isActive'] ?? true) && a['id'] != _fromAccountId)
                      .map<DropdownMenuItem<String>>((a) {
                    return DropdownMenuItem(
                      value: a['id'] as String,
                      child: Text(a['name'] as String),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _toAccountId = v),
                  validator: (v) => v == null ? loc.transferToRequired : null,
                ),
              ] else if (accountsState is MoneyAccountsLoading) ...[
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: loc.transferAmountLabel,
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return loc.transferAmountRequired;
                  }
                  final amount = double.tryParse(v.trim());
                  if (amount == null || amount <= 0) {
                    return loc.transferAmountPositive;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: loc.transferDescriptionLabel,
                  prefixIcon: const Icon(Icons.description),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? loc.transferDescriptionRequired
                    : null,
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
                      : Text(loc.transferSubmit),
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
      await ref.read(moneyAccountsControllerProvider.notifier).transfer({
        'fromAccountId': _fromAccountId,
        'toAccountId': _toAccountId,
        'amount': double.parse(_amountController.text.trim()),
        'description': _descriptionController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.transferSuccess),
            backgroundColor: const Color(0xFF0066FF),
          ),
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
