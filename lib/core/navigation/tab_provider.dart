import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_tab.dart';

/// Provider usado pelo [BmoDock] para destacar o item ativo.
///
/// Após a migração para pushFeature, a troca de aba foi removida —
/// este provider existe apenas para o dock saber qual item destacar.
/// O estado default é [AppTab.home] (Dashboard é a raiz).
class CurrentTab extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;
}

final currentTabProvider = NotifierProvider<CurrentTab, AppTab>(CurrentTab.new);
