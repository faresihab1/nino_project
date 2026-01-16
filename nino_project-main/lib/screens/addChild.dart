import 'package:flutter/material.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Addchild extends StatefulWidget {
  const Addchild({super.key, this.child});

  final Map<String, dynamic>? child;

  @override
  State<Addchild> createState() => _AddchildState();
}

class _AddchildState extends State<Addchild> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _chronicConditionsController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedBirthDate;
  String? _selectedBloodType;
  bool _isLoading = false;

  
  final _genders = const ['male', 'female'];
  final _bloodTypes = const ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  bool get _isEditing => widget.child != null;

  @override
  void initState() {
    super.initState();
    _prefillFromChild();
  }

  void _prefillFromChild() {
    final child = widget.child;
    if (child == null) return;

    _nameController.text = child['name']?.toString() ?? '';
    _allergiesController.text = child['allergies']?.toString() ?? '';
    _chronicConditionsController.text =
        child['chronic_conditions']?.toString() ?? '';

    final gender = child['gender']?.toString();
    if (gender != null && _genders.contains(gender)) {
      _selectedGender = gender;
    }

    final bloodType = child['blood_type']?.toString();
    if (bloodType != null && _bloodTypes.contains(bloodType)) {
      _selectedBloodType = bloodType;
    }

    _selectedBirthDate = _parseBirthDate(child['birth_date']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _allergiesController.dispose();
    _chronicConditionsController.dispose();
    super.dispose();
  }

  DateTime? _parseBirthDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return DateTime.tryParse(value.toString());
  }

  int? _parseChildId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 20); 
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select birth date';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select birth date')));
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select gender')));
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save a child')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final allergies = _allergiesController.text.trim();
      final chronicConditions = _chronicConditionsController.text.trim();
      final name = _nameController.text.trim();
      final birthDate = _selectedBirthDate!.toIso8601String().split('T').first;

      if (_isEditing) {
        final childId = _parseChildId(widget.child?['child_id']);
        if (childId == null) {
          throw 'Invalid child record.';
        }

        await Supabase.instance.client
            .from('children')
            .update({
              'name': name,
              'gender': _selectedGender,
              'birth_date': birthDate,
              'blood_type': _selectedBloodType,
              'allergies': allergies.isEmpty ? null : allergies,
              'chronic_conditions':
                  chronicConditions.isEmpty ? null : chronicConditions,
            })
            .eq('child_id', childId)
            .eq('user_id', user.id);
      } else {
        final payload = <String, dynamic>{
          'user_id': user.id,
          'name': name,
          'gender': _selectedGender,
          'birth_date': birthDate,
          'blood_type': _selectedBloodType,
        };

        if (allergies.isNotEmpty) {
          payload['allergies'] = allergies;
        }

        if (chronicConditions.isNotEmpty) {
          payload['chronic_conditions'] = chronicConditions;
        }

        
        await Supabase.instance.client.from('children').insert(payload);
      }

      if (!mounted) return;

      final message = _isEditing
          ? 'Child updated successfully'
          : 'Child added successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.of(context).pop(true); 
    } catch (error) {
      if (!mounted) return;
      final message = _isEditing
          ? 'Error updating child: $error'
          : 'Error adding child: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Child' : 'Add Child'),
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
                              Expanded(
                                child: Text(
                                  _isEditing
                                      ? 'Update your child profile details.'
                                      : 'Add your child details to create a profile.',
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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: _inputDecoration(
                                    'Child name',
                                    icon: Icons.person_outline,
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Please enter the child\'s name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedGender,
                                  decoration: _inputDecoration(
                                    'Gender',
                                    icon: Icons.wc,
                                  ),
                                  items: _genders
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g,
                                          child: Text(
                                            g[0].toUpperCase() + g.substring(1),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGender = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select gender';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: _pickBirthDate,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InputDecorator(
                                    decoration: _inputDecoration(
                                      'Birth date',
                                      icon: Icons.cake_outlined,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDate(_selectedBirthDate)),
                                        const Icon(Icons.calendar_today),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedBloodType,
                                  decoration: _inputDecoration(
                                    'Blood type (optional)',
                                    icon: Icons.bloodtype_outlined,
                                  ),
                                  items: _bloodTypes
                                      .map(
                                        (b) => DropdownMenuItem(
                                          value: b,
                                          child: Text(b),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedBloodType = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _allergiesController,
                                  decoration: _inputDecoration(
                                    'Allergies (optional)',
                                    icon: Icons.warning_amber_outlined,
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _chronicConditionsController,
                                  decoration: _inputDecoration(
                                    'Chronic conditions (optional)',
                                    icon: Icons.health_and_safety_outlined,
                                  ),
                                  textInputAction: TextInputAction.done,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _submit,
                                    icon: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.check_circle_outline),
                                    label: Text(
                                      _isEditing
                                          ? 'Save Changes'
                                          : 'Save Child',
                                      style: const TextStyle(
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
