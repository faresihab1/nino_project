import 'package:flutter/material.dart';
import 'package:nino/widgets/background.dart';
import 'package:nino/widgets/profile_info_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isSaving = false;
  int _refreshToken = 0;

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

  String? _metadataPhone(Map<String, dynamic>? metadata) {
    final raw = metadata?['phone'] ?? metadata?['phone_number'];
    final phone = raw?.toString().trim();
    return (phone == null || phone.isEmpty) ? null : phone;
  }

  String? _metadataName(Map<String, dynamic>? metadata) {
    final raw = metadata?['name'];
    final name = raw?.toString().trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<_ProfileDraft> _loadProfileDraft(User user) async {
    String? name;
    String? phone;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('name, phone_number')
          .eq('id', user.id)
          .maybeSingle();

      final profileName = data?['name']?.toString().trim();
      if (profileName != null && profileName.isNotEmpty) {
        name = profileName;
      }

      final profilePhone = data?['phone_number']?.toString().trim();
      if (profilePhone != null && profilePhone.isNotEmpty) {
        phone = profilePhone;
      }
    } catch (_) {
      // Fall back to auth metadata if profile lookup fails.
    }

    if (phone == null) {
      final authPhone = user.phone?.trim();
      if (authPhone != null && authPhone.isNotEmpty) {
        phone = authPhone;
      } else {
        phone = _metadataPhone(user.userMetadata);
      }
    }

    name ??= _metadataName(user.userMetadata);

    return _ProfileDraft(
      name: name ?? '',
      phone: phone ?? '',
    );
  }

  Future<_ProfileDraft?> _promptForProfileEdit(_ProfileDraft current) async {
    final nameController = TextEditingController(text: current.name);
    final phoneController = TextEditingController(text: current.phone);

    try {
      return await showDialog<_ProfileDraft>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: _dialogInputDecoration('Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: _dialogInputDecoration('Phone'),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(
                    _ProfileDraft(
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> _editProfile() async {
    if (_isSaving) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active session.')),
      );
      return;
    }

    final current = await _loadProfileDraft(user);
    if (!mounted) return;
    final updated = await _promptForProfileEdit(current);
    if (!mounted) return;
    if (updated == null) return;

    final name = updated.name.trim();
    final phone = updated.phone.trim();
    final normalizedName = name.isEmpty ? null : name;
    final normalizedPhone = phone.isEmpty ? null : phone;

    setState(() => _isSaving = true);

    bool updatedSomething = false;
    Object? lastError;
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'name': normalizedName,
        'phone_number': normalizedPhone,
      });
      updatedSomething = true;
    } catch (e) {
      lastError = e;
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'name': normalizedName,
            'phone': normalizedPhone,
            'phone_number': normalizedPhone,
          },
        ),
      );
      updatedSomething = true;
    } catch (e) {
      lastError = e;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (updatedSomething) {
        _refreshToken++;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updatedSomething
              ? 'Profile updated.'
              : 'Profile update failed: $lastError',
        ),
      ),
    );
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
                    'Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(0, 145, 110, 1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProfileInfoCard(
                    key: ValueKey(_refreshToken),
                    showEdit: true,
                    onEdit: _isSaving ? null : _editProfile,
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

class _ProfileDraft {
  const _ProfileDraft({required this.name, required this.phone});

  final String name;
  final String phone;
}
