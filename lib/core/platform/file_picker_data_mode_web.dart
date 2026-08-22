/// Na web o `file_picker` não expõe o arquivo ORIGINAL: `withData: false`
/// deixa `bytes` null, `PlatformFile.path` lançando e `result.xFiles`
/// quebrando (`XFile.fromData(null!)`). Sem original não há como streamar
/// (a costura de faixa lê de um blob/URL), então pedimos os bytes
/// materializados e ficamos na rota em memória — nenhum ganho é possível.
///
/// Não usar `kIsWeb`/`Platform.is`: a escolha é feita pela compilação
/// condicional deste seam, não no código do app.
const bool filePickerWithData = true;
