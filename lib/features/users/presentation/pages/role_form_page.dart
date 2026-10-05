import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../roles/presentation/role_permission_groups.dart';

class RoleFormPage extends ConsumerStatefulWidget {
  const RoleFormPage({super.key, this.roleId});

  final String? roleId;

  @override
  ConsumerState<RoleFormPage> createState() => _RoleFormPageState();
}

class _RoleFormPageState extends ConsumerState<RoleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<String> _selectedPermissions = [];
  bool _saving = false;
  bool _loaded = false;
  bool _isSystemRole = false;
  bool _isAdministrator = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    try {
      final repository = ref.read(roleRepositoryProvider);
      await ref.read(permissionsProvider.future);

      List<String> rolePerms = [];
      if (widget.roleId != null) {
        rolePerms = await repository.rolePermissions(widget.roleId!);
        final role = await repository.getById(widget.roleId!);
        if (mounted) {
          _nameController.text = role.name;
          _descriptionController.text = role.description ?? '';
          _isSystemRole = role.isSystem;
          _isAdministrator = role.name == 'Administrator';
        }
      }

      if (mounted) {
        setState(() {
          _selectedPermissions = rolePerms;
          _loaded = true;
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
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.roleId != null;
    final allPermissionsAsync = ref.watch(permissionsProvider);
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? loc.roleFormTitleEdit : loc.roleFormTitleAdd),
      ),
      body: WaveBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_isSystemRole,
                decoration: InputDecoration(labelText: loc.roleFormName),
                validator: (v) => v == null || v.trim().isEmpty
                    ? loc.roleFormNameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isSystemRole,
                decoration: InputDecoration(labelText: loc.roleFormDescription),
                maxLines: 2,
              ),
              if (_isSystemRole) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.amber.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _isAdministrator
                          ? loc.roleFormSystemAdminNote
                          : loc.roleFormSystemNote,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                loc.roleFormPermissions,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              allPermissionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        loc.commonWithError('$e'),
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                ),
                data: (allPermissions) {
                  if (allPermissions.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            loc.roleFormNoPermissions,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children:
                        groupPermissionsByArea(allPermissions).map((group) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          title: Text(roleAreaLabel(loc, group.label)),
                          children: group.permissions.map((perm) {
                            final isSelected =
                                _selectedPermissions.contains(perm.name);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedPermissions.add(perm.name);
                                  } else {
                                    _selectedPermissions.remove(perm.name);
                                  }
                                });
                              },
                              title: Text(
                                perm.description ?? perm.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                perm.name,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade500),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_saving || !_loaded) ? null : _save,
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
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final permissions = _selectedPermissions;

      if (widget.roleId != null && _isSystemRole) {
        await ref.read(rolesControllerProvider.notifier).setPermissions(
              widget.roleId!,
              permissions,
            );
      } else if (widget.roleId != null) {
        await ref.read(rolesControllerProvider.notifier).update(
              widget.roleId!,
              name: name,
              description: description,
              permissions: permissions,
            );
      } else {
        await ref.read(rolesControllerProvider.notifier).create(
              name: name,
              description: description,
              permissions: permissions,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.roleFormSaved)),
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
