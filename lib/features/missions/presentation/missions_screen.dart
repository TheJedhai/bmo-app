import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import 'selected_view_provider.dart';
import 'widgets/folders_sidebar.dart';
import 'widgets/tasks_list.dart';

const _kMobileBreakpoint = 600.0;
const _kSidebarWidth = 260.0;

class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < _kMobileBreakpoint;

    if (isMobile) {
      return _MobileLayout(
        scaffoldKey: _scaffoldKey,
      );
    }
    return _DesktopLayout();
  }
}

class _DesktopLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          width: _kSidebarWidth,
          child: FoldersSidebar(),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: BmoColors.textMuted.withValues(alpha: 0.2),
        ),
        const Expanded(
          child: TasksList(),
        ),
      ],
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const _MobileLayout({required this.scaffoldKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = ref.watch(currentViewLabelProvider);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        backgroundColor: BmoColors.screenBg,
        child: FoldersSidebar(
          onItemTap: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            color: BmoColors.textPrimary,
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: BmoColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: const TasksList(),
    );
  }
}
