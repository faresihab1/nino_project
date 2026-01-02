import 'package:flutter/material.dart';
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Child' : 'Add Child'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Child name',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the child\'s name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: _genders
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
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
                const SizedBox(height: 16),

                
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Birth date',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDate(_selectedBirthDate)),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                
                DropdownButtonFormField<String>(
                  initialValue: _selectedBloodType,
                  decoration: const InputDecoration(
                    labelText: 'Blood type (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: _bloodTypes
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBloodType = value;
                    });
                  },
                ),
                const SizedBox(height: 24),

                
                TextFormField(
                  controller: _allergiesController,
                  decoration: const InputDecoration(
                    labelText: 'Allergies (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                
                TextFormField(
                  controller: _chronicConditionsController,
                  decoration: const InputDecoration(
                    labelText: 'Chronic conditions (optional)',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24),

                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Save Changes' : 'Save Child'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
