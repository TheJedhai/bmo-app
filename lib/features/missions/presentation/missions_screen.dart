import 'package:flutter/material.dart';
import '../../../core/theme/bmo_theme.dart';

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'MISSOES',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: BmoColors.accentGreen,
            ),
      ),
    );
  }
}
