import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChildInfoPage extends StatefulWidget {
  const ChildInfoPage({super.key});

  @override
  State<ChildInfoPage> createState() => _ChildInfoPageState();
}

class _ChildInfoPageState extends State<ChildInfoPage> {
  final supabase = Supabase.instance.client;
  Future<Map<String, dynamic>>? _infoFuture;
  int? _childId;
  String? _childName;
  bool _didInitDependencies = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitDependencies) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final dynamic id = args['childId'];
        if (id is int) {
          _childId = id;
        } else if (id is String) {
          _childId = int.tryParse(id);
        }
        _childName = args['name'] as String?;
      }

      _infoFuture = _fetchLatestActivities();
      _didInitDependencies = true;
    }
  }

  Future<Map<String, dynamic>> _fetchLatestActivities() async {
    final childId = _childId;

    final user = supabase.auth.currentUser;
    if (user == null) return {};

    final result = <String, dynamic>{};

    // Helper to try fetching a table and return first row or null.
    Future<Map<String, dynamic>?> tryFetchFirst(String table) async {
      try {
        // Start with a selectable builder
        var builder = supabase.from(table).select();

        // Prefer filtering by child_id if available
        if (childId != null) {
          try {
            builder = builder.eq('child_id', childId);
          } catch (_) {
            // ignore if the column doesn't exist on this table
          }
        }

        // Try filtering by user id if that column exists
        try {
          builder = builder.eq('user_id', user.id);
        } catch (_) {
          // ignore if the column doesn't exist
        }

        // Apply ordering and limit last
        final dynamic data = await builder
            .order('created_at', ascending: false)
            .limit(1);

        if (data == null) return null;
        if (data is List && data.isNotEmpty) {
          final first = data.first;
          if (first is Map) return Map<String, dynamic>.from(first);
          return null;
        }
        if (data is Map) return Map<String, dynamic>.from(data);
      } catch (_) {
        // ignore errors for optional tables
      }
      return null;
    }

    // Growth
    final growth = await tryFetchFirst('growth_records');
    result['growth'] = growth;

    // Sleep
    final sleep = await tryFetchFirst('sleep_records');
    result['sleep'] = sleep;

    // Lab results (best-effort)
    final lab = await tryFetchFirst('lab_reports');
    result['lab'] = lab;

    // Medications (best-effort) - try common table names
    Map<String, dynamic>? meds;
    meds = await tryFetchFirst('medicines');
    meds ??= await tryFetchFirst('medications');
    meds ??= await tryFetchFirst('meds');
    result['medication'] = meds;

    return result;
  }

  Widget _buildCard(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _entryToWidget(Map<String, dynamic>? entry) {
    if (entry == null) return const Text('No data');
    final buffer = <String>[];
    entry.forEach((k, v) {
      if (k == 'medicine_name' ||
          k == 'doctor_name' ||
          k == 'duration_days' ||
          k == 'publish_date' ||
          k == 'expiry_date' ||
          k == 'created_at' ||
          k == 'sleep_date' ||
          k == 'sleep_start' ||
          k == 'sleep_end' ||
          k.endsWith('_date') ||
          k.endsWith('_at')) {
        buffer.add('$k: ${v ?? ''}');
      } else if (k == 'weight_kg' || k == 'height_cm' || k == 'bmi') {
        buffer.add('$k: ${v ?? ''}');
      } else if (k == 'duration_hours' ||
          k == 'sleep_quality' ||
          k == 'wakeups_count') {
        buffer.add('$k: ${v ?? ''}');
      } else if (k == 'notes' ||
          k == 'comment' ||
          k == 'ai_comment' ||
          k == 'commentary') {
        buffer.add('$k: ${v ?? ''}');
      }
    });
    if (buffer.isEmpty) {
      // Fallback: show some keys
      final preview = entry.keys
          .take(6)
          .map((k) => '$k: ${entry[k]}')
          .join('\n');
      return Text(preview);
    }
    return Text(buffer.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Child Info';
    if (_childName != null && _childName!.isNotEmpty) {
      title = '${_childName!} — Recent Activity';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _infoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data ?? {};

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _infoFuture = _fetchLatestActivities();
              });
              await _infoFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCard(
                  'Last Growth Evaluation',
                  _entryToWidget(data['growth'] as Map<String, dynamic>?),
                ),
                _buildCard(
                  'Last Sleep Record',
                  _entryToWidget(data['sleep'] as Map<String, dynamic>?),
                ),
                _buildCard(
                  'Last Lab Result',
                  _entryToWidget(data['lab'] as Map<String, dynamic>?),
                ),
                _buildCard(
                  'Last Medication Activity',
                  _entryToWidget(data['medication'] as Map<String, dynamic>?),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Notes: The app stores many activity records at the user level. If some sections show no data, that feature may not be used yet or the project stores those records under a different table name.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
