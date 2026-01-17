import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LabAnalyzerPage extends StatefulWidget {
  final int? childId;

  const LabAnalyzerPage({super.key, required this.childId});

  @override
  State<LabAnalyzerPage> createState() => _LabAnalyzerPageState();
}

class _LabAnalyzerPageState extends State<LabAnalyzerPage> {
  // ✅ Put your ngrok base url here (NO /docs)
  // Example: https://defervescent-jaylene-unspoiled.ngrok-free.dev
  final String _apiBaseUrl = "https://defervescent-jaylene-unspoiled.ngrok-free.dev";

  final _picker = ImagePicker();
  File? _imageFile;

  bool _loadingChildAge = true;
  bool _analyzing = false;

  DateTime? _birthDate;
  int? _ageMonths;
  String? _ageForAi; // "6 months" OR "2 years"

  Map<String, dynamic>? _result;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadBirthDateAndComputeAge();
  }

  Future<void> _loadBirthDateAndComputeAge() async {
    setState(() => _loadingChildAge = true);

    try {
      if (widget.childId == null) {
        setState(() {
          _birthDate = null;
          _ageMonths = null;
          _ageForAi = null;
          _loadingChildAge = false;
        });
        return;
      }

      final row = await supabase
          .from('children')
          .select('birth_date')
          .eq('child_id', widget.childId!)
          .maybeSingle();

      if (row == null) {
        setState(() {
          _birthDate = null;
          _ageMonths = null;
          _ageForAi = null;
          _loadingChildAge = false;
        });
        return;
      }

      final raw = row['birth_date'];

      DateTime? bd;
      if (raw is String) {
        bd = DateTime.tryParse(raw);
      } else if (raw is DateTime) {
        bd = raw;
      }

      if (bd == null) {
        setState(() {
          _birthDate = null;
          _ageMonths = null;
          _ageForAi = null;
          _loadingChildAge = false;
        });
        return;
      }

      final months = _monthsBetween(bd, DateTime.now());
      final ageLabel = _formatAgeForAi(months);

      setState(() {
        _birthDate = bd;
        _ageMonths = months;
        _ageForAi = ageLabel;
        _loadingChildAge = false;
      });
    } catch (_) {
      setState(() => _loadingChildAge = false);
    }
  }

  int _monthsBetween(DateTime from, DateTime to) {
    int months = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }

  // ✅ Your rule:
  // < 12 months => "X months"
  // >= 12 months => "Y years"
  String _formatAgeForAi(int months) {
    if (months < 12) return "$months months";
    final years = months ~/ 12;
    return "$years years";
  }

  Future<void> _pickFromGallery() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    setState(() {
      _imageFile = File(xfile.path);
      _result = null;
    });
  }

  Future<void> _pickFromCamera() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;

    setState(() {
      _imageFile = File(xfile.path);
      _result = null;
    });
  }

  Future<void> _analyze() async {
    if (_imageFile == null) {
      _showDialog("Missing image", "Please choose a photo first.");
      return;
    }
    if (_ageForAi == null || _ageForAi!.trim().isEmpty) {
      _showDialog("Missing age", "Could not calculate child age. Check birth_date.");
      return;
    }

    setState(() => _analyzing = true);

    try {
      final url = Uri.parse("$_apiBaseUrl/analyze");

      final request = http.MultipartRequest("POST", url);
      request.fields["age"] = _ageForAi!;
      request.files.add(await http.MultipartFile.fromPath("image", _imageFile!.path));

      final streamed = await request.send();
      final bodyStr = await streamed.stream.bytesToString();

      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        _showDialog("API Error", "Status: ${streamed.statusCode}\n\n$bodyStr");
        return;
      }

      final decoded = jsonDecode(bodyStr);
      setState(() {
        _result = decoded is Map<String, dynamic> ? decoded : {"data": decoded};
      });
    } catch (e) {
      _showDialog("Error", e.toString());
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _showDialog(String title, String message) async {
    if (!mounted) return;
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
  }

  // --------------------- NICE UI HELPERS ---------------------

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'low':
        return const Color(0xFFE57373);
      case 'high':
        return const Color(0xFFFFB74D);
      case 'normal':
        return const Color(0xFF81C784);
      default:
        return const Color(0xFF90A4AE);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'low':
        return Icons.arrow_downward_rounded;
      case 'high':
        return Icons.arrow_upward_rounded;
      case 'normal':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF0B3D2E),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0B3D2E),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _prettyResultView(Map<String, dynamic> json) {
    // Expected response:
    // age_input, age_years, lab_results: { test: {value,status,confidence} }, alerts: []
    final String ageInput = (json['age_input'] ?? '-').toString();
    final String ageYears = (json['age_years'] ?? '-').toString();

    final dynamic labResultsRaw = json['lab_results'];
    final Map<String, dynamic> labResults =
        (labResultsRaw is Map<String, dynamic>) ? labResultsRaw : <String, dynamic>{};

    final dynamic alertsRaw = json['alerts'];
    final List<dynamic> alerts = (alertsRaw is List) ? alertsRaw : <dynamic>[];

    final List<Widget> labCards = [];
    labResults.forEach((testName, data) {
      final Map<String, dynamic> d = (data is Map<String, dynamic>) ? data : <String, dynamic>{};

      final value = d['value']?.toString() ?? '-';
      final status = (d['status'] ?? 'Unknown').toString();
      final confidence = (d['confidence'] ?? 'Unknown').toString();

      final c = _statusColor(status);

      labCards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withOpacity(0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_statusIcon(status), color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleCase(testName.toString()),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0B3D2E),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip("Value: $value", const Color(0xFF00916E)),
                        _chip("Status: $status", c),
                        _chip("Confidence: $confidence", const Color(0xFF5C6BC0)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });

    final List<String> alertStrings = alerts
        .map((a) => a.toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: "Age Used",
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Input",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0B3D2E),
                      ),
                    ),
                  ),
                  Text(
                    ageInput,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B3D2E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Years",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0B3D2E),
                      ),
                    ),
                  ),
                  Text(
                    ageYears,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B3D2E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _sectionCard(
          title: "Lab Results",
          child: labCards.isEmpty
              ? const Text(
                  "No lab results found in response.",
                  style: TextStyle(
                    color: Color(0xFF0B3D2E),
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Column(children: labCards),
        ),
        _sectionCard(
          title: "Alerts",
          child: alertStrings.isEmpty
              ? const Text(
                  "No alerts ✅",
                  style: TextStyle(
                    color: Color(0xFF0B3D2E),
                    fontWeight: FontWeight.w800,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: alertStrings.map((a) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("•  ",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0B3D2E))),
                          Expanded(
                            child: Text(
                              a,
                              style: const TextStyle(
                                color: Color(0xFF0B3D2E),
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // --------------------- UI ---------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Lab Analyzer"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0B3D2E),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const Background(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                // Child age card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.6)),
                  ),
                  child: _loadingChildAge
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            SizedBox(width: 10),
                            Text("Calculating child age..."),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(Icons.cake_outlined, color: Color(0xFF00916E)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _ageForAi == null
                                    ? "Could not calculate age (check birth_date)."
                                    : "Child age for AI: $_ageForAi",
                                style: const TextStyle(
                                  color: Color(0xFF0B3D2E),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 12),

                // Image + actions
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Lab Image",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0B3D2E),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_imageFile == null)
                        Container(
                          height: 160,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00916E).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            "No image selected",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0B3D2E),
                            ),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(_imageFile!, height: 220, fit: BoxFit.cover),
                        ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _analyzing ? null : _pickFromGallery,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text("Gallery"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _analyzing ? null : _pickFromCamera,
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text("Camera"),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _analyzing ? null : _analyze,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00916E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _analyzing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Analyze",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (_result != null) _prettyResultView(_result!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}