import 'package:flutter/material.dart';
import 'package:nino/screens/addChild.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChildrenListPage extends StatefulWidget {
  const ChildrenListPage({super.key, this.onChildSelected});

  final void Function(int? childId, String name)? onChildSelected;

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
    final parsedId = childId is int
        ? childId
        : int.tryParse(childId?.toString() ?? '');
    final handler = widget.onChildSelected;
    if (handler != null) {
      handler(parsedId, name);
      return;
    }

    Navigator.pop(context, {'childId': childId, 'name': name});
  }

  @override
  Widget build(BuildContext context) {
    Future<void> openAddChild() async {
      final added = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Addchild()),
      );
      if (added == true) {
        await _refresh();
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Children'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF0B3D2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add child',
            onPressed: openAddChild,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit child',
            onPressed: _openEditPicker,
          ),
        ],
      ),
      body: Stack(
        children: [
          const Background(),
          SafeArea(
            child: FutureBuilder<List<dynamic>>(
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

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                                  children: const [
                                    Icon(Icons.info_outline,
                                        color: Color(0xFF00916E)),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Manage your children and tap a card to select.',
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
                              const Text(
                                'Children',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0B3D2E),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      if (children.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                            child: Center(
                              child: Text(
                                'No children found.',
                                style: TextStyle(color: Color(0xFF0B3D2E)),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final child =
                                    children[index] as Map<String, dynamic>;
                                return _buildChildCard(child);
                              },
                              childCount: children.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final name = (child['name'] ?? '').toString();
    final childId = child['child_id'];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _returnSelectedChild(childId, name),
        child: Container(
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
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Unnamed child' : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF0B3D2E),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/child_info',
                          arguments: {'childId': childId, 'name': name},
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00916E),
                      ),
                      child: const Text('Info'),
                    ),
                    ElevatedButton(
                      onPressed: () => _returnSelectedChild(childId, name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00916E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
