import 'package:flutter/material.dart';
import '../models/pediatrician.dart';
import '../screens copy/pediatrician_details_screen.dart';

class DoctorCard extends StatelessWidget {
  final Pediatrician pediatrician;
  final double? distanceKm;

  const DoctorCard({
    super.key,
    required this.pediatrician,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final distText = (distanceKm == null)
        ? ''
        : ' • ${distanceKm!.toStringAsFixed(2)} km';

    return ListTile(
      leading: const Icon(Icons.local_hospital),
      title: Text(pediatrician.name),
      subtitle: Text('${pediatrician.address}$distText'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PediatricianDetailsScreen(
              pediatrician: pediatrician,
              distanceKm: distanceKm,
            ),
          ),
        );
      },
    );
  }
}
