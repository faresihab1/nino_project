import 'package:flutter/material.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SleepTrackerPage extends StatefulWidget {
  final int? childId;

  const SleepTrackerPage({super.key, this.childId});

  @override
  State<SleepTrackerPage> createState() => _SleepTrackerPageState();
}

class _SleepTrackerPageState extends State<SleepTrackerPage> {
  final _formKey = GlobalKey<FormState>();

  final _wakeupsController = TextEditingController();
  final _ageMonthsController = TextEditingController();
  final _sleepStartController = TextEditingController();
  final _sleepEndController = TextEditingController();

  TimeOfDay? sleepStart;
  TimeOfDay? sleepEnd;

  final supabase = Supabase.instance.client;
  late Future<List<dynamic>> _sleepRecordsFuture;

  // ✅ loading while saving
  bool _saving = false;

  // ✅ collapsible history
  bool _historyExpanded = false;

  // ✅ last evaluation (structured)
  String? _lastQuality;
  String? _lastRisk;
  String? _lastNotes;
  double? _lastDuration;
  double? _lastNormalMin;
  double? _lastNormalMax;
  int? _lastWakeups;
  int? _lastAgeMonths;

  @override
  void initState() {
    super.initState();
    _sleepRecordsFuture = _fetch();
    _loadChildInfo();
  }

  Future<void> _loadChildInfo() async {
    final user = supabase.auth.currentUser;

    if (user == null || widget.childId == null) {
      setState(() => _ageMonthsController.text = '');
      return;
    }

    try {
      final child = await supabase
          .from('children')
          .select('birth_date')
          .eq('child_id', widget.childId!)
          .maybeSingle();

      if (child == null) {
        setState(() => _ageMonthsController.text = '');
        return;
      }

      final rawBirthDate = child['birth_date'];

      DateTime? bd;
      if (rawBirthDate is String) {
        bd = DateTime.tryParse(rawBirthDate);
      } else if (rawBirthDate is DateTime) {
        bd = rawBirthDate;
      }

      int? ageMonths;
      if (bd != null) {
        final now = DateTime.now();
        ageMonths = (now.year - bd.year) * 12 + (now.month - bd.month);
        if (now.day < bd.day) ageMonths -= 1;
        if (ageMonths < 0) ageMonths = 0;
      }

      setState(() {
        _ageMonthsController.text = ageMonths?.toString() ?? '';
      });
    } catch (_) {
      // keep editable
    }
  }

  @override
  void dispose() {
    _wakeupsController.dispose();
    _ageMonthsController.dispose();
    _sleepStartController.dispose();
    _sleepEndController.dispose();
    super.dispose();
  }

