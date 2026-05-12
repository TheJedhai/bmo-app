import 'package:flutter/material.dart';
import '../../../core/theme/bmo_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'HOME',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: BmoColors.accentGreen,
            ),
      ),
    );
  }
}
