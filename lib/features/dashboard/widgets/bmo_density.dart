import 'package:flutter/widgets.dart';

/// Densidade visual dos cards da dashboard.
///
/// Compact (mobile): menos padding, número de destaque menor, cantoneiras
/// mais curtas e menos linhas nas listas — para os títulos caberem nas
/// colunas estreitas do grid de 2. Regular (desktop) é o default quando
/// não há [BmoDensity] na árvore.
enum BmoDensityMode {
  regular(
    contentPadding: 16,
    highlightFontSize: 34,
    cornerStrokeLength: 18,
  ),
  compact(
    contentPadding: 12,
    highlightFontSize: 24,
    cornerStrokeLength: 14,
  );

  const BmoDensityMode({
    required this.contentPadding,
    required this.highlightFontSize,
    required this.cornerStrokeLength,
  });

  final double contentPadding;
  final double highlightFontSize;
  final double cornerStrokeLength;

  bool get isCompact => this == BmoDensityMode.compact;
}

/// Expõe [BmoDensityMode] para [DashCard] e os cards de conteúdo, sem
/// cascata de isMobile por construtor.
class BmoDensity extends InheritedWidget {
  const BmoDensity({super.key, required this.mode, required super.child});

  final BmoDensityMode mode;

  static BmoDensityMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BmoDensity>()?.mode ??
      BmoDensityMode.regular;

  @override
  bool updateShouldNotify(BmoDensity oldWidget) => mode != oldWidget.mode;
}
