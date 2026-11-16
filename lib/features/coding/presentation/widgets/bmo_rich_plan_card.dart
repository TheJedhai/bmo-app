import 'package:flutter/material.dart';

import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/features/coding/data/models/coding_project.dart';
import 'package:bmo_app/features/coding/presentation/widgets/coding_plan_look.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';
import 'package:bmo_app/features/rich_blocks/widgets/bmo_clamped_text.dart';

/// Card do bloco rico `coding_plan` (plano com orçamento).
///
/// Payload = `plan_payload` do servidor:
/// `{id, project_id, text, max_runs, max_cost_usd, runs_used, cost_used,
/// remaining_runs, status, created_at, ended_at}`. O mesmo card serve para o
/// plano aprovado (`active`) e para o cancelado (`cancelled`, emitido por
/// `cancel_coding_plan`).
class BmoRichPlanCard extends StatelessWidget {
  final BmoRichBlock block;

  const BmoRichPlanCard({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = CodingPlan.fromJson(block.payload);
    final look = planStatusLook(plan.status);
    final runs = plan.maxRuns == null
        ? '${plan.runsUsed} (sem limite)'
        : '${plan.runsUsed} / ${plan.maxRuns}';
    final cost = plan.maxCostUsd == null
        ? formatMoney(plan.costUsed)
        : '${formatMoney(plan.costUsed)} / ${formatMoney(plan.maxCostUsd!)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BmoColors.screenBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: look.color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.route_outlined, size: 16, color: look.color),
                const SizedBox(width: 8),
                Text(
                  'Plano · ${look.label}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: look.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (plan.maxRuns != null && plan.status == 'active')
                  Text(
                    'restam ${plan.runsLeft}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: BmoColors.textMuted),
                  ),
              ],
            ),
            if (plan.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              BmoClampedText(
                plan.text,
                maxLines: 4,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: BmoColors.textPrimary),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Meta(icon: Icons.playlist_play, text: 'runs $runs'),
                _Meta(icon: Icons.payments_outlined, text: 'custo $cost'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: BmoColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: BmoColors.textSecondary),
        ),
      ],
    );
  }
}
