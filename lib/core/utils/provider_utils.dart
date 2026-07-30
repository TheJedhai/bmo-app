import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Invalida todas as instâncias ativas de um provider `.family`.
///
/// Diferente de [ProviderContainer.invalidate] chamado diretamente na família —
/// que pode não forçar o rebuild de todas as instâncias vivas, especialmente com
/// `keepAlive: true` em [IndexedStack].
///
/// Percorre [ProviderContainer.getAllProviderElements] e invalida cada
/// instância cujo `origin.from` seja a família recebida, garantindo refetch
/// do backend em todos os widgets que a consomem.
void invalidateAllFamilyInstances(ProviderContainer container, Object family) {
  int total = 0;
  int matched = 0;
  for (final element in container.getAllProviderElements()) {
    total++;
    if (element.origin.from == family) {
      matched++;
      container.invalidate(element.origin);
    }
  }
  debugPrint('[invalidateAllFamilyInstances] family=${family.runtimeType} '
      'total=$total matched=$matched');
}