  String _timeOfDayToPgTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white.withOpacity(0.92),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF00916E), width: 2),
      ),
    );
  }

  Widget _timeField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: _saving ? null : onTap,
      decoration: _inputDecoration(label, icon: icon),
    );
  }

  Future<TimeOfDay?> _pickTime() async {
    return showTimePicker(context: context, initialTime: TimeOfDay.now());
  }

  Color _qualityColor(String? quality) {
    switch (quality) {
      case 'less_than_recommended':
        return const Color(0xFFF2C57C);
      case 'more_than_recommended':
        return const Color(0xFFF0A6A6);
      case 'normal':
        return const Color(0xFF9FD6B8);
      default:
        return Colors.grey;
    }
  }

  String _qualityLabel(String? quality) {
    switch (quality) {
      case 'less_than_recommended':
        return 'Below recommended';
      case 'more_than_recommended':
        return 'Above recommended';
      case 'normal':
        return 'Normal';
      default:
        return '-';
    }
  }

  IconData _qualityIcon(String? quality) {
    switch (quality) {
      case 'less_than_recommended':
        return Icons.arrow_downward_rounded;
      case 'more_than_recommended':
        return Icons.arrow_upward_rounded;
      case 'normal':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  Widget _miniInfo(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF00916E).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B3D2E),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0B3D2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _evaluationCard() {
    if (_lastQuality == null) return const SizedBox.shrink();

    final color = _qualityColor(_lastQuality);

    final List<String> bullets = [];
    if (_lastDuration != null && _lastNormalMin != null && _lastNormalMax != null) {
      if (_lastDuration! < _lastNormalMin!) {
        bullets.add(
          "Sleep duration is low (${_lastDuration!.toStringAsFixed(1)}h). Try to increase it.",
        );
      } else if (_lastDuration! > _lastNormalMax!) {
        bullets.add(
          "Sleep duration is higher than the typical range (${_lastDuration!.toStringAsFixed(1)}h). Often okay if the child is well-rested.",
        );
      } else {
        bullets.add("Sleep duration is within the recommended range.");
      }
    }
    if (_lastWakeups != null) {
      bullets.add("Night wakeups: $_lastWakeups");
    }
    if (_lastRisk != null && _lastRisk!.trim().isNotEmpty) {
      bullets.add("Risk level: ${_lastRisk!}");
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_qualityIcon(_lastQuality), color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  _qualityLabel(_lastQuality),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Last evaluation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0B3D2E),
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniInfo("Age", "${_lastAgeMonths ?? '-'} months"),
              _miniInfo("Duration", "${_lastDuration?.toStringAsFixed(1) ?? '-'} h"),
              _miniInfo("Recommended", (_lastNormalMin != null && _lastNormalMax != null)
                  ? "${_lastNormalMin!.toStringAsFixed(1)}–${_lastNormalMax!.toStringAsFixed(1)} h"
                  : "-"),
              _miniInfo("Wakeups", "${_lastWakeups ?? '-'}"),
            ],
          ),

          const SizedBox(height: 12),

          if (bullets.isNotEmpty) ...[
            const Text(
              "Summary",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B3D2E),
              ),
            ),
            const SizedBox(height: 6),
            ...bullets.map(
              (x) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        x,
                        style: const TextStyle(
                          color: Color(0xFF0B3D2E),
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if ((_lastNotes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              "Notes",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B3D2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _lastNotes!,
              style: const TextStyle(
                color: Color(0xFF0B3D2E),
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (sleepStart == null || sleepEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select start and end times")),
      );
      return;
    }

    if (widget.childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a child first")),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final ageMonths = int.parse(_ageMonthsController.text.trim());
      final wakeups = int.parse(_wakeupsController.text.trim());

      final start = DateTime(2025, 1, 1, sleepStart!.hour, sleepStart!.minute);
      final end = DateTime(2025, 1, 1, sleepEnd!.hour, sleepEnd!.minute);

      double duration = end.difference(start).inMinutes / 60.0;
      if (duration < 0) duration += 24.0;

      final refRows = await supabase
          .from('sleep_reference')
          .select()
          .lte('min_age_months', ageMonths)
          .gte('max_age_months', ageMonths)
          .limit(1);

      if (refRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No reference data found for this age.")),
        );
        return;
      }

      final ref = refRows.first;
      final double normalMin = (ref['normal_min_hours'] as num?)?.toDouble() ?? 0.0;
      final double normalMax = (ref['normal_max_hours'] as num?)?.toDouble() ?? 0.0;
      final String notes = (ref['notes'] ?? '') as String;

      String sleepQuality;
      String riskLevel;

      if (duration < normalMin) {
        sleepQuality = 'less_than_recommended';
        riskLevel = 'medium';
      } else if (duration > normalMax) {
        sleepQuality = 'more_than_recommended';
        riskLevel = 'low';
      } else {
        sleepQuality = 'normal';
        riskLevel = 'low';
      }

      await supabase.from('sleep_records').insert({
        'user_id': user.id,
        'child_id': widget.childId,
        'sleep_date': DateTime.now().toIso8601String().split('T').first,
        'sleep_start': _timeOfDayToPgTime(sleepStart!),
        'sleep_end': _timeOfDayToPgTime(sleepEnd!),
        'duration_hours': duration,
        'wakeups_count': wakeups,
        'age_months': ageMonths,
        'sleep_quality': sleepQuality,
      });

      if (!mounted) return;

      setState(() {
        _lastQuality = sleepQuality;
        _lastRisk = riskLevel;
        _lastNotes = notes;
        _lastDuration = duration;
        _lastNormalMin = normalMin;
        _lastNormalMax = normalMax;
        _lastWakeups = wakeups;
        _lastAgeMonths = ageMonths;

        _sleepRecordsFuture = _fetch();
        _historyExpanded = true; // ✅ expand after saving

        _wakeupsController.clear();
        _sleepStartController.clear();
        _sleepEndController.clear();
        sleepStart = null;
        sleepEnd = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving data: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<dynamic>> _fetch() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    var query = supabase.from('sleep_records').select().eq('user_id', user.id);
    if (widget.childId != null) {
      query = query.eq('child_id', widget.childId!);
    }

    final data = await query.order('sleep_date', ascending: false);
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Sleep Tracker'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF0B3D2E),
      ),
      body: Stack(
        children: [
          const Background(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        // Hint
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.6)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFF00916E)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.childId == null
                                      ? 'Select a child first to save sleep records.'
                                      : 'Log sleep times, wakeups, and get a quick evaluation.',
                                  style: const TextStyle(
                                    color: Color(0xFF0B3D2E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Form card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _ageMonthsController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    'Age (months)',
                                    icon: Icons.cake_outlined,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    final n = int.tryParse(v);
                                    if (n == null || n < 0) return 'Enter a valid age in months';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _timeField(
                                        label: 'Sleep start',
                                        controller: _sleepStartController,
                                        icon: Icons.bedtime_outlined,
                                        onTap: () async {
                                          final picked = await _pickTime();
                                          if (picked != null) {
                                            setState(() {
                                              sleepStart = picked;
                                              _sleepStartController.text = picked.format(context);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _timeField(
                                        label: 'Sleep end',
                                        controller: _sleepEndController,
                                        icon: Icons.wb_sunny_outlined,
                                        onTap: () async {
                                          final picked = await _pickTime();
                                          if (picked != null) {
                                            setState(() {
                                              sleepEnd = picked;
                                              _sleepEndController.text = picked.format(context);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _wakeupsController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    'Night wakeups',
                                    icon: Icons.nights_stay_outlined,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    final n = int.tryParse(v);
                                    if (n == null || n < 0) return 'Enter a valid number';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _save,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00916E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _saving
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.6,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Save & Evaluate',
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
                        ),

                        const SizedBox(height: 12),

                        // ✅ Evaluation card
                        _evaluationCard(),

                        const SizedBox(height: 12),

                        // ✅ History header with arrow
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() => _historyExpanded = !_historyExpanded);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'History',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0B3D2E),
                                    ),
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: _historyExpanded ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 180),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color(0xFF0B3D2E),
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        
                      ],
                    ),
                  ),
                ),

                // ✅ History list only when expanded
                if (_historyExpanded)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: FutureBuilder<List<dynamic>>(
                      future: _sleepRecordsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: 20),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return SliverToBoxAdapter(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Center(child: Text('No sleep data yet.')),
                            ),
                          );
                        }

                        final entries = snapshot.data!;
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final item = entries[i];

                              final String dateStr = item['sleep_date']?.toString() ?? '';
                              final double dur =
                                  (item['duration_hours'] as num?)?.toDouble() ?? 0.0;
                              final int wakes =
                                  (item['wakeups_count'] as num?)?.toInt() ?? 0;
                              final String quality = (item['sleep_quality'] ?? '').toString();

                              final color = _qualityColor(quality);
                              final label = _qualityLabel(quality);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.86),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 14,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(Icons.bedtime_outlined, color: color),
                                  ),
                                  title: Text(
                                    'Duration: ${dur.toStringAsFixed(1)} hrs',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0B3D2E),
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Wakeups: $wakes\nDate: $dateStr\nQuality: $label',
                                      style: const TextStyle(
                                        color: Color(0xFF0B3D2E),
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: entries.length,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}