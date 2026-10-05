import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';

class UserFormPage extends ConsumerStatefulWidget {
  const UserFormPage({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends ConsumerState<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  List<String> _selectedRoleIds = [];
  bool _saving = false;
  bool _loadingUser = false;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    setState(() => _loadingUser = true);
    try {
      final repository = ref.read(userRepositoryProvider);
      final user = await repository.getById(widget.userId!);
      if (mounted) {
        setState(() {
          _emailController.text = user.email;
          _fullNameController.text = user.fullName;
          _phoneController.text = user.phone ?? '';
          _selectedRoleIds = user.roleIds;
          _loadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingUser = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError('$e'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.userId != null;
    final rolesAsync = ref.watch(rolesProvider);
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? loc.userFormTitleEdit : loc.userFormTitleAdd),
      ),
      body: WaveBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: loc.userFormEmail),
                keyboardType: TextInputType.emailAddress,
                enabled: !isEdit,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return loc.userFormEmailRequired;
                  }
                  if (!v.contains('@')) {
                    return loc.emailInvalidShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(labelText: loc.userFormName),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return loc.userFormNameRequired;
                  }
                  if (v.trim().length > 200) {
                    return loc.userFormNameTooLong;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: loc.settingsPhone),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              Text(
                loc.userFormRoles,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (_loadingUser)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ...rolesAsync.when(
                  data: (roles) {
                    if (roles.isEmpty) {
                      return [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                loc.userFormNoRoles,
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ),
                          ),
                        ),
                      ];
                    }
                    return roles.map((role) {
                      final isSelected = _selectedRoleIds.contains(role.id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedRoleIds.add(role.id);
                              } else {
                                _selectedRoleIds.remove(role.id);
                              }
                            });
                          },
                          title: Text(role.name),
                          subtitle: role.description != null
                              ? Text(role.description!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500))
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      );
                    }).toList();
                  },
                  loading: () => [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            loc.commonWithError('$e'),
                            style: TextStyle(color: Colors.red.shade500),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
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
      final isEdit = widget.userId != null;

      if (isEdit) {
        final body = <String, dynamic>{
          'fullName': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        };
        final controller = ref.read(usersControllerProvider.notifier);
        await controller.update(widget.userId!, body);
        await ref.read(userRepositoryProvider).setRoles(
              widget.userId!,
              _selectedRoleIds,
            );
      } else {
        final body = <String, dynamic>{
          'email': _emailController.text.trim(),
          'password': 'Temp1234!',
          'fullName': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          'roleIds': _selectedRoleIds,
          'branchIds': <String>[],
        };
        final controller = ref.read(usersControllerProvider.notifier);
        await controller.create(body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.userFormSaved)),
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
