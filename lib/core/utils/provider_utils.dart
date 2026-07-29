import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Invalida todas as instâncias ativas de um provider `.family`.
///
/// Diferente de [Ref.invalidate] chamado diretamente na família — que pode não
/// forçar o rebuild de todas as instâncias vivas, especialmente com
/// `keepAlive: true` em [IndexedStack].
///
/// Percorre [ProviderContainer.getAllProviderElements] e invalida cada
/// instância cujo `origin.from` seja a família recebida, garantindo refetch
/// do backend em todos os widgets que a consomem.
void invalidateAllFamilyInstances(Ref ref, Object family) {
  for (final element in ref.container.getAllProviderElements()) {
    if (element.origin.from == family) {
      ref.invalidate(element.origin);
    }
  }
}
