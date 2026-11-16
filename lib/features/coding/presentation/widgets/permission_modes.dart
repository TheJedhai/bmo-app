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
const kPermissionModes = <PermissionModeInfo>[
  PermissionModeInfo(
    'manual',
    'Manual',
    'Pede aprovação para cada ação do agente.',
  ),
  PermissionModeInfo(
    'acceptEdits',
    'Aceitar edições',
    'Edita arquivos sozinho; pede aprovação para o resto.',
  ),
  PermissionModeInfo(
    'plan',
    'Planejar',
    'Só lê e monta um plano; não altera nada.',
  ),
  PermissionModeInfo(
    'auto',
    'Automático',
    'Decide sozinho o que é seguro e pergunta no resto.',
  ),
  PermissionModeInfo(
    'dontAsk',
    'Não perguntar',
    'Segue em frente sem perguntar; nega o que as regras barram.',
  ),
  PermissionModeInfo(
    'bypassPermissions',
    'Sem permissões',
    'Não faz nenhuma checagem de permissão. Use com cuidado.',
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
