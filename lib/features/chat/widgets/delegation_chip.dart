import 'package:flutter/material.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/chat_message.dart';

/// Chip que mostra o estado de uma delegação ao executor externo
/// (delegate_external_agent) na timeline do chat.
class DelegationChip extends StatelessWidget {
  final DelegationEvent delegation;

  const DelegationChip({super.key, required this.delegation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _borderColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(theme),
          if (delegation.report != null && delegation.report!.isNotEmpty)
            _buildReport(theme),
          if (delegation.error != null && delegation.error!.isNotEmpty)
            _buildError(theme),
        ],
      ),
    );
  }

  Color get _borderColor {
    return switch (delegation.status) {
      DelegationStatus.running => BmoColors.accentYellow,
      DelegationStatus.waitingPermission => BmoColors.accentYellow,
      DelegationStatus.completed => BmoColors.accentGreen,
      DelegationStatus.error => Colors.redAccent,
    };
  }

  Widget _buildHeader(ThemeData theme) {
    final icon = switch (delegation.status) {
      DelegationStatus.running => Icons.terminal_rounded,
      DelegationStatus.waitingPermission => Icons.lock_outline_rounded,
      DelegationStatus.completed => Icons.check_circle_outline_rounded,
      DelegationStatus.error => Icons.error_outline_rounded,
    };

    final label = switch (delegation.status) {
      DelegationStatus.running => 'executando',
      DelegationStatus.waitingPermission => 'aguardando permissão',
      DelegationStatus.completed => 'concluído',
      DelegationStatus.error => 'erro',
    };

    final info = <String>[];
    if (delegation.runner != null && delegation.runner!.isNotEmpty) {
      info.add(delegation.runner!);
    }
    if (delegation.cwd != null && delegation.cwd!.isNotEmpty) {
      info.add(delegation.cwd!);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          _StatusIcon(
            icon: icon,
            color: _borderColor,
            status: delegation.status,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Delegação · $label',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _borderColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (info.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      info.join('  ·  '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BmoColors.textSecondary,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: BmoColors.screenBgElevated,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          delegation.report!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: BmoColors.textPrimary,
            height: 1.5,
          ),
          maxLines: 20,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Text(
        delegation.error!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.redAccent,
          fontFamily: 'monospace',
          fontSize: 11,
        ),
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Ícone de status com spinner para estado running.
class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final DelegationStatus status;

  const _StatusIcon({
    required this.icon,
    required this.color,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    if (status == DelegationStatus.running) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color,
        ),
      );
    }

    return Icon(icon, size: 20, color: color);
  }
}
