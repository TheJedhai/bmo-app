import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BmoApp extends ConsumerWidget {
  const BmoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BMO',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(child: Text('BMO — em construção')),
      ),
    );
  }
}
