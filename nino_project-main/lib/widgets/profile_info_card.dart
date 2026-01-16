import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileInfoCard extends StatefulWidget {
  const ProfileInfoCard({
    super.key,
    this.title = 'Account Info',
    this.showEdit = false,
    this.onEdit,
  });

  final String title;
  final bool showEdit;
  final VoidCallback? onEdit;

  @override
  State<ProfileInfoCard> createState() => _ProfileInfoCardState();
}

class _ProfileInfoCardState extends State<ProfileInfoCard> {
  late final Future<_ProfileInfo?> _profileFuture;
  late final User? _user;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _user = user;
    _profileFuture =
        user == null ? Future.value(null) : _fetchProfileInfo(user);
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

  Future<_ProfileInfo?> _fetchProfileInfo(User user) async {
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

    return _ProfileInfo(name: name, phone: phone);
  }

  Widget _infoRow(String label, String? value) {
    final display =
        (value == null || value.trim().isEmpty) ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color.fromRGBO(0, 145, 110, 1),
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: user == null
          ? const Text(
              'No active session.',
              style: TextStyle(color: Colors.black87),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.showEdit)
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              const Color.fromRGBO(0, 145, 110, 1),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow('Email', user.email),
                FutureBuilder<_ProfileInfo?>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    final isLoading =
                        snapshot.connectionState == ConnectionState.waiting;
                    final info = snapshot.data;
                    final nameValue = isLoading ? 'Loading...' : info?.name;
                    final phoneValue = isLoading ? 'Loading...' : info?.phone;
                    return Column(
                      children: [
                        _infoRow('Name', nameValue),
                        _infoRow('Phone', phoneValue),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _ProfileInfo {
  const _ProfileInfo({this.name, this.phone});

  final String? name;
  final String? phone;
}
