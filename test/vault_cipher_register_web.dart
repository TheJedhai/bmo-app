// Chrome: troca o dispatch de criptografia para DartAesGcm puro, que
// roda em microtasks — determinístico dentro do FakeAsync do testWidgets.
// Precisa rodar antes do primeiro uso de VaultCipher (o static final
// _aesGcm é lazy).
// ignore_for_file: implementation_imports
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/src/dart/cryptography.dart';

void registerVaultCipherForWebTests() {
  Cryptography.instance = DartCryptography.defaultInstance;
}
