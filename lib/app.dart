import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/bmo_theme.dart';
import 'core/widgets/bmo_frame.dart';
import 'features/chat/chat_screen.dart';

class BmoApp extends ConsumerWidget {
  const BmoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BMO',
      debugShowCheckedModeBanner: false,
      theme: BmoTheme.themeData,
      home: const Scaffold(
        body: BmoFrame(
          child: ChatScreen(),
        ),
      ),
    );
  }
}
