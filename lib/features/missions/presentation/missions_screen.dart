import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bmo_theme.dart';
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: isMobile
          ? Drawer(
              backgroundColor: BmoColors.screenBg,
              child: FoldersSidebar(
                onItemTap: () => context.pop(),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          'Missões',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: isMobile
            ? [
                IconButton(
                  icon: const Icon(Icons.menu),
                  color: BmoColors.textPrimary,
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ]
            : null,
      ),
      body: isMobile
          ? const TasksList()
          : const _DesktopLayout(),
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout();

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

