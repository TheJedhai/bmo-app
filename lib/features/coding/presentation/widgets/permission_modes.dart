import 'package:flutter/material.dart';

import '../../../../core/theme/bmo_theme.dart';

/// Um `permission_mode` do Claude Code, com explicação curta para a UI.
class PermissionModeInfo {
  final String value;
  final String label;
  final String description;

  const PermissionModeInfo(this.value, this.label, this.description);
}

/// Modos válidos no servidor. Valores legados (`default`, `allow_all`,
/// `deny_all`) ainda podem aparecer em projetos antigos — a UI mostra o
/// valor cru nesse caso em vez de mentir.
/// Comportamento abaixo é o do run real: não é interativo, nada é perguntado
/// no meio da execução — o que não é permitido é negado.
const kPermissionModes = <PermissionModeInfo>[
  PermissionModeInfo(
    'manual',
    'Manual',
    'Só o que estiver em allow roda; todo o resto é negado.',
  ),
  PermissionModeInfo(
    'acceptEdits',
    'Aceitar edições',
    'Edita arquivos sozinho; Bash e o resto só se estiverem em allow — o '
        'que não estiver é negado.',
  ),
  PermissionModeInfo(
    'plan',
    'Planejar',
    'Comportamento não verificado no servidor.',
  ),
  PermissionModeInfo(
    'auto',
    'Automático',
    'Comportamento não verificado no servidor.',
  ),
  PermissionModeInfo(
    'dontAsk',
    'Não perguntar',
    'Só o que estiver em allow roda; todo o resto é negado.',
  ),
  PermissionModeInfo(
    'bypassPermissions',
    'Sem permissões',
    'Tudo liberado, exceto o que estiver em deny — deny bloqueia sem aviso.',
  ),
];

PermissionModeInfo? permissionModeInfo(String value) {
  for (final mode in kPermissionModes) {
    if (mode.value == value) return mode;
  }
  return null;
}

/// Rótulo curto de um modo (valor cru quando desconhecido/legado).
String permissionModeLabel(String value) =>
    permissionModeInfo(value)?.label ?? value;

/// Seletor de `permission_mode` com a explicação do modo escolhido.
class PermissionModeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const PermissionModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final legacy = permissionModeInfo(value) == null;
    final info = permissionModeInfo(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: BmoColors.screenBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          dropdownColor: BmoColors.screenBgElevated,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: BmoColors.textPrimary,
          ),
          items: [
            for (final mode in kPermissionModes)
              DropdownMenuItem(value: mode.value, child: Text(mode.label)),
            // Projeto antigo com valor que saiu do contrato: mostra o cru.
            if (legacy)
              DropdownMenuItem(value: value, child: Text('$value (legado)')),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
        const SizedBox(height: 4),
        Text(
          info?.description ??
              'Modo fora do contrato atual; troque para um dos listados.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: BmoColors.textMuted,
          ),
        ),
      ],
    );
  }
}
