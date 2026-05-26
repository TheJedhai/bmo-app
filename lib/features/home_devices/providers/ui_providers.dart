import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeViewMode { lista, planta }

final viewModeProvider = StateProvider<HomeViewMode>((ref) => HomeViewMode.lista);

final editModeProvider = StateProvider<bool>((ref) => false);
