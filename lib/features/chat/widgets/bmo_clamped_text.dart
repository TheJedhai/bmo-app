import 'package:flutter/material.dart';

import '../../../core/theme/bmo_theme.dart';

/// Texto variável de card rico (erro, prompt, status): no máximo [maxLines]
/// linhas, com reticências, para nunca estourar o card. Tocar abre o texto
/// completo num diálogo selecionável.
class BmoClampedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  const BmoClampedText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 3,
    this.textAlign,
  });

  void _openFull(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: style ?? const TextStyle(
                color: BmoColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFull(context),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}
