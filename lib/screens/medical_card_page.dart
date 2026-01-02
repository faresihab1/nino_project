import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vaccinations_list_page.dart';

class MedicalCardPage extends StatefulWidget {
  const MedicalCardPage({super.key});

  @override
  State<MedicalCardPage> createState() => _MedicalCardPageState();
}

class _MedicalCardPageState extends State<MedicalCardPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _children = [];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _error = 'You must be logged in to view medical cards.';
          _loading = false;
        });
        return;
      }

      final data = await supabase
          .from('children')
          .select()
          .eq('user_id', user.id)
          .order('child_id');

      setState(() {
        _children = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });

    } catch (e) {
      setState(() {
        _error = 'Failed to load children: $e';
        _loading = false;
      });
    }
  }

  DateTime? _parseBirthDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return DateTime.tryParse(value.toString());
  }

  DateTime _addMonths(DateTime date, int months) {
    final totalMonths = (date.year * 12 + (date.month - 1)) + months;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(targetYear, targetMonth, day);
  }

  String _formatAge(DateTime birthDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dob = DateTime(birthDate.year, birthDate.month, birthDate.day);

    if (dob.isAfter(today)) {
      return '0 days';
    }

    var totalMonths =
        (today.year - dob.year) * 12 + (today.month - dob.month);
    if (today.day < dob.day) {
      totalMonths -= 1;
    }

    if (totalMonths < 0) totalMonths = 0;

    final years = totalMonths ~/ 12;
    final months = totalMonths % 12;
    final anchor = _addMonths(dob, totalMonths);
    final days = today.difference(anchor).inDays;

    final parts = <String>[];
    if (years > 0) {
      parts.add('$years ${years == 1 ? 'year' : 'years'}');
    }
    if (months > 0) {
      parts.add('$months ${months == 1 ? 'month' : 'months'}');
    }
    if (days > 0 || parts.isEmpty) {
      parts.add('$days ${days == 1 ? 'day' : 'days'}');
    }

    return parts.join(', ');
  }

  String _sanitizeFileName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'child';
    final sanitized = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return sanitized.isEmpty ? 'child' : sanitized;
  }

  String _timestampForFile() {
    return DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
  }

  String _valueOrDash(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    return value;
  }

  String _stringField(Map<String, dynamic> item, String key) {
    final value = item[key];
    if (value == null) return '';
    return value.toString();
  }

  String _formatTime12h(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    final isPm = hour >= 12;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minuteText = minute.toString().padLeft(2, '0');
    final suffix = isPm ? 'PM' : 'AM';
    return '$hour12:$minuteText $suffix';
  }

  String _formatTimes(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      final times = value
          .map((e) {
            if (e is Map<String, dynamic>) {
              return e['dose_time']?.toString();
            }
            return e?.toString();
          })
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .map((e) => _formatTime12h(e.toString()))
          .toList();
      return times.join(', ');
    }
    return _formatTime12h(value.toString());
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int _doseTimesCount(Map<String, dynamic> med) {
    final times = med['medicine_dose_times'];
    if (times is List) return times.length;
    return 0;
  }

  int _totalDoses(Map<String, dynamic> med) {
    final days = _parseInt(med['duration_days']);
    final timesCount = _doseTimesCount(med);
    if (days <= 0 || timesCount <= 0) return 0;
    return days * timesCount;
  }

  bool _isMedicineFinished(Map<String, dynamic> med) {
    final flag = med['is_finished'];
    if (flag is bool) return flag;
    final total = _totalDoses(med);
    if (total == 0) return false;
    final given = _parseInt(med['doses_given']);
    return given >= total;
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

  Future<List<Map<String, dynamic>>> _fetchMedicinesForPdf(
    int childId,
  ) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final data = await supabase
          .from('medicines')
          .select(
            'medicine_id,medicine_name,reason,doctor_name,publish_date,'
            'expiry_date,duration_days,created_at,doses_given,is_finished,'
            'medicine_dose_times(dose_time)',
          )
          .eq('user_id', user.id)
          .eq('child_id', childId)
          .order('created_at', ascending: false);

      return (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load medicines for PDF: $e')),
        );
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVaccinesForPdf(int childId) async {
    final supabase = Supabase.instance.client;
    try {
      final data = await supabase
          .from('vaccines')
          .select(
            'id,status,due_date,administered_date,notes,provider,lot_number,'
            'vaccines_reference(name,code,dose_number,is_booster)',
          )
          .eq('child_id', childId)
          .order('administered_date', ascending: false);

      return (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      try {
        final data = await supabase
            .from('vaccinations')
            .select()
            .eq('child_id', childId)
            .order('created_at', ascending: false);

        return (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load vaccines for PDF: $e')),
          );
        }
        return [];
      }
    }
  }

  List<pw.Widget> _buildMedicineBlocks(List<Map<String, dynamic>> medicines) {
    if (medicines.isEmpty) {
      return [pw.Text('- None')];
    }

    final blocks = <pw.Widget>[];
    for (var i = 0; i < medicines.length; i++) {
      final med = medicines[i];
      final name = _stringField(med, 'medicine_name');
      final reason = _stringField(med, 'reason');
      final doctor = _stringField(med, 'doctor_name');
      final times = _formatTimes(med['medicine_dose_times']);
      final days = _stringField(med, 'duration_days');
      final publishDate = _stringField(med, 'publish_date');
      final expiryDate = _stringField(med, 'expiry_date');
      final total = _totalDoses(med);
      final given = _parseInt(med['doses_given']);
      final finished = _isMedicineFinished(med);
      final status = finished ? 'Finished' : 'Active';

      final lines = <pw.Widget>[
        pw.Text('- ${name.isEmpty ? 'Unnamed medicine' : name} ($status)'),
      ];

      if (reason.isNotEmpty) lines.add(pw.Text('  Reason: $reason'));
      if (doctor.isNotEmpty) lines.add(pw.Text('  Doctor: $doctor'));
      if (times.isNotEmpty) lines.add(pw.Text('  Times: $times'));
      if (days.isNotEmpty) lines.add(pw.Text('  Duration: $days days'));
      if (publishDate.isNotEmpty) {
        lines.add(pw.Text('  Publish: $publishDate'));
      }
      if (expiryDate.isNotEmpty) {
        lines.add(pw.Text('  Expiry: $expiryDate'));
      }
      if (total > 0) {
        lines.add(pw.Text('  Doses: $given / $total'));
      } else if (given > 0) {
        lines.add(pw.Text('  Doses: $given'));
      }

      if (i != medicines.length - 1) {
        lines.add(pw.Text('  --------------------'));
      }

      blocks.add(
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: lines,
          ),
        ),
      );
    }

    return blocks;
  }

  List<pw.Widget> _buildVaccineBlocks(List<Map<String, dynamic>> vaccines) {
    if (vaccines.isEmpty) {
      return [pw.Text('- None')];
    }

    final blocks = <pw.Widget>[];
    for (var i = 0; i < vaccines.length; i++) {
      final item = vaccines[i];
      final refMap = _referenceMap(item);
      final name =
          refMap?['name']?.toString() ??
          _firstNonEmpty(item, ['name', 'vaccine_name', 'vaccine', 'title']);
      final code = refMap?['code']?.toString() ??
          _firstNonEmpty(item, ['code', 'vaccine_code']);
      final dose = refMap?['dose_number']?.toString() ??
          _firstNonEmpty(item, ['dose', 'dosage', 'dose_number']);
      final status = _firstNonEmpty(item, ['status']);
      final notes = _firstNonEmpty(item, ['notes', 'note', 'description']);
      final rawDate = _firstNonEmpty(
        item,
        [
          'administered_date',
          'due_date',
          'taken_date',
          'date',
          'given_date',
          'created_at',
        ],
      );
      final date = _formatDate(rawDate);

      final lines = <pw.Widget>[
        pw.Text('- ${name.isEmpty ? 'Unnamed vaccine' : name}'),
      ];

      if (code.isNotEmpty) lines.add(pw.Text('  Code: $code'));
      if (date != null && date.isNotEmpty) {
        lines.add(pw.Text('  Date: $date'));
      }
      if (dose.isNotEmpty) lines.add(pw.Text('  Dose: $dose'));
      if (status.isNotEmpty) lines.add(pw.Text('  Status: $status'));
      if (notes.isNotEmpty) lines.add(pw.Text('  Notes: $notes'));

      if (i != vaccines.length - 1) {
        lines.add(pw.Text('  --------------------'));
      }

      blocks.add(
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: lines,
          ),
        ),
      );
    }

    return blocks;
  }

  Future<Directory?> _getDesktopDirectory() async {
    String? home;
    if (Platform.isWindows) {
      home = Platform.environment['USERPROFILE'];
    } else if (Platform.isMacOS || Platform.isLinux) {
      home = Platform.environment['HOME'];
    }

    if (home == null || home.isEmpty) return null;
    final desktop = Directory(p.join(home, 'Desktop'));
    if (await desktop.exists()) return desktop;
    return null;
  }

  Future<Directory?> _getAndroidDownloadsDirectory() async {
    const candidates = [
      '/storage/emulated/0/Download',
      '/sdcard/Download',
    ];
    for (final path in candidates) {
      final dir = Directory(path);
      if (await dir.exists()) return dir;
    }
    return null;
  }

  Future<(Directory directory, String label, bool isFallback)?>
      _resolveExportTarget() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final desktop = await _getDesktopDirectory();
      if (desktop == null) return null;
      return (desktop, 'Desktop', false);
    }

    if (Platform.isAndroid) {
      final downloads = await _getAndroidDownloadsDirectory();
      if (downloads != null) {
        return (downloads, 'Downloads', false);
      }

      final docs = await getApplicationDocumentsDirectory();
      return (docs, 'App documents', true);
    }

    if (Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      return (docs, 'Documents', true);
    }

    return null;
  }

  pw.Widget _pdfRow(String label, String value) {
    final labelStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$label: ', style: labelStyle),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _pdfSection(String title, List<pw.Widget> items) {
    final headerStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: headerStyle),
        pw.SizedBox(height: 4),
        for (final item in items) item,
      ],
    );
  }

  Future<void> _exportChildPdf(Map<String, dynamic> child) async {
    final target = await _resolveExportTarget();
    if (target == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export folder not found.')),
      );
      return;
    }

    final name = (child['name'] ?? '').toString();
    final childId = _parseChildId(child['child_id']);
    final birthDateValue = _parseBirthDate(child['birth_date']);
    final age = birthDateValue == null ? null : _formatAge(birthDateValue);
    final dateOfBirth = _formatDate(child['birth_date']);
    final gender = _stringOrNull(child['gender']);
    final bloodType = _stringOrNull(child['blood_type']);
    final allergies = _stringOrNull(child['allergies']);
    final chronicConditions = _stringOrNull(child['chronic_conditions']);
    final medicines = childId == null
        ? <Map<String, dynamic>>[]
        : await _fetchMedicinesForPdf(childId);
    final vaccines = childId == null
        ? <Map<String, dynamic>>[]
        : await _fetchVaccinesForPdf(childId);
    final medicineBlocks = _buildMedicineBlocks(medicines);
    final vaccineBlocks = _buildVaccineBlocks(vaccines);

    final fileName =
        'medical_card_${_sanitizeFileName(name)}_${_timestampForFile()}.pdf';
    final file = File(p.join(target.$1.path, fileName));

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Child Medical Card',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          _pdfRow('Name', _valueOrDash(name)),
          _pdfRow('Date of Birth', _valueOrDash(dateOfBirth)),
          _pdfRow('Age', _valueOrDash(age)),
          _pdfRow('Gender', _valueOrDash(gender)),
          _pdfRow('Blood Type', _valueOrDash(bloodType)),
          _pdfRow('Allergies', _valueOrDash(allergies)),
          _pdfRow(
            'Chronic Conditions',
            _valueOrDash(chronicConditions),
          ),
          pw.SizedBox(height: 12),
          _pdfSection('Medicines', medicineBlocks),
          pw.SizedBox(height: 12),
          _pdfSection('Vaccinations', vaccineBlocks),
        ],
      ),
    );

    final bytes = await doc.save();

    try {
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      final message = target.$3
          ? 'Saved PDF to ${target.$2}: ${file.path}'
          : 'Saved PDF to ${file.path}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (Platform.isAndroid && target.$2 == 'Downloads') {
        try {
          final fallbackDir = await getApplicationDocumentsDirectory();
          final fallbackFile = File(
            p.join(fallbackDir.path, fileName),
          );
          await fallbackFile.writeAsBytes(bytes);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Downloads not writable. Saved to app documents: ${fallbackFile.path}',
              ),
            ),
          );
          return;
        } catch (_) {
          // fall through to error message below
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: $e')),
      );
    }
  }

  String? _formatDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is DateTime) {
      return value.toIso8601String().split('T').first;
    }
    return value.toString();
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  int? _parseChildId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Card'),
        backgroundColor: Colors.redAccent,
      ),
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

    if (_children.isEmpty) {
      return const Center(child: Text('No children found for this account.'));
    }

    return ListView.builder(
      itemCount: _children.length,
      itemBuilder: (context, index) {
        final child = _children[index];
        final name = child['name'] as String?;
        final childId = _parseChildId(child['child_id']);
        final birthDateValue = _parseBirthDate(child['birth_date']);
        final allergies = _stringOrNull(child['allergies']);
        final chronicConditions = _stringOrNull(child['chronic_conditions']);

        
        final bd = birthDateValue;
        final String? age = bd == null ? null : _formatAge(bd);

        final bloodType = child['blood_type'] as String?;
        final gender = child['gender'] as String?;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index == 0) ...[
              const Text(
                'Child Medical Card',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MedicalField(label: 'Name', value: name),
                    _MedicalField(
                      label: 'Date of Birth',
                      value: _formatDate(child['birth_date']),
                    ),
                    _MedicalField(label: 'Age', value: age),
                    _MedicalField(label: 'Gender', value: gender),
                    _MedicalField(label: 'Blood Type', value: bloodType),
                    _MedicalField(label: 'Allergies', value: allergies),
                    _MedicalField(
                      label: 'Chronic Conditions',
                      value: chronicConditions,
                    ),
                    const _MedicalField(label: 'Medications'),
                    _MedicalActionField(
                      label: 'Vaccinations',
                      buttonText: 'View',
                      onPressed: childId == null
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VaccinationsListPage(
                                    childId: childId,
                                    childName: name,
                                  ),
                                ),
                              );
                            },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _exportChildPdf(
                          Map<String, dynamic>.from(child),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Save PDF'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (index == _children.length - 1) ...[
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: const Text(
                  'Add any extra medical notes here...',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _MedicalField extends StatelessWidget {
  final String label;
  final String? value;

  const _MedicalField({
    required this.label,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textStyleLabel = const TextStyle(
      fontWeight: FontWeight.w600,
    );

    if (value == null || value!.isEmpty) {
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Text('$label: ', style: textStyleLabel),
            const Expanded(
              child: Divider(
                indent: 4,
                thickness: 0.6,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: textStyleLabel),
          Expanded(
            child: Text(
              value!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalActionField extends StatelessWidget {
  final String label;
  final String buttonText;
  final VoidCallback? onPressed;

  const _MedicalActionField({
    required this.label,
    required this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const textStyleLabel = TextStyle(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Text('$label: ', style: textStyleLabel),
          const Spacer(),
          TextButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
