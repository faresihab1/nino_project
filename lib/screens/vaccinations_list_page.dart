import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VaccinationsListPage extends StatefulWidget {
  const VaccinationsListPage({
    super.key,
    required this.childId,
    this.childName,
  });

  final int childId;
  final String? childName;

  @override
  State<VaccinationsListPage> createState() => _VaccinationsListPageState();
}

class _VaccinationsListPageState extends State<VaccinationsListPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _vaccines = [];

  @override
  void initState() {
    super.initState();
    _loadVaccines();
  }

  Future<void> _loadVaccines() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _error = 'You must be logged in to view vaccinations.';
        _loading = false;
      });
      return;
    }

    try {
      final data = await supabase
          .from('vaccines')
          .select(
            'id,status,administered_date,notes,provider,lot_number,'
            'vaccines_reference(name,code,dose_number,is_booster)',
          )
          .eq('child_id', widget.childId)
          .eq('status', 'given')
          .order('administered_date', ascending: false);
      _setVaccines(data);
    } catch (_) {
      try {
        final data = await supabase
            .from('vaccinations')
            .select()
            .eq('user_id', user.id)
            .eq('child_id', widget.childId)
            .order('created_at', ascending: false);
        _setVaccines(data);
      } catch (e) {
        setState(() {
          _error = 'Failed to load vaccinations: $e';
          _loading = false;
        });
      }
    }
  }

  void _setVaccines(dynamic data) {
    final list = (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
    setState(() {
      _vaccines = list;
      _loading = false;
    });
  }

  String _firstNonEmpty(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Map<String, dynamic>? _referenceMap(Map<String, dynamic> item) {
    final ref = item['vaccines_reference'];
    if (ref is Map<String, dynamic>) return ref;
    if (ref is List && ref.isNotEmpty && ref.first is Map) {
      return Map<String, dynamic>.from(ref.first as Map);
    }
    return null;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return value.toIso8601String().split('T').first;
    }
    final text = value.toString();
    if (text.contains('T')) {
      return text.split('T').first;
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.childName == null || widget.childName!.isEmpty
        ? 'Vaccinations'
        : 'Vaccinations - ${widget.childName}';

    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.redAccent),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_vaccines.isEmpty) {
      return const Center(child: Text('No vaccinations found.'));
    }

    return ListView.separated(
      itemCount: _vaccines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _vaccines[index];
        final refMap = _referenceMap(item);
        final name =
            refMap?['name']?.toString() ??
            _firstNonEmpty(item, ['name', 'vaccine_name', 'vaccine', 'title']);
        final code = refMap?['code']?.toString() ?? '';
        final dose = refMap?['dose_number']?.toString() ??
            _firstNonEmpty(item, ['dose', 'dosage']);
        final rawDate = _firstNonEmpty(
          item,
          [
            'taken_date',
            'date',
            'given_date',
            'administered_date',
            'administered_at',
            'created_at',
          ],
        );
        final date = _formatDate(rawDate);
        final status = _firstNonEmpty(item, ['status']);
        final notes = _firstNonEmpty(item, ['notes', 'note', 'description']);

        final details = <String>[];
        if (code.isNotEmpty) details.add('Code: $code');
        if (date.isNotEmpty) details.add('Date: $date');
        if (dose.isNotEmpty) details.add('Dose: $dose');
        if (status.isNotEmpty) details.add('Status: $status');
        if (notes.isNotEmpty) details.add('Notes: $notes');

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Unnamed vaccine' : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (details.isNotEmpty) const SizedBox(height: 8),
                for (final line in details) Text(line),
              ],
            ),
          ),
        );
      },
    );
  }
}
