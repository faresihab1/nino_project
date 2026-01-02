import 'package:flutter/material.dart';
import 'package:nino/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'growth_tracker_page.dart';
import 'sleep_tracker_page.dart';
import 'medical_card_page.dart';
import 'medicines_list_page.dart';
import 'chatbot.dart';
import 'lab_analyzer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;

  int? _selectedChildId;
  String? _selectedChildName;

  void _clearSelectedChild() {
    setState(() {
      _selectedChildId = null;
      _selectedChildName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedName =
        (_selectedChildName != null && _selectedChildName!.trim().isNotEmpty)
            ? _selectedChildName!
            : 'Unnamed child';

    return Scaffold(
      body: Stack(
        children: [
          const Background(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  /// ─── HEADER ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedChildId != null
                              ? 'Selected Child: $selectedName'
                              : 'No child selected yet',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_selectedChildId != null)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearSelectedChild,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  /// ─── GRID (FILLS SCREEN, NO SCROLL) ───
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 16.0;
                        const rows = 3;
                        const columns = 2;

                        final cardHeight =
                            (constraints.maxHeight - spacing * (rows - 1)) /
                                rows;

                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            mainAxisExtent: cardHeight,
                          ),
                          itemCount: 6,
                          itemBuilder: (context, index) {
                            final cards = [
                              /// 🌱 Growth Tracker (Health & Progress)
                              DashboardCard(
                                title: "Growth Tracker",
                                icon: Icons.monitor_weight_outlined,
                                color: const Color(0xFF9FD6B8), // #9FD6B8
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GrowthTrackerPage(
                                        childId: _selectedChildId,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              /// 🌙 Sleep Tracker (Calm & Night)
                              DashboardCard(
                                title: "Sleep Tracker",
                                icon: Icons.bedtime_outlined,
                                color: const Color(0xFFA9B8E8), // #A9B8E8
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SleepTrackerPage(
                                        childId: _selectedChildId,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              /// 🩺 Medical Card (Care, Not Alarm)
                              DashboardCard(
                                title: "Medical Card",
                                icon: Icons.medical_information_outlined,
                                color: const Color(0xFFF0A6A6), // #F0A6A6
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MedicalCardPage(),
                                    ),
                                  );
                                },
                              ),

                              /// 💉 Medicines & Vaccinations (Trust & Structure)
                              DashboardCard(
                                title: "Medicines & Vaccinations",
                                icon: Icons.medication_outlined,
                                color: const Color(0xFFAFC2CC), // #AFC2CC
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MedicinesListPage(
                                        initialChildId: _selectedChildId,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              /// 💬 Chatbot (Friendly & Supportive)
                              DashboardCard(
                                title: "Chatbot",
                                icon: Icons.chat_bubble_outline,
                                color: const Color(0xFF8EDAD0), // #8EDAD0
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatbotPage(),
                                    ),
                                  );
                                },
                              ),

                              /// 🧪 Lab Analyzer (Insight & Attention)
                              DashboardCard(
                                title: "Lab Analyzer",
                                icon: Icons.camera_alt_outlined,
                                color: const Color(0xFFF2C57C), // #F2C57C
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LabAnalyzerPage(),
                                    ),
                                  );
                                },
                              ),
                            ];

                            return cards[index];
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// DASHBOARD CARD (SOFT / CALM STYLE)
/// ─────────────────────────────────────────────
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.circle, size: 0), // keeps layout stable

            Icon(icon, size: 42, color: Colors.white),

            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF), // #FFFFFF33
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Open",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}