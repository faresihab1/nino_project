import 'package:flutter/material.dart';
import 'package:nino/services/notification_service.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddMedicinePage extends StatefulWidget {
  const AddMedicinePage({super.key});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _children = [];
  int? _selectedChildId;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _reasonController = TextEditingController();
  final _doctorController = TextEditingController();
  final _daysController = TextEditingController();
  final _publishDateController = TextEditingController();
  final _expiryDateController = TextEditingController();

  final List<TimeOfDay> _doseTimes = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    _doctorController.dispose();
    _daysController.dispose();
    _publishDateController.dispose();
    _expiryDateController.dispose();
    super.dispose();
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

  Future<void> _loadChildren() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase
          .from('children')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Supabase `select()` returns a List when rows are returned.
      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _children = list;
        if (_children.isNotEmpty) {
          final firstId = _children.first['child_id'];
          _selectedChildId = firstId is int
              ? firstId
              : int.tryParse(firstId?.toString() ?? '');
        }
      });
    } catch (e) {
      // ignore load errors for now
    }
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be logged in')));
      return;
    }

    if (_selectedChildId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a child first')));
      return;
    }

    final name = _nameController.text.trim();
    final reason = _reasonController.text.trim();
    final doctor = _doctorController.text.trim();
    final days = int.tryParse(_daysController.text.trim()) ?? 0;
    final publishDate = _publishDateController.text.trim();
    final expiryDate = _expiryDateController.text.trim();
    final timesList = _doseTimes
        .map(
          (t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00',
        )
        .toList();

    setState(() => _loading = true);
    try {
      final payload = {
        'user_id': user.id,
        'child_id': _selectedChildId,
        'medicine_name': name,
        'reason': reason.isEmpty ? null : reason,
        'doctor_name': doctor.isEmpty ? null : doctor,
        'duration_days': days > 0 ? days : null,
        'publish_date': publishDate.isEmpty ? null : publishDate,
        'expiry_date': expiryDate.isEmpty ? null : expiryDate,
        'doses_given': 0,
        'is_finished': false,
      };

      final inserted = await supabase
          .from('medicines')
          .insert(payload)
          .select('medicine_id')
          .single();

      final medicineId = inserted['medicine_id'] as int?;
      if (medicineId != null && timesList.isNotEmpty) {
        final rows = timesList
            .map(
              (time) => {
                'medicine_id': medicineId,
                'dose_time': time,
              },
            )
            .toList();
        await supabase.from('medicine_dose_times').insert(rows);
      }

      if (medicineId != null) {
        final selectedChild = _children.firstWhere(
          (c) => c['child_id'] == _selectedChildId,
          orElse: () => {},
        );
        final childName =
            selectedChild.isEmpty ? null : selectedChild['name']?.toString();
        await NotificationService.scheduleMedicineReminders(
          medicineId: medicineId,
          medicineName: name,
          childName: childName,
          doseTimes: List<TimeOfDay>.from(_doseTimes),
          durationDays: days,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Medicine saved')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Add Medicine'),
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
                              const Expanded(
                                child: Text(
                                  'Add a medicine and set its dose schedule.',
                                  style: TextStyle(
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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  initialValue: _selectedChildId,
                                  decoration: _inputDecoration(
                                    'Child',
                                    icon: Icons.child_care_outlined,
                                  ),
                                  items: _children.map((c) {
                                    final id = c['child_id'] as int?;
                                    final name =
                                        (c['name'] ?? 'Unnamed') as String;
                                    return DropdownMenuItem<int>(
                                      value: id,
                                      child: Text('$name (${id ?? '-'})'),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedChildId = v),
                                  hint: const Text('Choose a child'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: _inputDecoration(
                                    'Medicine name',
                                    icon: Icons.local_hospital_outlined,
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _reasonController,
                                  decoration: _inputDecoration(
                                    'For what (reason)',
                                    icon: Icons.chat_bubble_outline,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _doctorController,
                                  decoration: _inputDecoration(
                                    'Doctor name (recommended by)',
                                    icon: Icons.medical_services_outlined,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _publishDateController,
                                  decoration: _inputDecoration(
                                    'Publish date',
                                    icon: Icons.event_outlined,
                                  ).copyWith(hintText: 'YYYY-MM-DD'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _expiryDateController,
                                  decoration: _inputDecoration(
                                    'Expiry date',
                                    icon: Icons.event_busy_outlined,
                                  ).copyWith(hintText: 'YYYY-MM-DD'),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Dose times',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0B3D2E),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (var i = 0; i < _doseTimes.length; i++)
                                      Chip(
                                        label: Text(
                                          MaterialLocalizations.of(context)
                                              .formatTimeOfDay(
                                            _doseTimes[i],
                                            alwaysUse24HourFormat: false,
                                          ),
                                        ),
                                        onDeleted: () =>
                                            setState(() => _doseTimes.removeAt(i)),
                                      ),
                                    ActionChip(
                                      label: const Text('Add time'),
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.now(),
                                        );
                                        if (picked != null) {
                                          setState(() => _doseTimes.add(picked));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _daysController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    'Duration (days)',
                                    icon: Icons.timelapse_outlined,
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: _loading ? null : _saveMedicine,
                                    icon: _loading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.check_circle_outline),
                                    label: const Text(
                                      'Save Medicine',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF00916E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
