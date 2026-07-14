import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_tab.dart';

class CurrentTab extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void setTab(AppTab tab) {
    state = tab;
  }
}

final currentTabProvider = NotifierProvider<CurrentTab, AppTab>(CurrentTab.new);
