import 'package:flutter/material.dart';
import 'package:nino/screens/add_medicine_page.dart';
import 'package:nino/services/notification_service.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MedicinesListPage extends StatefulWidget {
  const MedicinesListPage({super.key, this.initialChildId});

  final int? initialChildId;

  @override
  State<MedicinesListPage> createState() => _MedicinesListPageState();
}

class _MedicinesListPageState extends State<MedicinesListPage> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _children = [];
  int? _selectedChildId;
  List<Map<String, dynamic>> _medicines = [];
  List<Map<String, dynamic>> _vaccines = [];
  List<Map<String, dynamic>> _vaccineRefs = [];
  final Map<int, _VaccineUndoSnapshot> _vaccineUndoByRefId = {};
  final Set<int> _updatingMedicineIds = {};

  bool _loadingChildren = true;
  bool _loadingMedicines = false;
  bool _loadingVaccines = false;
  bool _loadingVaccineRefs = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.initialChildId;
    _loadChildren();
    _loadVaccineReferences();
  }

  Future<void> _loadChildren() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _loadingChildren = false;
        _errorMessage = 'You must be logged in.';
      });
      return;
    }

    try {
      final data = await _supabase
          .from('children')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();

      int? selected = _selectedChildId;
      if (selected != null) {
        final exists = list.any(
          (c) => _parseChildId(c['child_id']) == selected,
        );
        if (!exists) selected = null;
      }

      setState(() {
        _children = list;
        _selectedChildId = selected;
        _loadingChildren = false;
      });

      if (selected != null) {
        await _loadDataForChild(selected);
      }
    } catch (e) {
      setState(() {
        _loadingChildren = false;
        _errorMessage = 'Failed to load children: $e';
      });
    }
  }

  Future<void> _loadVaccineReferences() async {
    setState(() {
      _loadingVaccineRefs = true;
      _errorMessage = null;
      _vaccineRefs = [];
    });

    try {
      final data = await _supabase
          .from('vaccines_reference')
          .select()
          .order('recommended_age_months', ascending: true);

      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _vaccineRefs = list;
        _loadingVaccineRefs = false;
      });
    } catch (e) {
      setState(() {
        _loadingVaccineRefs = false;
        _errorMessage = 'Failed to load vaccine schedule: $e';
      });
    }
  }

  Future<void> _loadDataForChild(int childId) async {
    await Future.wait([
      _loadMedicinesForChild(childId),
      _loadVaccinesForChild(childId),
    ]);
  }

  Future<void> _loadMedicinesForChild(int childId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loadingMedicines = true;
      _errorMessage = null;
      _medicines = [];
    });

    try {
      final data = await _supabase
          .from('medicines')
          .select(
            'medicine_id,medicine_name,reason,doctor_name,publish_date,'
            'expiry_date,duration_days,created_at,doses_given,is_finished,'
            'medicine_dose_times(dose_time)',
          )
          .eq('user_id', user.id)
          .eq('child_id', childId)
          .order('created_at', ascending: false);

      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _medicines = list;
        _loadingMedicines = false;
      });
    } catch (e) {
      setState(() {
        _loadingMedicines = false;
        _errorMessage = 'Failed to load medicines: $e';
      });
    }
  }

  Future<void> _loadVaccinesForChild(int childId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loadingVaccines = true;
      _errorMessage = null;
      _vaccines = [];
    });

    try {
      final data = await _supabase
          .from('vaccines')
          .select(
            'id,vaccine_ref_id,status,due_date,administered_date,provider,'
            'lot_number,notes',
          )
          .eq('child_id', childId)
          .order('due_date', ascending: true);

      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _vaccines = list;
        _loadingVaccines = false;
      });
    } catch (e) {
      setState(() {
        _loadingVaccines = false;
        _errorMessage = 'Failed to load vaccines: $e';
      });
    }
  }

  int? _parseChildId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  String _stringField(Map<String, dynamic> item, String key) {
    final value = item[key];
    if (value == null) return '';
    return value.toString();
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

  List<TimeOfDay> _doseTimesList(Map<String, dynamic> med) {
    final times = med['medicine_dose_times'];
    if (times is! List) return [];
    return times
        .map((e) {
          final raw = e is Map<String, dynamic>
              ? e['dose_time']?.toString()
              : e?.toString();
          if (raw == null || raw.trim().isEmpty) return null;
          final parts = raw.split(':');
          if (parts.length < 2) return null;
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          return TimeOfDay(hour: hour, minute: minute);
        })
        .whereType<TimeOfDay>()
        .toList();
  }

  int _totalDoses(Map<String, dynamic> med) {
    final days = _parseInt(med['duration_days']);
    final timesCount = _doseTimesCount(med);
    if (days <= 0 || timesCount <= 0) return 0;
    return days * timesCount;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }

  String _doseTimeToDb(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  Future<_DoseScheduleEdit?> _promptEditSchedule({
    required List<TimeOfDay> initialTimes,
    required int initialDays,
  }) async {
    final daysController = TextEditingController(
      text: initialDays > 0 ? initialDays.toString() : '',
    );
    var times = List<TimeOfDay>.from(initialTimes);
    String? errorText;

    try {
      return await showDialog<_DoseScheduleEdit>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> addTime() async {
                final picked = await showTimePicker(
                  context: dialogContext,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setDialogState(() {
                    times.add(picked);
                    errorText = null;
                  });
                }
              }

              return AlertDialog(
                title: const Text('Edit dose schedule'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dose times',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < times.length; i++)
                            Chip(
                              label: Text(_formatTimeOfDay(times[i])),
                              onDeleted: () {
                                setDialogState(() {
                                  times.removeAt(i);
                                  if (times.isNotEmpty) {
                                    errorText = null;
                                  }
                                });
                              },
                            ),
                          ActionChip(
                            label: const Text('Add time'),
                            onPressed: addTime,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: daysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (days)',
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorText!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
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
                      final days =
                          int.tryParse(daysController.text.trim()) ?? 0;
                      if (days <= 0 || times.isEmpty) {
                        setDialogState(() {
                          errorText =
                              'Please set a duration and at least one time.';
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(
                        _DoseScheduleEdit(durationDays: days, times: times),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      daysController.dispose();
    }
  }

  Future<void> _editMedicineSchedule(Map<String, dynamic> med) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final medicineId = _parseChildId(med['medicine_id']);
    if (medicineId == null) return;
    if (_updatingMedicineIds.contains(medicineId)) return;

    final currentDays = _parseInt(med['duration_days']);
    final currentTimes = _doseTimesList(med);
    final result = await _promptEditSchedule(
      initialTimes: currentTimes,
      initialDays: currentDays,
    );
    if (result == null) return;

    setState(() => _updatingMedicineIds.add(medicineId));

    final oldTotal = _totalDoses(med);
    final given = _parseInt(med['doses_given']);
    final newTotal = result.durationDays * result.times.length;
    final newFinished = newTotal > 0 ? given >= newTotal : false;
    final timesList = result.times.map(_doseTimeToDb).toList();

    try {
      await _supabase
          .from('medicines')
          .update({
            'duration_days': result.durationDays,
            'is_finished': newFinished,
          })
          .eq('medicine_id', medicineId)
          .eq('user_id', user.id);

      await _supabase
          .from('medicine_dose_times')
          .delete()
          .eq('medicine_id', medicineId);

      if (timesList.isNotEmpty) {
        final rows = timesList
            .map(
              (time) => {
                'medicine_id': medicineId,
                'dose_time': time,
              },
            )
            .toList();
        await _supabase.from('medicine_dose_times').insert(rows);
      }

      if (oldTotal > 0) {
        await NotificationService.cancelMedicineReminders(
          medicineId: medicineId,
          totalNotifications: oldTotal,
        );
      }

      final childName = _childNameForSelected();
      final name = _stringField(med, 'medicine_name');
      if (newTotal > 0) {
        await NotificationService.scheduleMedicineReminders(
          medicineId: medicineId,
          medicineName: name.isEmpty ? 'Medicine' : name,
          childName: childName,
          doseTimes: result.times,
          durationDays: result.durationDays,
        );
      }

      if (_selectedChildId != null) {
        await _loadMedicinesForChild(_selectedChildId!);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dose schedule updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _updatingMedicineIds.remove(medicineId));
      }
    }
  }

  String? _childNameForSelected() {
    if (_selectedChildId == null) return null;
    final match = _children.firstWhere(
      (c) => _parseChildId(c['child_id']) == _selectedChildId,
      orElse: () => {},
    );
    if (match.isEmpty) return null;
    final name = match['name']?.toString();
    return name == null || name.trim().isEmpty ? null : name;
  }

  bool _isFinished(Map<String, dynamic> med) {
    final flag = med['is_finished'];
    if (flag is bool) return flag;
    final total = _totalDoses(med);
    if (total == 0) return false;
    final given = _parseInt(med['doses_given']);
    return given >= total;
  }

  DateTime? _parseCreatedAt(Map<String, dynamic> med) {
    final value = med['created_at'];
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  List<_VaccineGroup> _buildVaccineGroups() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final ref in _vaccineRefs) {
      final isActive = ref['is_active'];
      if (isActive is bool && !isActive) continue;
      final code = ref['code']?.toString() ?? '';
      if (code.isEmpty) continue;
      grouped.putIfAbsent(code, () => []).add(ref);
    }

    final groups = <_VaccineGroup>[];
    grouped.forEach((code, refs) {
      refs.sort((a, b) {
        final aAge = _parseInt(a['recommended_age_months']);
        final bAge = _parseInt(b['recommended_age_months']);
        if (aAge != bAge) return aAge.compareTo(bAge);
        final aDose = _parseInt(a['dose_number']);
        final bDose = _parseInt(b['dose_number']);
        if (aDose != bDose) return aDose.compareTo(bDose);
        final aBooster = a['is_booster'] == true;
        final bBooster = b['is_booster'] == true;
        if (aBooster != bBooster) return aBooster ? 1 : -1;
        return 0;
      });

      final name = refs.first['name']?.toString() ?? code;
      final minAge = _parseInt(refs.first['recommended_age_months']);
      groups.add(
        _VaccineGroup(
          code: code,
          name: name,
          refs: refs,
          minAgeMonths: minAge,
        ),
      );
    });

    groups.sort((a, b) => a.minAgeMonths.compareTo(b.minAgeMonths));
    return groups;
  }

  Set<int> _givenVaccineRefIds() {
    final ids = <int>{};
    for (final vaccine in _vaccines) {
      final status = vaccine['status']?.toString().toLowerCase();
      if (status != 'given') continue;
      final refId = _parseChildId(vaccine['vaccine_ref_id']);
      if (refId != null) ids.add(refId);
    }
    return ids;
  }

  int _takenCountForGroup(_VaccineGroup group, Set<int> givenRefIds) {
    var count = 0;
    for (final ref in group.refs) {
      final refId = _parseChildId(ref['id']);
      if (refId != null && givenRefIds.contains(refId)) {
        count++;
      }
    }
    return count;
  }

  Map<String, dynamic>? _nextDoseRef(
    _VaccineGroup group,
    Set<int> givenRefIds,
  ) {
    for (final ref in group.refs) {
      final refId = _parseChildId(ref['id']);
      if (refId != null && !givenRefIds.contains(refId)) {
        return ref;
      }
    }
    return null;
  }

  Future<void> _markVaccineTaken(Map<String, dynamic> ref) async {
    if (_selectedChildId == null) return;
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in.')),
      );
      return;
    }
    final refId = _parseChildId(ref['id']);
    if (refId == null) return;

    final today = DateTime.now().toIso8601String().split('T').first;
    final existingIndex = _vaccines.indexWhere(
      (v) => _parseChildId(v['vaccine_ref_id']) == refId,
    );
    final previousStatus =
        existingIndex >= 0 ? _vaccines[existingIndex]['status']?.toString() : null;
    final previousDate = existingIndex >= 0
        ? _vaccines[existingIndex]['administered_date']?.toString()
        : null;
    _vaccineUndoByRefId[refId] = _VaccineUndoSnapshot(
      existed: existingIndex >= 0,
      status: previousStatus,
      administeredDate: previousDate,
    );

    try {
      if (existingIndex >= 0) {
        await _supabase
            .from('vaccines')
            .update({
              'status': 'given',
              'administered_date': today,
            })
            .eq('child_id', _selectedChildId!)
            .eq('vaccine_ref_id', refId);
      } else {
        await _supabase.from('vaccines').insert({
          'child_id': _selectedChildId,
          'vaccine_ref_id': refId,
          'status': 'given',
          'administered_date': today,
        });
      }

      setState(() {
        if (existingIndex >= 0) {
          _vaccines[existingIndex]['status'] = 'given';
          _vaccines[existingIndex]['administered_date'] = today;
        } else {
          _vaccines.add({
            'child_id': _selectedChildId,
            'vaccine_ref_id': refId,
            'status': 'given',
            'administered_date': today,
          });
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vaccine marked as taken.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  DateTime? _parseVaccineDate(Map<String, dynamic> vaccine) {
    final raw =
        vaccine['administered_date'] ??
        vaccine['due_date'] ??
        vaccine['created_at'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  Map<String, dynamic>? _latestGivenVaccineForGroup(_VaccineGroup group) {
    final refIds = group.refs
        .map((ref) => _parseChildId(ref['id']))
        .whereType<int>()
        .toSet();

    final given = _vaccines
        .where((v) {
          final refId = _parseChildId(v['vaccine_ref_id']);
          final status = v['status']?.toString().toLowerCase();
          return refId != null && refIds.contains(refId) && status == 'given';
        })
        .toList();

    if (given.isEmpty) return null;

    given.sort((a, b) {
      final aDate = _parseVaccineDate(a);
      final bDate = _parseVaccineDate(b);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return given.first;
  }

  Future<void> _undoLatestVaccineForGroup(_VaccineGroup group) async {
    final childId = _selectedChildId;
    if (childId == null) return;

    final latest = _latestGivenVaccineForGroup(group);
    final refId = latest == null ? null : _parseChildId(latest['vaccine_ref_id']);
    if (refId == null) return;

    final snapshot = _vaccineUndoByRefId[refId];
    final existed = snapshot?.existed ?? true;
    final previousStatus = snapshot?.status ?? 'pending';
    final previousDate = snapshot?.administeredDate;

    if (!existed) {
      setState(() {
        _vaccines.removeWhere(
          (v) => _parseChildId(v['vaccine_ref_id']) == refId,
        );
      });
      try {
        await _supabase
            .from('vaccines')
            .delete()
            .eq('child_id', childId)
            .eq('vaccine_ref_id', refId);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Undo failed: $e')));
      }
      return;
    }

    final index = _vaccines.indexWhere(
      (v) => _parseChildId(v['vaccine_ref_id']) == refId,
    );
    if (index >= 0) {
      setState(() {
        _vaccines[index]['status'] = previousStatus;
        _vaccines[index]['administered_date'] = previousDate;
      });
    }

    try {
      await _supabase
          .from('vaccines')
          .update({
            'status': previousStatus,
            'administered_date': previousDate,
          })
          .eq('child_id', childId)
          .eq('vaccine_ref_id', refId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Undo failed: $e')));
    }
  }

  Future<void> _markDoseGiven(Map<String, dynamic> med) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final medicineId = med['medicine_id'];
    if (medicineId == null) return;

    final total = _totalDoses(med);
    if (total <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set duration and dose times first.')),
      );
      return;
    }

    final current = _parseInt(med['doses_given']);
    if (current >= total || _isFinished(med)) return;

    final next = current + 1;
    final finished = next >= total;

    setState(() {
      med['doses_given'] = next;
      if (finished) med['is_finished'] = true;
    });

    try {
      await _supabase
          .from('medicines')
          .update({'doses_given': next, 'is_finished': finished})
          .eq('medicine_id', medicineId)
          .eq('user_id', user.id);
      if (!mounted) return;
      if (finished && total > 0) {
        await NotificationService.cancelMedicineReminders(
          medicineId: medicineId,
          totalNotifications: total,
        );
      }
      final message =
          finished ? 'Dose recorded. This medicine is finished.' : 'Dose recorded.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      if (_selectedChildId != null) {
        await _loadMedicinesForChild(_selectedChildId!);
      }
    }
  }

  Future<void> _undoDoseGiven(Map<String, dynamic> med) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final medicineId = med['medicine_id'];
    if (medicineId == null) return;

    final current = _parseInt(med['doses_given']);
    if (current <= 0) return;

    final newGiven = current - 1;
    final total = _totalDoses(med);
    final wasFinished = _isFinished(med);
    final newFinished = total > 0 ? newGiven >= total : false;

    setState(() {
      med['doses_given'] = newGiven;
      med['is_finished'] = newFinished;
    });

    try {
      await _supabase
          .from('medicines')
          .update({
            'doses_given': newGiven,
            'is_finished': newFinished,
          })
          .eq('medicine_id', medicineId)
          .eq('user_id', user.id);
      if (!mounted) return;
      if (wasFinished && total > 0) {
        final name = _stringField(med, 'medicine_name');
        final childName = _childNameForSelected();
        final durationDays = _parseInt(med['duration_days']);
        final doseTimes = _doseTimesList(med);
        await NotificationService.scheduleMedicineReminders(
          medicineId: medicineId as int,
          medicineName: name.isEmpty ? 'Medicine' : name,
          childName: childName,
          doseTimes: doseTimes,
          durationDays: durationDays,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Undo failed: $e')));
      if (_selectedChildId != null) {
        await _loadMedicinesForChild(_selectedChildId!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Medicines & Vaccines'),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Color(0xFF00916E)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedChildId == null
                                      ? 'Select a child to view medicines and vaccines.'
                                      : 'Track medicines and vaccines for your child.',
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Child',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0B3D2E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildChildSelector(),
                            ],
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ..._buildMedicinesSlivers(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_medicine',
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.local_hospital_outlined),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddMedicinePage(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChildSelector() {
    if (_loadingChildren) {
      return const LinearProgressIndicator();
    }

    if (_children.isEmpty) {
      return const Text('No children found. Add a child first.');
    }

    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: _selectedChildId,
      hint: const Text('Select a child'),
      decoration: _inputDecoration(
        'Child',
        icon: Icons.child_care_outlined,
      ),
      items: _children.map((c) {
        final id = _parseChildId(c['child_id']);
        final name = (c['name'] ?? 'Unnamed').toString();
        return DropdownMenuItem<int>(
          value: id,
          child: Text('$name (${id ?? '-'})'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedChildId = value;
        });
        if (value != null) {
          _loadDataForChild(value);
        }
      },
    );
  }

  List<Widget> _buildMedicinesSlivers() {
    if (_selectedChildId == null) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Center(
              child: Text(
                'Select a child to view medicines and vaccines.',
                style: TextStyle(color: Color(0xFF0B3D2E)),
              ),
            ),
          ),
        ),
      ];
    }

    if (_loadingMedicines || _loadingVaccines || _loadingVaccineRefs) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    final hasMedicines = _medicines.isNotEmpty;
    final hasVaccines = _vaccineRefs.isNotEmpty;

    if (!hasMedicines && !hasVaccines) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Center(
              child: Text(
                'No medicines or vaccines yet.',
                style: TextStyle(color: Color(0xFF0B3D2E)),
              ),
            ),
          ),
        ),
      ];
    }

    final givenRefIds = _givenVaccineRefIds();
    final groups = _buildVaccineGroups();
    final visibleGroups = <_VaccineGroup>[];
    for (final group in groups) {
      final taken = _takenCountForGroup(group, givenRefIds);
      if (taken < group.refs.length) {
        visibleGroups.add(group);
      }
    }

    final medicines = List<Map<String, dynamic>>.from(_medicines);
    medicines.sort((a, b) {
      final aFinished = _isFinished(a);
      final bFinished = _isFinished(b);
      if (aFinished != bFinished) {
        return aFinished ? 1 : -1;
      }
      final aCreated = _parseCreatedAt(a);
      final bCreated = _parseCreatedAt(b);
      if (aCreated != null && bCreated != null) {
        return bCreated.compareTo(aCreated);
      }
      return 0;
    });

    final items = <Widget>[];
    items.add(const _SectionHeader(title: 'Medicines'));
    if (!hasMedicines) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'No medicines for this child yet.',
            style: TextStyle(color: Color(0xFF0B3D2E)),
          ),
        ),
      );
    } else {
      for (final med in medicines) {
        items.add(_buildMedicineCard(med));
      }
    }

    items.add(const SizedBox(height: 12));
    items.add(const _SectionHeader(title: 'Vaccines'));
    if (!hasVaccines) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'No vaccine schedule found.',
            style: TextStyle(color: Color(0xFF0B3D2E)),
          ),
        ),
      );
    }
    if (hasVaccines && visibleGroups.isEmpty) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'All vaccines have been marked as taken.',
            style: TextStyle(color: Color(0xFF0B3D2E)),
          ),
        ),
      );
    }
    for (final group in visibleGroups) {
      items.add(
        _buildVaccineCard(
          group,
          _takenCountForGroup(group, givenRefIds),
          group.refs.length,
          _nextDoseRef(group, givenRefIds),
        ),
      );
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => items[index],
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildMedicineCard(Map<String, dynamic> med) {
    final name = _stringField(med, 'medicine_name');
    final reason = _stringField(med, 'reason');
    final doctor = _stringField(med, 'doctor_name');
    final times = _formatTimes(med['medicine_dose_times']);
    final days = _stringField(med, 'duration_days');
    final publishDate = _stringField(med, 'publish_date');
    final expiryDate = _stringField(med, 'expiry_date');
    final total = _totalDoses(med);
    final given = _parseInt(med['doses_given']);
    final finished = _isFinished(med);
    final canUndo = given > 0;
    final medicineId = _parseChildId(med['medicine_id']);
    final isUpdating =
        medicineId != null && _updatingMedicineIds.contains(medicineId);

    final details = <String>[];
    if (reason.isNotEmpty) details.add('Reason: $reason');
    if (doctor.isNotEmpty) details.add('Doctor: $doctor');
    if (times.isNotEmpty) details.add('Times: $times');
    if (days.isNotEmpty) details.add('Duration: $days days');
    if (publishDate.isNotEmpty) details.add('Publish: $publishDate');
    if (expiryDate.isNotEmpty) details.add('Expiry: $expiryDate');

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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Unnamed medicine' : name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF0B3D2E),
                    ),
                  ),
                ),
                if (finished)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            if (details.isNotEmpty) const SizedBox(height: 8),
            for (final line in details)
              Text(
                line,
                style: const TextStyle(color: Color(0xFF0B3D2E)),
              ),
            const SizedBox(height: 8),
            if (total > 0)
              Text(
                'Doses: $given / $total',
                style: const TextStyle(color: Color(0xFF0B3D2E)),
              )
            else
              const Text(
                'Doses: not set',
                style: TextStyle(color: Color(0xFF0B3D2E)),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: finished ? null : () => _markDoseGiven(med),
                    child: Text(finished ? 'Finished' : 'Dose given'),
                  ),
                  OutlinedButton(
                    onPressed: canUndo ? () => _undoDoseGiven(med) : null,
                    child: const Text('Undo'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        isUpdating ? null : () => _editMedicineSchedule(med),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit schedule'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccineCard(
    _VaccineGroup group,
    int takenCount,
    int totalCount,
    Map<String, dynamic>? nextRef,
  ) {
    final name = group.name;
    final code = group.code;
    final protectsAgainst = nextRef == null
        ? _stringField(group.refs.first, 'protects_against')
        : _stringField(nextRef, 'protects_against');
    final ageValue =
        nextRef == null ? '' : _stringField(nextRef, 'recommended_age_value');
    final ageUnit =
        nextRef == null ? '' : _stringField(nextRef, 'recommended_age_unit');
    final isBooster = nextRef?['is_booster'] == true;
    final doseNumber = nextRef == null ? '' : _stringField(nextRef, 'dose_number');

    final details = <String>[];
    if (code.isNotEmpty) details.add('Code: $code');
    if (totalCount > 0) details.add('Doses: $takenCount / $totalCount');
    if (doseNumber.isNotEmpty) {
      details.add('Next dose: $doseNumber${isBooster ? ' (Booster)' : ''}');
    } else if (isBooster) {
      details.add('Next dose: Booster');
    }
    if (ageValue.isNotEmpty && ageUnit.isNotEmpty) {
      details.add('Recommended age: $ageValue $ageUnit');
    }
    if (protectsAgainst.isNotEmpty) {
      details.add('Protects against: $protectsAgainst');
    }

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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? 'Unnamed vaccine' : name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF0B3D2E),
              ),
            ),
            if (details.isNotEmpty) const SizedBox(height: 8),
            for (final line in details)
              Text(
                line,
                style: const TextStyle(color: Color(0xFF0B3D2E)),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: nextRef == null
                        ? null
                        : () => _markVaccineTaken(nextRef),
                    child: const Text('Mark dose as taken'),
                  ),
                  OutlinedButton(
                    onPressed: _latestGivenVaccineForGroup(group) == null
                        ? null
                        : () => _undoLatestVaccineForGroup(group),
                    child: const Text('Undo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    
  }
}

class _VaccineUndoSnapshot {
  final bool existed;
  final String? status;
  final String? administeredDate;

  _VaccineUndoSnapshot({
    required this.existed,
    required this.status,
    required this.administeredDate,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0B3D2E),
        ),
      ),
    );
  }
}

class _VaccineGroup {
  final String code;
  final String name;
  final List<Map<String, dynamic>> refs;
  final int minAgeMonths;

  _VaccineGroup({
    required this.code,
    required this.name,
    required this.refs,
    required this.minAgeMonths,
  });
}

class _DoseScheduleEdit {
  final int durationDays;
  final List<TimeOfDay> times;

  _DoseScheduleEdit({required this.durationDays, required this.times});
}
