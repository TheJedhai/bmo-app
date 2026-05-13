import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/missions_providers.dart';

sealed class MissionsView {
  const MissionsView();
}

class AllTasks extends MissionsView {
  const AllTasks();
}

class TodayTasks extends MissionsView {
  const TodayTasks();
}

class UrgentTasks extends MissionsView {
  const UrgentTasks();
}

class FolderView extends MissionsView {
  final int folderId;
  const FolderView(this.folderId);
}

class CurrentViewNotifier extends Notifier<MissionsView> {
  @override
  MissionsView build() => const AllTasks();

  void setView(MissionsView view) {
    state = view;
  }
}

final currentViewProvider =
    NotifierProvider<CurrentViewNotifier, MissionsView>(
  CurrentViewNotifier.new,
);

final currentViewLabelProvider = Provider<String>((ref) {
  final view = ref.watch(currentViewProvider);
  return switch (view) {
    AllTasks() => 'Todas',
    TodayTasks() => 'Hoje',
    UrgentTasks() => 'Urgentes',
    FolderView(:final folderId) =>
      ref.watch(foldersProvider).valueOrNull
              ?.where((f) => f.id == folderId)
              .firstOrNull
              ?.name ??
          'Pasta',
  };
});
