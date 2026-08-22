/// No nativo (iOS) o `PlatformFile.path` aponta para a cópia em cache do
/// arquivo — o ORIGINAL acessível. Com `withData: false` o plugin não lê os
/// bytes (sem teto de memória) e o upload streama desse path, pela mesmíssima
/// costura do botão "Foto ou vídeo" ([openFileRangeReader]).
///
/// Não usar `kIsWeb`/`Platform.is`: a escolha é feita pela compilação
/// condicional deste seam, não no código do app.
const bool filePickerWithData = false;
