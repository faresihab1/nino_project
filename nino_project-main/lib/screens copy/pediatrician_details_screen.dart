import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/pediatrician.dart';

class PediatricianDetailsScreen extends StatelessWidget {
  final Pediatrician pediatrician;
  final double? distanceKm;

  const PediatricianDetailsScreen({
    super.key,
    required this.pediatrician,
    required this.distanceKm,
  });

  Future<void> _openDirections() async {
    final lat = pediatrician.latitude;
    final lng = pediatrician.longitude;

    final url = Platform.isIOS
        ? 'http://maps.apple.com/?daddr=$lat,$lng'
        : 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open maps');
    }
  }

  Future<void> _callPhone() async {
    final phone = pediatrician.phone;
    if (phone == null) return;

    final cleaned = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleaned');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open dialer');
    }
  }

  @override
  Widget build(BuildContext context) {
    final distText = (distanceKm == null)
        ? 'Distance: unknown'
        : 'Distance: ${distanceKm!.toStringAsFixed(2)} km';

    return Scaffold(
      appBar: AppBar(title: Text(pediatrician.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pediatrician.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(pediatrician.address ?? 'Address not available'),
            const SizedBox(height: 8),
            Text('Phone: ${pediatrician.phone ?? 'Not available'}'),
            const SizedBox(height: 8),
            Text(distText),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        pediatrician.phone == null ? null : _callPhone,
                    child: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _openDirections,
                    child: const Text('Get Directions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
