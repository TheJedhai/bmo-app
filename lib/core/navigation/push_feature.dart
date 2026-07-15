import 'package:flutter/material.dart';

/// Empurra [screen] como uma rota full-screen com transição fade.
///
/// Centraliza a definição da transição para que futuras trocas (ex: slide,
/// zoom) sejam feitas em um único ponto, sem tocar nos call sites.
///
/// Exemplo:
/// ```dart
/// await pushFeature(context, const ChatScreen());
/// ```
Future<T?> pushFeature<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 200),
    ),
  );
}
