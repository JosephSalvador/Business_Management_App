import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/app_exception.dart';
import '../../data/workspace_repository.dart';

/// Business types accepted by the backend validator.
const _businessTypes = <String, String>{
  'retail': 'Maduka (Rejareja)',
  'wholesale': 'Jumla',
  'services': 'Huduma',
  'hospitality': 'Usafiri na Mapumziko',
  'agriculture': 'Kilimo',
  'other': 'Nyingine',
};

const _countries = <String, String>{
  'TZ': 'Tanzania',
  'KE': 'Kenya',
  'UG': 'Uganda',
  'RW': 'Rwanda',
  'BI': 'Burundi',
};

const _currencies = ['TZS', 'KES', 'UGX', 'RWF', 'BIF', 'USD'];

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
    for (final controller in [_nameController, _phoneController, _taxIdController]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) {
      return;
    }
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
      // Straight into first-run setup ("Tuanzishe biashara yako"), which
      // prepares starter units and hands over to the products screen.
      if (mounted) {
        context.go('/setup');
      }
    } on AppException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anzisha biashara')),
      body: SafeArea(
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
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Jina la biashara',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Weka jina la biashara' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _businessType,
                      decoration: const InputDecoration(
                        labelText: 'Aina ya biashara',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final entry in _businessTypes.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _businessType = value ?? 'retail'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _countryCode,
                      decoration: const InputDecoration(
                        labelText: 'Nchi',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final entry in _countries.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _countryCode = value ?? 'TZ';
                        if (_countryCode == 'TZ') {
                          _currency = 'TZS';
                        }
                      }),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Sarafu',
                        border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        labelText: 'Simu ya mawasiliano',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _taxIdController,
                      decoration: const InputDecoration(
                        labelText: 'Kodi (TIN) — si lazima',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'Inaanzisha…' : 'Kamilisha'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
