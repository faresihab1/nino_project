import 'package:flutter/material.dart';
import 'package:nino/widgets/background.dart';

class LabAnalyzerPage extends StatelessWidget {
  const LabAnalyzerPage({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be available soon.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Lab Analyzer'),
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
                            children: const [
                              Icon(Icons.info_outline,
                                  color: Color(0xFF00916E)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Upload or capture lab results for analysis.',
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
                          child: _HeroCard(
                            onTapInfo: () =>
                                _comingSoon(context, 'AI analysis'),
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
                          child: const _EmptyState(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.upload_file_outlined),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00916E),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () =>
                                    _comingSoon(context, 'Upload & analyze'),
                                label: const Text('Upload PDF/Image'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.photo_camera_outlined),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFF00916E),
                                  ),
                                  foregroundColor: const Color(0xFF00916E),
                                ),
                                onPressed: () =>
                                    _comingSoon(context, 'Capture & analyze'),
                                label: const Text('Capture Photo'),
                              ),
                            ),
                          ],
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

class _HeroCard extends StatelessWidget {
  final VoidCallback onTapInfo;
  const _HeroCard({required this.onTapInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0xFFE7F5F1),
            child: Icon(Icons.analytics_outlined,
                color: Color(0xFF00916E), size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analyze lab reports easily',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0B3D2E),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Upload or capture lab results. AI insights will appear here once connected.',
                  style: TextStyle(
                    color: Color(0xFF0B3D2E),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTapInfo,
            icon: const Icon(Icons.info_outline, color: Color(0xFF00916E)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.insert_drive_file_outlined,
              size: 52, color: Color(0xFF00916E)),
          SizedBox(height: 12),
          Text(
            'No reports yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0B3D2E),
            ),
          ),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Upload a PDF or image of your lab results to view them here.',
              style: TextStyle(color: Color(0xFF0B3D2E)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
