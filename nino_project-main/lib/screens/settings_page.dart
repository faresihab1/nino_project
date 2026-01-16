import 'package:flutter/material.dart';
import 'package:nino/screens/getstartedscreen.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isSigningOut = false;
  bool _isChangingPassword = false;
  bool _isDeletingAccount = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $e')),
      );
      setState(() => _isSigningOut = false);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Getstartedscreen()),
      (_) => false,
    );
  }

  InputDecoration _dialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<String?> _promptForPassword({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: controller,
                    obscureText: true,
                    decoration: _dialogInputDecoration('Password'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Password is required.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final isValid = formKey.currentState?.validate() ?? false;
                  if (!isValid) return;
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<String?> _promptForNewPassword() async {
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Change password'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: newController,
                    obscureText: true,
                    decoration: _dialogInputDecoration('New password'),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.length < 6) {
                        return 'Password must be at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: _dialogInputDecoration('Confirm password'),
                    validator: (value) {
                      if (value == null || value != newController.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final isValid = formKey.currentState?.validate() ?? false;
                  if (!isValid) return;
                  Navigator.of(dialogContext).pop(newController.text.trim());
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      );
    } finally {
      newController.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _changePassword() async {
    if (_isChangingPassword) return;
    final newPassword = await _promptForNewPassword();
    if (newPassword == null || newPassword.isEmpty) return;

    setState(() => _isChangingPassword = true);
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPassword));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password update failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    final password = await _promptForPassword(
      title: 'Delete account',
      message: 'Enter your password to confirm account deletion.',
      confirmLabel: 'Delete',
    );
    if (password == null || password.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active account found.')),
      );
      return;
    }

    setState(() => _isDeletingAccount = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await Supabase.instance.client.auth.admin.deleteUser(user.id);
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Getstartedscreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete account failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Background(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(0, 145, 110, 1),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isChangingPassword ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromRGBO(246, 251, 250, 1),
                        foregroundColor:
                            const Color.fromRGBO(0, 145, 110, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isChangingPassword
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color.fromRGBO(0, 145, 110, 1),
                              ),
                            )
                          : const Text(
                              'Change password',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isDeletingAccount ? null : _deleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromRGBO(255, 242, 242, 1),
                        foregroundColor:
                            const Color.fromRGBO(168, 31, 31, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isDeletingAccount
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color.fromRGBO(168, 31, 31, 1),
                              ),
                            )
                          : const Text(
                              'Delete account',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSigningOut ? null : _signOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromRGBO(246, 251, 250, 1),
                        foregroundColor:
                            const Color.fromRGBO(0, 145, 110, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSigningOut
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color.fromRGBO(0, 145, 110, 1),
                              ),
                            )
                          : const Text(
                              'Log out',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
