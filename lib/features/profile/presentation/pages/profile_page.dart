import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.profileTitle),
      ),
      body: WaveBackground(
        child: state is ProfileLoading
            ? const Center(child: CircularProgressIndicator())
            : state is ProfileFailure
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => ref
                              .read(profileControllerProvider.notifier)
                              .load(),
                          child: Text(context.loc.commonRetry),
                        ),
                      ],
                    ),
                  )
                : _buildProfile(state as ProfileLoaded),
      ),
    );
  }

  Widget _buildProfile(ProfileLoaded loaded) {
    final profile = loaded.profile;
    final name = profile.fullName.isNotEmpty ? profile.fullName : profile.email;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final loc = context.loc;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF0066FF).withValues(alpha: 0.1),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0066FF),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            profile.email,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ),
        if (profile.phone != null && profile.phone!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              profile.phone!,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ),
        ],
        const SizedBox(height: 32),
        Card(
          child: Column(
            children: [
              _profileTile(
                icon: Icons.person,
                title: loc.profileChangeName,
                subtitle: name,
                onTap: _editName,
              ),
              const Divider(height: 1),
              _profileTile(
                icon: Icons.phone,
                title: loc.settingsPhone,
                subtitle: profile.phone != null && profile.phone!.isNotEmpty
                    ? profile.phone!
                    : loc.profileAddPhone,
                onTap: _editPhone,
              ),
              const Divider(height: 1),
              _profileTile(
                icon: Icons.lock,
                title: loc.settingsChangePassword,
                subtitle: loc.settingsUpdatePassword,
                onTap: _changePassword,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _profileTile(
                icon: Icons.business,
                title: loc.profileBusiness,
                subtitle: profile.tenantName,
                onTap: () {},
              ),
              const Divider(height: 1),
              _profileTile(
                icon: Icons.security,
                title: loc.navRoles,
                subtitle: profile.roleNames.join(', '),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _confirmLogout(context),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.profileSignOut),
          ),
        ),
      ],
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0066FF)),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _editName() {
    final loc = context.loc;
    final current = ref.read(profileControllerProvider);
    if (current is! ProfileLoaded) return;
    final controller = TextEditingController(text: current.profile.fullName);
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.profileChangeNameTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: loc.profileNameLabel),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.commonSave),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      final newName = controller.text.trim();
      if (newName.isEmpty) return;
      try {
        await ref
            .read(profileControllerProvider.notifier)
            .updateProfile(fullName: newName);
        _showSuccess(loc.profileSaved);
      } on AppException catch (e) {
        _showError(e.message);
      }
    });
  }

  void _editPhone() {
    final loc = context.loc;
    final current = ref.read(profileControllerProvider);
    if (current is! ProfileLoaded) return;
    final controller = TextEditingController(text: current.profile.phone ?? '');
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.profileChangePhoneTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: loc.settingsPhone),
          keyboardType: TextInputType.phone,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.commonSave),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      final newPhone = controller.text.trim();
      try {
        await ref
            .read(profileControllerProvider.notifier)
            .updateProfile(phone: newPhone.isEmpty ? null : newPhone);
        _showSuccess(loc.profileSaved);
      } on AppException catch (e) {
        _showError(e.message);
      }
    });
  }

  void _changePassword() {
    final loc = context.loc;
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.profileChangePasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              decoration:
                  InputDecoration(labelText: loc.profileCurrentPassword),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              decoration: InputDecoration(labelText: loc.profileNewPassword),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(labelText: loc.profileRepeatPassword),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.profileChangeAction),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      final current = currentController.text;
      final newPass = newController.text;
      final confirm = confirmController.text;
      if (current.isEmpty || newPass.isEmpty || newPass != confirm) {
        _showError(loc.profilePasswordsMismatch);
        return;
      }
      try {
        await ref.read(profileControllerProvider.notifier).changePassword(
              currentPassword: current,
              newPassword: newPass,
            );
        _showSuccess(loc.profileSaved);
      } on AppException catch (e) {
        _showError(e.message);
      } finally {
        currentController.dispose();
        newController.dispose();
        confirmController.dispose();
      }
    });
  }

  void _confirmLogout(BuildContext context) {
    final loc = context.loc;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.moreLogoutConfirm),
        content: Text(loc.moreLogoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(loc.moreLogoutStay),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(authControllerProvider.notifier).logout();
            },
            child: Text(loc.profileSignOut),
          ),
        ],
      ),
    );
  }
}
