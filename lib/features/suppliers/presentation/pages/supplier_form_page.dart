import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';

class SupplierFormPage extends ConsumerStatefulWidget {
  const SupplierFormPage({super.key, this.supplierId});

  final String? supplierId;

  @override
  ConsumerState<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends ConsumerState<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _tinController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplierId != null) _loadSupplier();
  }

  Future<void> _loadSupplier() async {
    try {
      final repo = ref.read(supplierRepositoryProvider);
      final data = await repo.getById(widget.supplierId!);
      if (mounted) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _contactNameController.text = data['contactName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? '';
          _addressController.text = data['address'] ?? '';
          _tinController.text = data['tin'] ?? '';
          _notesController.text = data['notes'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError('$e'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _tinController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplierId != null;
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(isEdit ? loc.supplierFormTitleEdit : loc.supplierFormTitleAdd),
      ),
      body: WaveBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: loc.supplierFormName),
                validator: (v) => v == null || v.trim().isEmpty
                    ? loc.supplierFormNameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactNameController,
                decoration: InputDecoration(labelText: loc.supplierFormContact),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: loc.settingsPhone),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: loc.settingsEmail),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: loc.settingsAddress),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tinController,
                decoration: InputDecoration(labelText: loc.settingsTIN),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(labelText: loc.purchasesNotes),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
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
                    : Text(isEdit ? loc.commonSave : loc.commonAdd),
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
      final body = <String, dynamic>{
        'name': _nameController.text.trim(),
        'contactName': _contactNameController.text.trim().isEmpty
            ? null
            : _contactNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'tin': _tinController.text.trim().isEmpty
            ? null
            : _tinController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'isActive': true,
      };

      final controller = ref.read(suppliersControllerProvider.notifier);
      if (widget.supplierId != null) {
        await controller.update(widget.supplierId!, body);
      } else {
        await controller.create(body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.supplierFormSaved)),
        );
        context.pop();
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
