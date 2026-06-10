import 'package:flutter/material.dart';
import 'package:ppn/core/constants/app_colors.dart';

/// A generic placeholder screen used for routes that are not yet implemented.
///
/// Displays a construction icon, the given [title], and a "Coming soon..."
/// message centered on screen.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Coming soon...', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
