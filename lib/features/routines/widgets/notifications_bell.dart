import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/dark_circle.dart';
import '../data/routines_client.dart';
import '../providers/routines_providers.dart';

/// Sino de notificações no topo. Badge = `unread` do `GET /notifications`;
/// as seguradas aparecem destacadas no diálogo.
class NotificationsBell extends ConsumerWidget {
  final double size;
  final double iconSize;

  const NotificationsBell({super.key, this.size = 48, this.iconSize = 24});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(notificationsProvider).valueOrNull;
    final items = page?.items ?? const <AppNotification>[];
    final unread = page?.unread ?? 0;
    final held = items.where((item) => item.held).length;
    final badgeScale = size / 48;

    return Tooltip(
      message: unread > 0 ? '$unread avisos' : 'avisos',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showNotificationsDialog(context),
          borderRadius: BorderRadius.circular(size / 2),
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                DarkCircle(
                  diameter: size,
                  child: Icon(
                    Icons.notifications_outlined,
                    size: iconSize,
                    color: unread > 0 || held > 0
                        ? BmoColors.accentYellow
                        : BmoColors.accentGreen,
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: -2 * badgeScale,
                    right: -2 * badgeScale,
                    child: Container(
                      constraints: BoxConstraints(minWidth: 15 * badgeScale),
                      height: 15 * badgeScale,
                      padding: EdgeInsets.symmetric(horizontal: 3 * badgeScale),
                      decoration: BoxDecoration(
                        color: BmoColors.accentRed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9 * badgeScale,
                          fontWeight: FontWeight.w700,
                          color: BmoColors.textPrimary,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recentes e seguradas. Seguradas vêm primeiro, destacadas.
Future<void> showNotificationsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _NotificationsDialog(),
  );
}

class _NotificationsDialog extends ConsumerStatefulWidget {
  const _NotificationsDialog();

  @override
  ConsumerState<_NotificationsDialog> createState() =>
      _NotificationsDialogState();
}

class _NotificationsDialogState extends ConsumerState<_NotificationsDialog> {
  /// Marca as exibidas como lidas uma vez por abertura.
  bool _marked = false;

  @override
  void initState() {
    super.initState();
    // Abrir é o "foco" da tela: relê do servidor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationsProvider.notifier).refresh();
    });
  }

  void _markDisplayed(List<AppNotification> items) {
    if (_marked) return;
    final ids = [
      for (final item in items)
        if (item.readAt == null) item.id,
    ];
    if (ids.isEmpty) return;
    _marked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationsProvider.notifier).markRead(ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(notificationsProvider);

    return AlertDialog(
      backgroundColor: BmoColors.screenBgElevated,
      title: const Text('Avisos'),
      content: SizedBox(
        width: 420,
        child: async.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(color: BmoColors.accentGreen),
            ),
          ),
          error: (error, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'falha ao carregar: $error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: BmoColors.accentRed,
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(notificationsProvider.notifier).refresh(),
                child: const Text('tentar de novo'),
              ),
            ],
          ),
          data: (page) {
            final items = page.items;
            _markDisplayed(items);
            if (items.isEmpty) {
              return Text(
                'nada por aqui',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: BmoColors.textMuted,
                ),
              );
            }
            final held = items.where((item) => item.held).toList();
            final recent = items.where((item) => !item.held).toList();
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (held.isNotEmpty) ...[
                    _SectionLabel('Seguradas'),
                    for (final item in held)
                      _NotificationTile(item: item, highlighted: true),
                  ],
                  if (recent.isNotEmpty) ...[
                    if (held.isNotEmpty) const SizedBox(height: 8),
                    _SectionLabel('Recentes'),
                    for (final item in recent)
                      _NotificationTile(item: item, highlighted: false),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: BmoColors.textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final bool highlighted;

  const _NotificationTile({required this.item, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = item.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlighted
            ? BmoColors.accentYellow.withValues(alpha: 0.08)
            : BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted
              ? BmoColors.accentYellow.withValues(alpha: 0.5)
              : BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: BmoColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (when != null)
                Text(
                  DateFormat('dd/MM HH:mm').format(when.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BmoColors.textMuted,
                  ),
                ),
            ],
          ),
          if (item.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            [
              item.level,
              if (item.channel != null) item.channel!,
              item.source,
            ].where((part) => part.isNotEmpty).join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: BmoColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
