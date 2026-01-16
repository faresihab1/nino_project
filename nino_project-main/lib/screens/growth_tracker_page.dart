import 'package:flutter/material.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GrowthTrackerPage extends StatefulWidget {
  final int? childId;

  const GrowthTrackerPage({super.key, this.childId});

  @override
  State<GrowthTrackerPage> createState() => _GrowthTrackerPageState();
}

class _GrowthTrackerPageState extends State<GrowthTrackerPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();

  final supabase = Supabase.instance.client;

  final List<String> _genders = ['male', 'female'];
  String? _selectedGender;

  late Future<List<dynamic>> _growthRecordsFuture;

  String? _lastStatus;
  String? _lastComment;

  @override
  void initState() {
    super.initState();
    _growthRecordsFuture = _fetchGrowthData();
    _loadChildInfo();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadChildInfo() async {
    final user = supabase.auth.currentUser;

    if (user == null || widget.childId == null) {
      setState(() {
        _selectedGender = null;
        _ageController.text = '';
      });
      return;
    }

    try {
      final child = await supabase
          .from('children')
          .select('gender, birth_date')
          .eq('child_id', widget.childId!)
          .maybeSingle();

      if (child == null) {
        setState(() {
          _selectedGender = null;
          _ageController.text = '';
        });
        return;
      }

      final gender = child['gender']?.toString();
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
        _selectedGender = gender;
        _ageController.text = ageMonths?.toString() ?? '';
      });
    } catch (_) {
      // leave fields editable if anything fails
    }
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

  Future<void> _saveGrowthData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null || _selectedGender!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select gender")),
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

    final double weight = double.parse(_weightController.text.trim());
    final double height = double.parse(_heightController.text.trim());
    final int age = int.parse(_ageController.text.trim());

    final double bmi = weight / ((height / 100) * (height / 100));

    final refRows = await supabase
        .from('growth_reference')
        .select()
        .eq('gender', _selectedGender!)
        .lte('min_age_month', age)
        .gte('max_age_month', age)
        .limit(1);

    if (refRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("No reference data found for this age & gender.")),
      );
      return;
    }

    final ref = refRows.first;

    final double? minW = ref['min_weight_kg'] != null
        ? (ref['min_weight_kg'] as num).toDouble()
        : null;
    final double? maxW = ref['max_weight_kg'] != null
        ? (ref['max_weight_kg'] as num).toDouble()
        : null;
    final double? minH = ref['min_height_cm'] != null
        ? (ref['min_height_cm'] as num).toDouble()
        : null;
    final double? maxH = ref['max_height_cm'] != null
        ? (ref['max_height_cm'] as num).toDouble()
        : null;

    final String notes = (ref['notes'] ?? '') as String;

    String status = 'normal';
    final List<String> issues = [];

    if (minW != null && weight < minW) {
      status = 'below_range';
      issues.add(
        "weight is below normal (${weight.toStringAsFixed(1)} kg < ${minW.toStringAsFixed(1)} kg)",
      );
    } else if (maxW != null && weight > maxW) {
      status = 'above_range';
      issues.add(
        "weight is above normal (${weight.toStringAsFixed(1)} kg > ${maxW.toStringAsFixed(1)} kg)",
      );
    }

    if (minH != null && height < minH) {
      status = status == 'normal' ? 'below_range' : status;
      issues.add(
        "height is below normal (${height.toStringAsFixed(1)} cm < ${minH.toStringAsFixed(1)} cm)",
      );
    } else if (maxH != null && height > maxH) {
      status = status == 'normal' ? 'above_range' : status;
      issues.add(
        "height is above normal (${height.toStringAsFixed(1)} cm > ${maxH.toStringAsFixed(1)} cm)",
      );
    }

    final String comment = issues.isEmpty
        ? "Your child's measurements are within the normal range for this age and gender. $notes"
        : "There are some deviations from normal: ${issues.join('; ')}. $notes";

    try {
      await supabase.from('growth_records').insert({
        'user_id': user.id,
        'child_id': widget.childId,
        'age_months': age,
        'gender': _selectedGender,
        'weight_kg': weight,
        'height_cm': height,
        'bmi': bmi,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved & evaluated!")),
      );

      setState(() {
        _lastStatus = status;
        _lastComment = comment;
        _growthRecordsFuture = _fetchGrowthData();
        _weightController.clear();
        _heightController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving data: $e")),
      );
    }
  }

  Future<List<dynamic>> _fetchGrowthData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    var query = supabase.from('growth_records').select().eq('user_id', user.id);
    if (widget.childId != null) {
      query = query.eq('child_id', widget.childId!);
    }

    final data = await query.order('created_at', ascending: false);
    return data;
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'below_range':
        return const Color(0xFFF2C57C); // sand
      case 'above_range':
        return const Color(0xFFF0A6A6); // rose
      case 'normal':
        return const Color(0xFF9FD6B8); // green
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'below_range':
        return 'Below range';
      case 'above_range':
        return 'Above range';
      case 'normal':
        return 'Normal';
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Growth Tracker'),
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
                        // Hint / info
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
                                  widget.childId == null
                                      ? 'Select a child first to save growth records.'
                                      : 'Enter weight & height to save and get a quick evaluation.',
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
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedGender,
                                  decoration: _inputDecoration('Gender',
                                      icon: Icons.wc),
                                  items: _genders
                                      .map((g) => DropdownMenuItem(
                                            value: g,
                                            child: Text(
                                              g[0].toUpperCase() +
                                                  g.substring(1),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedGender = value);
                                  },
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                          ? 'Please select gender'
                                          : null,
                                ),
                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _ageController,
                                  decoration: _inputDecoration('Age (months)',
                                      icon: Icons.cake_outlined),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _weightController,
                                  decoration: _inputDecoration('Weight (kg)',
                                      icon: Icons.monitor_weight_outlined),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _heightController,
                                  decoration: _inputDecoration('Height (cm)',
                                      icon: Icons.height_outlined),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 14),

                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: _saveGrowthData,
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text(
                                      'Save & Evaluate',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00916E),
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

                        const SizedBox(height: 12),

                        // Evaluation card
                        if (_lastComment != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.82),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _statusColor(_lastStatus).withOpacity(0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _statusColor(_lastStatus).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.health_and_safety_outlined,
                                          color: _statusColor(_lastStatus),
                                          size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        _statusLabel(_lastStatus),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _statusColor(_lastStatus),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Last evaluation',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0B3D2E),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _lastComment ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFF0B3D2E),
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0B3D2E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // History list
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: FutureBuilder<List<dynamic>>(
                    future: _growthRecordsFuture,
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
                            child: Center(child: Text('No growth data yet.')),
                          ),
                        );
                      }

                      final entries = snapshot.data!;
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final item = entries[i];

                            final double w =
                                (item['weight_kg'] as num?)?.toDouble() ?? 0.0;
                            final double h =
                                (item['height_cm'] as num?)?.toDouble() ?? 0.0;
                            final double bmi =
                                (item['bmi'] as num?)?.toDouble() ?? 0.0;
                            final int age =
                                (item['age_months'] as num?)?.toInt() ?? 0;
                            final String gender =
                                (item['gender'] ?? '') as String;
                            final String date =
                                (item['created_at'] ?? '').toString();

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
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00916E)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.monitor_weight_outlined,
                                    color: Color(0xFF00916E),
                                  ),
                                ),
                                title: Text(
                                  'W: ${w.toStringAsFixed(1)} kg  •  H: ${h.toStringAsFixed(1)} cm',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0B3D2E),
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Age: $age months • Gender: $gender\nBMI: ${bmi.toStringAsFixed(1)} • Date: $date',
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