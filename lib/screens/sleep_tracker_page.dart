import 'package:flutter/material.dart';
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

  TimeOfDay? sleepStart;
  TimeOfDay? sleepEnd;

  final supabase = Supabase.instance.client;
  late Future<List<dynamic>> _sleepRecordsFuture;

  
  String? _lastQuality;
  String? _lastRisk;
  String? _lastComment;

  @override
  void initState() {
    super.initState();
    _sleepRecordsFuture = _fetch();
    _loadChildInfo();
  }

  Future<void> _loadChildInfo() async {
    final user = supabase.auth.currentUser;
    
    if (user == null || widget.childId == null) {
      setState(() {
        _ageMonthsController.text = '';
      });
      return;
    }

    try {
      final child = await supabase
          .from('children')
          .select('birth_date')
          .eq('child_id', widget.childId!)
          .maybeSingle();

      if (child == null) {
        setState(() {
          _ageMonthsController.text = '';
        });
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
        if (now.day < bd.day) {
          ageMonths -= 1;
        }
        if (ageMonths < 0) {
          ageMonths = 0;
        }
      }

      setState(() {
        if (ageMonths != null) {
          _ageMonthsController.text = ageMonths.toString();
        }
      });
    } catch (e) {
      // Optionally handle error
    }
  }

  @override
  void dispose() {
    _wakeupsController.dispose();
    _ageMonthsController.dispose();
    super.dispose();
  }

  String _timeOfDayToPgTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
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

    final ageMonths = int.parse(_ageMonthsController.text.trim());
    final wakeups = int.parse(_wakeupsController.text.trim());

    
    final start = DateTime(2025, 1, 1, sleepStart!.hour, sleepStart!.minute);
    final end = DateTime(2025, 1, 1, sleepEnd!.hour, sleepEnd!.minute);

    double duration = end.difference(start).inMinutes / 60.0;
    if (duration < 0) {
      
      duration += 24.0;
    }

    
    final refRows = await supabase
        .from('sleep_reference')
        .select()
        .lte('min_age_months', ageMonths)
        .gte('max_age_months', ageMonths)
        .limit(1);

    if (refRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No reference data found for this age."),
        ),
      );
      return;
    }

    final ref = refRows.first;
    final double normalMin =
        (ref['normal_min_hours'] as num?)?.toDouble() ?? 0.0;
    final double normalMax =
        (ref['normal_max_hours'] as num?)?.toDouble() ?? 0.0;
    final String notes = (ref['notes'] ?? '') as String;

    
    String sleepQuality;
    String riskLevel;
    String aiComment;

    if (duration < normalMin) {
      sleepQuality = 'less_than_recommended';
      riskLevel = 'medium';
      aiComment =
          'Your child slept ${duration.toStringAsFixed(1)} hours, which is less than the recommended '
          '${normalMin.toStringAsFixed(1)}–${normalMax.toStringAsFixed(1)} hours for this age. '
          'Try to improve sleep duration if possible. $notes';
    } else if (duration > normalMax) {
      sleepQuality = 'more_than_recommended';
      riskLevel = 'low';
      aiComment =
          'Your child slept ${duration.toStringAsFixed(1)} hours, which is more than the recommended '
          '${normalMin.toStringAsFixed(1)}–${normalMax.toStringAsFixed(1)} hours for this age. '
          'In many cases that is okay as long as they seem well-rested. $notes';
    } else {
      sleepQuality = 'normal';
      riskLevel = 'low';
      aiComment =
          'Great! Your child slept ${duration.toStringAsFixed(1)} hours, which is within the recommended '
          '${normalMin.toStringAsFixed(1)}–${normalMax.toStringAsFixed(1)} hours for this age. $notes';
    }

    
    try {
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved & evaluated!")),
      );

      setState(() {
        _lastQuality = sleepQuality;
        _lastRisk = riskLevel;
        _lastComment = aiComment; 

        _sleepRecordsFuture = _fetch();
        _wakeupsController.clear();
        
        sleepStart = null;
        sleepEnd = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving data: $e")),
      );
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

  Future<TimeOfDay?> _pickTime() async {
    return showTimePicker(context: context, initialTime: TimeOfDay.now());
  }

  Color _qualityColor(String? quality) {
    switch (quality) {
      case 'less_than_recommended':
        return Colors.orange;
      case 'more_than_recommended':
        return Colors.blueGrey;
      case 'normal':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sleep Tracker")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  
                  TextFormField(
                    controller: _ageMonthsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Child age (months)",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Required";
                      }
                      final n = int.tryParse(v);
                      if (n == null || n <= 0) {
                        return "Enter a valid age in months";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            sleepStart = await _pickTime();
                            setState(() {});
                          },
                          child: Text(
                            sleepStart == null
                                ? "Sleep Start"
                                : "Start: ${sleepStart!.format(context)}",
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            sleepEnd = await _pickTime();
                            setState(() {});
                          },
                          child: Text(
                            sleepEnd == null
                                ? "Sleep End"
                                : "End: ${sleepEnd!.format(context)}",
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _wakeupsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Night wakeups count",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: _save,
                    child: const Text("Save & Evaluate"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            
            if (_lastComment != null)
              Card(
                color: _qualityColor(_lastQuality).withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Last evaluation",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _qualityColor(_lastQuality),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text("Quality: ${_lastQuality ?? "-"}"),
                      Text("Risk level: ${_lastRisk ?? "-"}"),
                      const SizedBox(height: 4),
                      Text(_lastComment ?? ""),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _sleepRecordsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No sleep data yet."));
                  }

                  final entries = snapshot.data!;
                  return ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final item = entries[i];
                      final String dateStr =
                          item['sleep_date']?.toString() ?? '';
                      final double dur =
                          (item['duration_hours'] as num?)?.toDouble() ?? 0.0;
                      final int wakes =
                          (item['wakeups_count'] as num?)?.toInt() ?? 0;
                      final String quality =
                          (item['sleep_quality'] ?? '') as String;

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _qualityColor(quality).withOpacity(0.8),
                            child: Text(
                              dur.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white),
                            ),
                          ),
                          title:
                              Text("Duration: ${dur.toStringAsFixed(1)} hrs"),
                          subtitle: Text(
                            "Wakeups: $wakes\nDate: $dateStr\nQuality: $quality",
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
