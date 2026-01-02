import 'package:flutter/material.dart';
import 'package:nino/screens/addChild.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChildrenListPage extends StatefulWidget {
  const ChildrenListPage({super.key});

  @override
  State<ChildrenListPage> createState() => _ChildrenListPageState();
}

class _ChildrenListPageState extends State<ChildrenListPage> {
  final _supabase = Supabase.instance.client;
  late Future<List<dynamic>> _childrenFuture;

  @override
  void initState() {
    super.initState();
    _childrenFuture = _fetchChildren();
  }

  Future<List<dynamic>> _fetchChildren() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to view children.');
    }

    final data = await _supabase
        .from('children')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return data;
  }

  Future<void> _refresh() async {
    setState(() {
      _childrenFuture = _fetchChildren();
    });
    await _childrenFuture;
  }

  Future<void> _openEditPicker() async {
    List<dynamic> children;
    try {
      children = await _childrenFuture;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load children: $e')),
      );
      return;
    }

    final mapped = children
        .whereType<Map>()
        .map((child) => Map<String, dynamic>.from(child))
        .toList();

    if (mapped.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No children to edit.')),
      );
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Edit child'),
          children: mapped.map((child) {
            final name = (child['name'] ?? '').toString();
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, child),
              child: Text(name.isEmpty ? 'Unnamed child' : name),
            );
          }).toList(),
        );
      },
    );

    if (selected == null) return;

    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            Addchild(child: Map<String, dynamic>.from(selected)),
      ),
    );

    if (updated == true) {
      await _refresh();
    }
  }

  Future<void> _deleteChild(dynamic childId, String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to delete.')),
      );
      return;
    }

    try {
      await _supabase
          .from('children')
          .delete()
          .eq('child_id', childId)
          .eq('user_id', user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Child deleted.')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _confirmDelete(dynamic childId, String name) async {
    final displayName = name.isEmpty ? 'this child' : name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete child'),
          content: Text('Are you sure you want to delete $displayName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteChild(childId, name);
    }
  }

  void _returnSelectedChild(dynamic childId, String name) {
    Navigator.pop(context, {
      'childId': childId,
      'name': name,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Children'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit child',
            onPressed: _openEditPicker,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_child',
        child: const Icon(Icons.add),
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Addchild()),
          );
          if (added == true) {
            await _refresh();
          }
        },
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _childrenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final children = snapshot.data ?? [];
          if (children.isEmpty) {
            return const Center(child: Text('No children found.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index] as Map<String, dynamic>;
                final name = (child['name'] ?? '').toString();
                final childId = child['child_id'];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    title: Text(name.isEmpty ? 'Unnamed child' : name),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/child_info',
                              arguments: {'childId': childId, 'name': name},
                            );
                          },
                          child: const Text('Info'),
                        ),
                        TextButton(
                          onPressed: () => _returnSelectedChild(childId, name),
                          child: const Text('Select'),
                        ),
                        TextButton(
                          onPressed: () => _confirmDelete(childId, name),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                    onTap: () => _returnSelectedChild(childId, name),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
