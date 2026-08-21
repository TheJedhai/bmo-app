import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/file_download.dart';
import '../../../core/platform/pdf_preview.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../crypto/vault_crypto.dart' as crypto;
import '../data/vault_client.dart';
import 'dart:typed_data';

import '../../../core/platform/file_stream_writer.dart';
import '../../../core/utils/file_mime.dart';
import '../data/vault_models.dart';
import '../crypto/vault_chunked_cipher.dart';
import '../providers/vault_providers.dart';
import 'viewers/vault_viewer_router.dart';

// ============================================================
// Screen root
// ============================================================

/// The Vault tab screen — switches between locked and unlocked views.
class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vaultSessionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BmoBackButton(),
        title: Text(
          'Cofre',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: session == null
          ? const _LockedVaultView()
          : _UnlockedVaultView(session: session),
    );
  }
}

// ============================================================
// Locked view — shows unlock form or "create first vault"
// ============================================================

class _LockedVaultView extends ConsumerStatefulWidget {
  const _LockedVaultView();

  @override
  ConsumerState<_LockedVaultView> createState() => _LockedVaultViewState();
}

class _LockedVaultViewState extends ConsumerState<_LockedVaultView> {
  /// Whether we've determined if vaults exist.
  bool _checkedForVaults = false;
  bool _hasVaults = false;
  bool _isChecking = false;

  /// Current mode: unlock vs create.
  bool _showCreateForm = false;

  @override
  void initState() {
    super.initState();
    _checkForVaults();
  }

  Future<void> _checkForVaults() async {
    setState(() => _isChecking = true);
    try {
      final repo = ref.read(vaultRepositoryProvider);
      final lookups = await repo.listUnlockMaterials();
      if (!mounted) return;
      setState(() {
        _hasVaults = lookups.isNotEmpty;
        _checkedForVaults = true;
        _isChecking = false;
      });
    } on NoVaultsException {
      if (!mounted) return;
      setState(() {
        _hasVaults = false;
        _checkedForVaults = true;
        _isChecking = false;
      });
    } on VaultApiException {
      // Server unreachable — show error state with retry.
      if (!mounted) return;
      setState(() {
        _checkedForVaults = true;
        _isChecking = false;
        _hasVaults = false;
        _showCreateForm = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Center(
        child: CircularProgressIndicator(color: BmoColors.accentGreen),
      );
    }

    if (!_checkedForVaults) {
      // Error checking — show retry.
      return _VaultErrorView(
        message: 'Não foi possível contactar o servidor.',
        onRetry: _checkForVaults,
      );
    }

    if (_showCreateForm || !_hasVaults) {
      return _CreateVaultView(
        showBackButton: _hasVaults,
        onBack: () => setState(() => _showCreateForm = false),
        onVaultCreated: () {
          // Session is set by the notifier — VaultScreen rebuilds
          // automatically via vaultSessionProvider.
        },
      );
    }

    return _UnlockView(
      onCreateTap: () => setState(() => _showCreateForm = true),
    );
  }
}

// ============================================================
// Unlock view — password
// ============================================================

class _UnlockView extends ConsumerStatefulWidget {
  final VoidCallback onCreateTap;

  const _UnlockView({required this.onCreateTap});

  @override
  ConsumerState<_UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends ConsumerState<_UnlockView> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final notifier = ref.read(vaultSessionProvider.notifier);

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await notifier.unlockWithPassword(_passwordController.text);
      // Success — VaultScreen rebuilds automatically.
    } on crypto.WrongPasswordException {
      setState(() => _errorMessage = 'Senha incorreta.');
    } on VaultApiException catch (e) {
      setState(() => _errorMessage = 'Erro do servidor (${e.statusCode}).');
    } on NoVaultsException {
      setState(() {
        _errorMessage = null;
        _isLoading = false;
      });
      widget.onCreateTap();
      return;
    } catch (e) {
      setState(() => _errorMessage = 'Erro inesperado. Tente novamente.');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 48,
          vertical: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Icon(
              Icons.lock_outline,
              size: isMobile ? 48 : 64,
              color: BmoColors.accentGreen,
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Cofre',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: isMobile ? 14 : 18,
                color: BmoColors.accentGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Entre com a senha para destravar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: isMobile ? 13 : 14,
                color: BmoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Input field
            _VaultTextField(
              controller: _passwordController,
              label: 'Senha',
              hint: 'Sua senha do cofre',
              obscureText: _obscurePassword,
              enabled: !_isLoading,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _unlock(),
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: BmoColors.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 8),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: BmoColors.accentYellow,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Unlock button
            SizedBox(
              width: isMobile ? double.infinity : 320,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _unlock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmoColors.accentGreen,
                  foregroundColor: BmoColors.screenBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BmoColors.screenBg,
                        ),
                      )
                    : Text(
                        'Destravar',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // "New vault" link
            TextButton(
              onPressed: _isLoading ? null : widget.onCreateTap,
              child: Text(
                'Novo cofre',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: BmoColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Create vault view
// ============================================================

/// Phases of the create-vault flow.
enum _CreatePhase {
  /// Fill in name + password.
  form,

  /// Creating vault (spinner).
  creating,
}

class _CreateVaultView extends ConsumerStatefulWidget {
  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onVaultCreated;

  const _CreateVaultView({
    required this.showBackButton,
    required this.onBack,
    required this.onVaultCreated,
  });

  @override
  ConsumerState<_CreateVaultView> createState() => _CreateVaultViewState();
}

class _CreateVaultViewState extends ConsumerState<_CreateVaultView> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  _CreatePhase _phase = _CreatePhase.form;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ---- Form validation ----

  String? _validateForm() {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty) return 'Dê um nome ao cofre.';
    if (password.isEmpty) return 'Escolha uma senha.';
    if (password.length < 4) return 'A senha deve ter pelo menos 4 caracteres.';
    if (password != confirm) return 'As senhas não conferem.';

    return null; // OK
  }

  // ---- Create vault ----

  Future<void> _createVault() async {
    final validationError = _validateForm();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _errorMessage = null;
      _phase = _CreatePhase.creating;
    });

    try {
      final notifier = ref.read(vaultSessionProvider.notifier);
      await notifier.createVault(
        _nameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      widget.onVaultCreated();
    } on DuplicatePasswordException {
      setState(() {
        _errorMessage =
            'Já existe um cofre com esta senha. Escolha uma senha diferente.';
        _phase = _CreatePhase.form;
      });
    } on VaultApiException catch (e) {
      setState(() {
        _errorMessage = 'Erro do servidor (${e.statusCode}).';
        _phase = _CreatePhase.form;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro inesperado ao criar o cofre.';
        _phase = _CreatePhase.form;
      });
    }
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 48,
          vertical: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Back button (if navigated from unlock screen)
            if (widget.showBackButton)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Voltar'),
                  style: TextButton.styleFrom(
                    foregroundColor: BmoColors.textSecondary,
                  ),
                ),
              ),

            if (_phase == _CreatePhase.form) ...[
              _buildForm(isMobile),
            ] else ...[
              // Creating phase
              const Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: BmoColors.accentGreen),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Icon(
          Icons.add_circle_outline,
          size: isMobile ? 48 : 64,
          color: BmoColors.accentGreen,
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          'Novo Cofre',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: isMobile ? 14 : 18,
            color: BmoColors.accentGreen,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Crie um cofre protegido por senha',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: isMobile ? 12 : 13,
            color: BmoColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Name field
        _VaultTextField(
          controller: _nameController,
          label: 'Nome do cofre',
          hint: 'Ex: Documentos, Fotos...',
          enabled: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        // Password field
        _VaultTextField(
          controller: _passwordController,
          label: 'Senha',
          hint: 'Escolha uma senha forte',
          obscureText: _obscurePassword,
          enabled: true,
          textInputAction: TextInputAction.next,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: BmoColors.textMuted,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm password field
        _VaultTextField(
          controller: _confirmController,
          label: 'Confirmar senha',
          hint: 'Digite a senha novamente',
          obscureText: _obscureConfirm,
          enabled: true,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _createVault(),
          suffix: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: BmoColors.textMuted,
            ),
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        const SizedBox(height: 8),

        // Error message
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.accentYellow,
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Create button
        SizedBox(
          width: isMobile ? double.infinity : 320,
          height: 48,
          child: ElevatedButton(
            onPressed: _createVault,
            style: ElevatedButton.styleFrom(
              backgroundColor: BmoColors.accentGreen,
              foregroundColor: BmoColors.screenBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Criar cofre',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Unlocked vault view — file management
// ============================================================

class _UnlockedVaultView extends ConsumerStatefulWidget {
  final VaultSession session;

  const _UnlockedVaultView({required this.session});

  @override
  ConsumerState<_UnlockedVaultView> createState() => _UnlockedVaultViewState();
}

class _UnlockedVaultViewState extends ConsumerState<_UnlockedVaultView> {
  /// Files above 25 MB use the streaming download path (File System Access API)
  /// instead of decryptAll + Blob URL, to avoid doubling memory.
  static const _kLargeFileThreshold = 25 * 1024 * 1024; // 25 MiB

  List<VaultItemDecrypted>? _items;
  bool _isLoading = true;
  String? _error;

  // Upload state
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _uploadFileName = '';
  int _uploadIndex = 0;
  int _uploadTotal = 0;

  // Download state
  String? _downloadingItemId;
  double _downloadProgress = 0;
  String _downloadFileName = '';

  // Multi-selection state
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  bool _batchBusy = false;

  // Batch download progress (index/total appended to the progress label)
  int _downloadBatchIndex = 0;
  int _downloadBatchTotal = 0;

  // PDF preview state (native only)
  //
  // Handle of the temp file behind the Quick Look sheet. The system closes
  // the sheet, not our code, so the file dies HERE — on this screen's
  // dispose (lock, leaving the tab). App killed with the sheet open: the
  // dispose never runs and the OS purges NSTemporaryDirectory instead.
  PdfPreview? _openPdfPreview;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _openPdfPreview?.dispose();
    super.dispose();
  }

  VaultSession get _session => widget.session;

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(vaultRepositoryProvider);
      final items = await repo.listItems(_session.vaultId, _session.dek);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _isLoading = false;
      });
    }
  }

  // ----------------------------------------------------------
  // Upload
  // ----------------------------------------------------------

  /// "Arquivo" — qualquer tipo, múltiplos, sem limite de tamanho.
  Future<void> _pickAndUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    // `null` means the user cancelled the picker.
    if (result == null || result.files.isEmpty) return;

    final failures = <String>[];
    final pending = <({Uint8List bytes, String fileName, String mimeType})>[];
    for (final file in result.files) {
      // On web and iOS, withData (default) populates `bytes` fully in memory.
      final bytes = file.bytes;
      if (bytes == null) {
        failures.add('${file.name}: não foi possível ler o arquivo.');
        continue;
      }
      pending.add((
        bytes: bytes,
        fileName: file.name,
        // Mime pelos bytes, não pela extensão (HEIC renomeado para .jpg
        // vinha do picker como image/jpeg e ficava salvo errado).
        mimeType: detectMimeType(bytes: bytes, fileName: file.name),
      ));
    }

    if (pending.isEmpty) {
      _showError('Falha no upload: ${failures.first}');
      return;
    }
    await _uploadFiles(pending, failures);
  }

  /// "Foto ou vídeo" — galeria (PHPicker no iOS, seletor filtrado na web).
  Future<void> _pickAndUploadMedia() async {
    final files = await ImagePicker().pickMultipleMedia();
    if (files.isEmpty) return;

    final failures = <String>[];
    final pending = <({Uint8List bytes, String fileName, String mimeType})>[];
    for (final file in files) {
      final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        failures.add('${file.name}: não foi possível ler o arquivo.');
        continue;
      }
      pending.add((
        bytes: bytes,
        fileName: file.name,
        // Mime pelos bytes, não pelo mimeType do picker nem pela extensão:
        // Blob.type e extensão são metadado editável (foto HEIC do app
        // Fotos chega como .jpg).
        mimeType: detectMimeType(bytes: bytes, fileName: file.name),
      ));
    }

    if (pending.isEmpty) {
      _showError('Falha no upload: ${failures.first}');
      return;
    }
    await _uploadFiles(pending, failures);
  }

  /// Fluxo único de upload — cifragem, thumbnail e envio iguais para
  /// qualquer origem; só os bytes mudam.
  Future<void> _uploadFiles(
    List<({Uint8List bytes, String fileName, String mimeType})> files,
    List<String> failures,
  ) async {
    if (!mounted) return;
    setState(() {
      _isUploading = true;
      _uploadTotal = files.length;
      _uploadIndex = 0;
    });

    final repo = ref.read(vaultRepositoryProvider);

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = file.fileName;

      if (!mounted) return;
      setState(() {
        _uploadIndex = i + 1;
        _uploadProgress = 0;
        _uploadFileName = fileName;
      });

      try {
        await repo.uploadItem(
          _session.vaultId,
          _session.dek,
          file.bytes,
          fileName,
          file.mimeType,
          onProgress: (sent, total) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = total > 0 ? sent / total : 0;
            });
          },
        );
      } catch (e) {
        failures.add('$fileName: ${_friendlyError(e)}');
      }
    }

    if (!mounted) return;
    setState(() {
      _isUploading = false;
      _uploadFileName = '';
      _uploadIndex = 0;
      _uploadTotal = 0;
    });

    await _loadItems();

    if (failures.isNotEmpty) {
      if (failures.length == 1) {
        _showError('Falha no upload: ${failures.first}');
      } else {
        final suffix = failures.take(3).join('\n');
        _showError(
          '${failures.length}/${files.length} arquivos falharam:\n$suffix',
        );
      }
    }
  }

  // ----------------------------------------------------------
  // Download
  // ----------------------------------------------------------

  /// Baixa um item pela rota de sempre — retorna null em sucesso ou a
  /// mensagem de erro. Os call sites de item único mostram a mensagem
  /// ([_downloadItemWithFeedback]); o lote acumula as falhas.
  Future<String?> _downloadItem(VaultItemDecrypted item) async {
    final isLarge = item.originalSize >= _kLargeFileThreshold;
    final canStream = isFileStreamSaveAvailable;

    if (isLarge && canStream) {
      return _downloadItemStreaming(item);
    } else if (isLarge && !canStream) {
      return 'Arquivo muito grande para este navegador.\n'
          'Use Chrome ou Brave para baixar arquivos grandes.';
    } else {
      return _downloadItemBlob(item);
    }
  }

  /// Item único: baixa e mostra o erro, se houver.
  Future<void> _downloadItemWithFeedback(VaultItemDecrypted item) async {
    final error = await _downloadItem(item);
    if (error != null && mounted) _showError(error);
  }

  /// Streaming download via fetchChunkRange + seam de escrita em arquivo.
  ///
  /// Fetches the 21-byte header, opens a save destination, then downloads
  /// and decrypts each chunk sequentially — writing each to disk
  /// immediately via [FileStreamWriter]. Never holds the full file in
  /// memory.
  ///
  /// [destinationDirectory] (lote no nativo): grava solto na pasta
  /// escolhida em vez de abrir o diálogo de destino. O escopo de segurança
  /// da pasta é do caller ([openBatchDownloadFolder] + finally close).
  ///
  /// Em erro/cancelamento o [FileStreamWriter.abort] descarta o parcial:
  /// web aborta o writable stream sem close() (o destino não materializa);
  /// nativo fecha o RandomAccessFile e apaga o arquivo — na pasta do
  /// usuário ou no temp, o parcial nunca sobrevive.
  ///
  /// Retorna null em sucesso (ou cancelamento do diálogo) e a mensagem de
  /// erro em falha — quem mostra é o caller.
  Future<String?> _downloadItemStreaming(
    VaultItemDecrypted item, {
    String? destinationDirectory,
  }) async {
    setState(() {
      _downloadingItemId = item.id;
      _downloadProgress = 0;
      _downloadFileName = item.fileName;
    });

    FileStreamWriter? writer;
    try {
      final repo = ref.read(vaultRepositoryProvider);

      // 1. Fetch the blob header (21 bytes) to get chunk parameters.
      final header = await repo.fetchItemHeader(
        _session.vaultId,
        item.id,
      );

      // 2. Parse header to know total chunk count.
      final (_, _, chunkSize, originalSize) =
          VaultChunkedCipher.parseHeader(header);
      final totalChunks =
          VaultChunkedCipher.totalChunks(originalSize, chunkSize);

      // 3. Open the save destination.
      writer = await openFileStreamWriter(
        item.fileName,
        destinationDirectory: destinationDirectory,
      );
      if (writer == null) {
        if (!mounted) return null;
        setState(() {
          _downloadingItemId = null;
          _downloadFileName = '';
        });
        if (destinationDirectory == null) {
          // User cancelled the save dialog — clean up without error.
          return null;
        }
        return 'Não foi possível criar o arquivo na pasta escolhida '
            '(já existe?).';
      }

      // 4. Fetch, decrypt, and write each chunk sequentially.
      for (var i = 0; i < totalChunks; i++) {
        if (!mounted) {
          // Screen closed mid-download: discard the partial file.
          await writer.abort();
          return null;
        }

        final (plaintext, statusCode, _) = await repo.fetchChunkRange(
          _session.vaultId,
          _session.dek,
          item.id,
          i,
          header,
        );

        if (statusCode != 206 && plaintext.isEmpty) {
          await writer.abort();
          if (!mounted) return null;
          setState(() {
            _downloadingItemId = null;
            _downloadFileName = '';
          });
          return 'Falha no download: servidor retornou status $statusCode.';
        }

        await writer.writeChunk(plaintext);

        if (mounted) {
          setState(() {
            _downloadProgress = (i + 1) / totalChunks;
          });
        }
      }

      // 5. Finalize the file.
      await writer.finalize();

      if (!mounted) return null;
      setState(() {
        _downloadingItemId = null;
        _downloadFileName = '';
      });
      return null;
    } catch (e) {
      // Abort descarta o parcial em qualquer ponto — no-op seguro depois
      // de finalize(), o catch não precisa saber até onde a gravação foi.
      await writer?.abort();
      if (!mounted) return null;
      setState(() {
        _downloadingItemId = null;
        _downloadFileName = '';
      });
      if (e is VaultApiException && e.statusCode == 410) {
        return 'Arquivo não encontrado no servidor. O blob foi removido.';
      }
      return 'Falha no download: ${_friendlyError(e)}';
    }
  }

  /// Small-file download via decryptAll + Blob URL.
  ///
  /// Suitable for files < 25 MB. For larger files the streaming path
  /// ([_downloadItemStreaming]) avoids double memory allocation.
  ///
  /// Retorna null em sucesso e a mensagem de erro em falha — quem mostra é
  /// o caller.
  Future<String?> _downloadItemBlob(VaultItemDecrypted item) async {
    setState(() {
      _downloadingItemId = item.id;
      _downloadProgress = 0;
      _downloadFileName = item.fileName;
    });

    try {
      final repo = ref.read(vaultRepositoryProvider);
      final plaintext = await repo.downloadItem(
        _session.vaultId,
        _session.dek,
        item.id,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = total > 0 ? received / total : 0;
          });
        },
      );
      if (!mounted) return null;

      // Save file via the platform download helper (file_saver).
      downloadBytes(
        bytes: plaintext,
        fileName: item.fileName,
        mimeType: item.mimeType,
      );

      setState(() {
        _downloadingItemId = null;
        _downloadFileName = '';
      });
      return null;
    } on VaultApiException catch (e) {
      if (!mounted) return null;
      setState(() {
        _downloadingItemId = null;
        _downloadFileName = '';
      });
      if (e.statusCode == 410) {
        return 'Arquivo não encontrado no servidor. O blob foi removido.';
      }
      return 'Falha no download: ${_friendlyError(e)}';
    } catch (e) {
      if (!mounted) return null;
      setState(() {
        _downloadingItemId = null;
        _downloadFileName = '';
      });
      return 'Falha no download: ${_friendlyError(e)}';
    }
  }

  // ----------------------------------------------------------
  // Delete item
  // ----------------------------------------------------------

  Future<void> _deleteItem(VaultItemDecrypted item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text('Deletar arquivo?',
            style: TextStyle(color: BmoColors.textPrimary, fontSize: 14)),
        content: Text(
          "Deletar '${item.fileName}'?\n"
          'O arquivo será removido permanentemente.',
          style:
              const TextStyle(color: BmoColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deletar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final repo = ref.read(vaultRepositoryProvider);
        await repo.deleteItem(_session.vaultId, item.id);
        await _loadItems();
      } catch (e) {
        if (!mounted) return;
        _showError('Falha ao deletar: ${_friendlyError(e)}');
      }
    }
  }

  // ----------------------------------------------------------
  // Multi-selection (batch download / delete)
  // ----------------------------------------------------------

  void _enterSelectionMode() {
    if (_items == null || _items!.isEmpty) return;
    setState(() => _selectionMode = true);
  }

  /// Sair SEMPRE limpa a seleção.
  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  /// Baixa a seleção inteira. A costura da composição vive no
  /// file_download.dart (zero kIsWeb/Platform.is aqui):
  ///
  /// - Só imagem/vídeo: cada item segue a rota individual de sempre
  ///   (galeria no iOS sem diálogo, downloads individuais na web).
  /// - Mistura: no nativo a pasta é escolhida UMA vez
  ///   ([openBatchDownloadFolder]) e os arquivos são gravados soltos nela
  ///   via streaming (sem zip); na web vira downloads individuais.
  ///
  /// Item que falha não interrompe o lote — o resumo no fim reporta
  /// quantos foram e quantos falharam.
  Future<void> _downloadSelected() async {
    final items = _items;
    if (items == null || _batchBusy) return;
    final selected =
        items.where((i) => _selectedIds.contains(i.id)).toList();
    if (selected.isEmpty) return;

    setState(() => _batchBusy = true);

    final allMedia = selected.every((i) =>
        i.mimeType.startsWith('image/') || i.mimeType.startsWith('video/'));

    final ({BatchFolderOpen choice, BatchDownloadFolder? folder}) open;
    if (allMedia) {
      open = (choice: BatchFolderOpen.individualDownloads, folder: null);
    } else {
      open = await openBatchDownloadFolder();
    }

    if (open.choice == BatchFolderOpen.cancelled) {
      // Usuário cancelou o picker (ou escopo negado) — nada acontece.
      if (mounted) setState(() => _batchBusy = false);
      return;
    }

    var saved = 0;
    final failures = <String>[];
    try {
      setState(() {
        _downloadBatchIndex = 0;
        _downloadBatchTotal = selected.length;
      });
      for (final item in selected) {
        if (!mounted) break;
        setState(() => _downloadBatchIndex++);
        final error = open.choice == BatchFolderOpen.folder
            ? await _downloadItemStreaming(
                item,
                destinationDirectory: open.folder!.path,
              )
            : await _downloadItem(item);
        if (error == null) {
          saved++;
        } else {
          failures.add('${item.fileName}: $error');
        }
      }
      setState(() {
        _downloadBatchIndex = 0;
        _downloadBatchTotal = 0;
      });
    } finally {
      // Todo caminho de saída — sucesso, falha parcial, tela fechada —
      // libera o escopo de segurança da pasta exatamente uma vez.
      await open.folder?.close();
      if (mounted) setState(() => _batchBusy = false);
    }

    if (failures.isNotEmpty && mounted) {
      final names = failures.take(3).join('\n');
      final more = failures.length > 3 ? '\n…' : '';
      _showError(
        '$saved/${selected.length} baixados. '
        '${failures.length} falharam:\n$names$more',
      );
    }
  }

  /// Apaga a seleção inteira — confirmação com contagem e destaque de
  /// perigo. Falha parcial não é silenciosa: o resumo diz quantos foram
  /// apagados e quantos falharam, e a lista é recarregada do servidor
  /// (consistente com o estado real).
  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    if (count == 0 || _batchBusy) return;

    final label = count == 1 ? '1 item' : '$count itens';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: BmoColors.accentYellow, size: 24),
            const SizedBox(width: 12),
            Text(
              'Apagar $label?',
              style: const TextStyle(
                  color: BmoColors.textPrimary, fontSize: 14),
            ),
          ],
        ),
        content: const Text(
          'Esta ação é irreversível.\n'
          'Os arquivos serão permanentemente apagados do cofre.',
          style: TextStyle(
            color: BmoColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Apagar $label'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _batchBusy = true);
    final repo = ref.read(vaultRepositoryProvider);
    var deleted = 0;
    var failed = 0;
    for (final id in _selectedIds.toList()) {
      try {
        await repo.deleteItem(_session.vaultId, id);
        deleted++;
      } catch (_) {
        failed++;
      }
    }

    // Lista consistente com o servidor — recarrega o que sobrou.
    await _loadItems();
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
      _batchBusy = false;
    });
    if (failed > 0) {
      _showError(
        '$deleted/$count apagados, $failed falharam. Tente novamente.',
      );
    }
  }

  // ----------------------------------------------------------
  // Open viewer
  // ----------------------------------------------------------

  void _openViewer(VaultItemDecrypted item) {
    openVaultItemViewer(
      context,
      item: item,
      session: _session,
      ref: ref,
      onDownload: () => _downloadItemWithFeedback(item),
      onPdfPreviewOpened: _onPdfPreviewOpened,
    );
  }

  /// Receives the temp-file handle once the Quick Look sheet is up.
  /// Reopening a preview replaces the previous one — no accumulation.
  void _onPdfPreviewOpened(PdfPreview preview) {
    _openPdfPreview?.dispose();
    _openPdfPreview = preview;
  }

  // ----------------------------------------------------------
  // Delete vault (with password confirmation)
  // ----------------------------------------------------------

  Future<void> _deleteVault() async {
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => _DeleteVaultDialog(),
    );

    if (password == null || password.isEmpty || !mounted) return;

    // Validate password locally — re-derive KEK and check canary.
    try {
      final repo = ref.read(vaultRepositoryProvider);
      final lookups = await repo.listUnlockMaterials();
      final lookup = lookups
          .where((l) => l.vaultId == _session.vaultId)
          .firstOrNull;

      if (lookup == null) {
        if (!mounted) return;
        _showError(
            'Não foi possível verificar a senha. Tente novamente.');
        return;
      }

      final canaryOk = await repo.testCanary(
        password: password,
        salt: lookup.material.salt,
        canaryIv: lookup.material.canaryIv,
        canaryCiphertext: lookup.material.canaryCiphertext,
      );

      if (!canaryOk) {
        if (!mounted) return;
        _showError('Senha incorreta.');
        return;
      }

      // Password confirmed — delete vault.
      await repo.deleteVault(_session.vaultId);

      if (!mounted) return;
      ref.read(vaultSessionProvider.notifier).lock();
      // Screen returns to locked view automatically via vaultSessionProvider.
    } catch (e) {
      if (!mounted) return;
      _showError('Falha ao deletar cofre: ${_friendlyError(e)}');
    }
  }

  // ----------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: BmoColors.screenBgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyError(Object e) {
    if (e is VaultApiException) {
      return 'Erro do servidor (${e.statusCode}).';
    }
    return e.toString();
  }

  // ----------------------------------------------------------
  // Build
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        // Header
        _VaultHeader(
          vaultName: _session.decryptedName,
          isMobile: isMobile,
          isUploading: _isUploading,
          hasItems: _items?.isNotEmpty ?? false,
          selectionMode: _selectionMode,
          selectedCount: _selectedIds.length,
          selectionBusy: _batchBusy,
          onAddMedia: _pickAndUploadMedia,
          onAddFile: _pickAndUploadFiles,
          onLock: () => ref.read(vaultSessionProvider.notifier).lock(),
          onDeleteVault: _deleteVault,
          onStartSelection: _enterSelectionMode,
          onCancelSelection: _exitSelectionMode,
          onDownloadSelected: _downloadSelected,
          onDeleteSelected: _deleteSelected,
        ),
        const Divider(color: BmoColors.textMuted, height: 1),

        // Upload progress bar
        if (_isUploading)
          _ProgressBar(
            progress: _uploadProgress,
            label: _uploadTotal > 1
                ? 'Enviando $_uploadIndex/$_uploadTotal — $_uploadFileName…'
                : 'Enviando $_uploadFileName…',
          ),

        // Download progress bar
        if (_downloadingItemId != null)
          _ProgressBar(
            progress: _downloadProgress,
            label: _downloadBatchTotal > 1
                ? 'Baixando $_downloadBatchIndex/$_downloadBatchTotal — '
                    '$_downloadFileName…'
                : 'Baixando $_downloadFileName…',
          ),

        // File list / states
        Expanded(child: _buildContent(isMobile)),
      ],
    );
  }

  Widget _buildContent(bool isMobile) {
    // Loading
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: BmoColors.accentGreen),
      );
    }

    // Error
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 32),
              const SizedBox(height: 8),
              const Text(
                'falha ao carregar',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: BmoColors.textMuted,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadItems,
                child: const Text('tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty
    if (_items == null || _items!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 48, color: BmoColors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'Nenhum arquivo ainda.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: BmoColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toque no + para adicionar.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: BmoColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // File list
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _items!.length,
      itemBuilder: (context, index) {
        final item = _items![index];
        final isDownloading = _downloadingItemId == item.id;
        return _VaultFileItem(
          item: item,
          isDownloading: isDownloading,
          downloadProgress: isDownloading ? _downloadProgress : null,
          selectionMode: _selectionMode,
          selected: _selectedIds.contains(item.id),
          onTap: () => _openViewer(item),
          onToggleSelection: () => _toggleSelection(item.id),
          onDownload: () => _downloadItemWithFeedback(item),
          onDelete: () => _deleteItem(item),
        );
      },
    );
  }
}

// ============================================================
// Vault header
// ============================================================

class _VaultHeader extends StatelessWidget {
  final String vaultName;
  final bool isMobile;
  final bool isUploading;
  final bool hasItems;
  final bool selectionMode;
  final int selectedCount;
  final bool selectionBusy;
  final VoidCallback onAddMedia;
  final VoidCallback onAddFile;
  final VoidCallback onLock;
  final VoidCallback onDeleteVault;
  final VoidCallback onStartSelection;
  final VoidCallback onCancelSelection;
  final VoidCallback onDownloadSelected;
  final VoidCallback onDeleteSelected;

  const _VaultHeader({
    required this.vaultName,
    required this.isMobile,
    required this.isUploading,
    required this.hasItems,
    required this.selectionMode,
    required this.selectedCount,
    required this.selectionBusy,
    required this.onAddMedia,
    required this.onAddFile,
    required this.onLock,
    required this.onDeleteVault,
    required this.onStartSelection,
    required this.onCancelSelection,
    required this.onDownloadSelected,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      child: selectionMode
          ? _buildSelectionBar()
          : _buildNormalBar(),
    );
  }

  /// Modo seleção: contador + Baixar/Apagar/Cancelar. Zero selecionados
  /// desabilita as ações.
  Widget _buildSelectionBar() {
    final countLabel = selectedCount == 1
        ? '1 selecionado'
        : '$selectedCount selecionados';
    final actionsEnabled = selectedCount > 0 && !selectionBusy;

    return Row(
      children: [
        TextButton.icon(
          onPressed: selectionBusy ? null : onCancelSelection,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancelar'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            countLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: BmoColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Baixar selecionados',
          onPressed: actionsEnabled ? onDownloadSelected : null,
          icon: const Icon(Icons.download_outlined,
              size: 20, color: BmoColors.textSecondary),
        ),
        IconButton(
          tooltip: 'Apagar selecionados',
          onPressed: actionsEnabled ? onDeleteSelected : null,
          icon: const Icon(Icons.delete_outline,
              size: 20, color: Colors.redAccent),
        ),
      ],
    );
  }

  Widget _buildNormalBar() {
    return Row(
      children: [
        // Vault icon + name
        Icon(Icons.lock_open_outlined,
            size: isMobile ? 20 : 24, color: BmoColors.accentGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            vaultName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: isMobile ? 12 : 14,
              color: BmoColors.accentGreen,
            ),
          ),
        ),

        // Select button — discoverable entry to multi-selection mode.
        TextButton.icon(
          onPressed: hasItems && !isUploading ? onStartSelection : null,
          icon: const Icon(Icons.checklist, size: 18),
          label: const Text('Selecionar',
              style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 4),

        // Add button — two obvious origins, one upload flow
        PopupMenuButton<_VaultAddAction>(
          tooltip: 'Adicionar ao cofre',
          enabled: !isUploading,
          padding: EdgeInsets.zero,
          color: BmoColors.screenBgElevated,
          onSelected: (action) {
            if (action == _VaultAddAction.media) {
              onAddMedia();
            } else {
              onAddFile();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _VaultAddAction.media,
              child: _VaultAddMenuItem(
                icon: Icons.photo_library_outlined,
                label: 'Foto ou vídeo',
              ),
            ),
            PopupMenuItem(
              value: _VaultAddAction.file,
              child: _VaultAddMenuItem(
                icon: Icons.insert_drive_file_outlined,
                label: 'Arquivo',
              ),
            ),
          ],
          icon: isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BmoColors.accentGreen,
                  ),
                )
              : const Icon(Icons.add, size: 20, color: BmoColors.textSecondary),
        ),
        const SizedBox(width: 4),

        // Lock button
        _HeaderIconButton(
          icon: Icons.lock_outline,
          tooltip: 'Travar cofre',
          onPressed: onLock,
        ),
        const SizedBox(width: 4),

        // More menu (delete vault)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert,
              size: 20, color: BmoColors.textMuted),
          color: BmoColors.screenBgElevated,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onSelected: (v) {
            if (v == 'delete') onDeleteVault();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'delete',
              child: Text('Deletar cofre…',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ],
    );
  }
}

enum _VaultAddAction { media, file }

class _VaultAddMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _VaultAddMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: BmoColors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: BmoColors.textSecondary),
        ),
      ),
    );
  }
}

// ============================================================
// File item row
// ============================================================

class _VaultFileItem extends StatelessWidget {
  final VaultItemDecrypted item;
  final bool isDownloading;
  final double? downloadProgress;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onToggleSelection;

  const _VaultFileItem({
    required this.item,
    required this.isDownloading,
    required this.downloadProgress,
    required this.selectionMode,
    required this.selected,
    required this.onDownload,
    required this.onDelete,
    required this.onTap,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // Tap target: in selection mode toggles the checkbox, otherwise
          // icon + text opens the viewer.
          Expanded(
            child: InkWell(
              onTap: selectionMode ? onToggleSelection : onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    // Thumbnail or icon
                    _ThumbnailWidget(
                      thumbnail: item.thumbnail,
                      mimeType: item.mimeType,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: BmoColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_formatSize(item.originalSize)} · ${_formatDate(item.createdAt)}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: BmoColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Selection checkbox replaces the item menu
          if (selectionMode)
            Checkbox(
              value: selected,
              onChanged: (_) => onToggleSelection(),
              fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? BmoColors.accentGreen
                    : null,
              ),
              checkColor: BmoColors.screenBg,
            )
          // Download progress indicator (or menu)
          else if (isDownloading)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BmoColors.accentGreen,
                  value: downloadProgress,
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 18, color: BmoColors.textMuted),
              color: BmoColors.screenBgElevated,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              onSelected: (v) {
                switch (v) {
                  case 'download':
                    onDownload();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'download',
                  child: Text('Baixar'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Deletar'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ---- helpers (free functions would be cleaner but matching codebase pattern) ----

  static IconData _iconForMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType.startsWith('video/')) return Icons.movie_outlined;
    if (mimeType.startsWith('audio/')) return Icons.audio_file_outlined;
    if (mimeType.startsWith('text/')) return Icons.description_outlined;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('zip') ||
        mimeType.contains('rar') ||
        mimeType.contains('tar') ||
        mimeType.contains('gzip') ||
        mimeType.contains('7z')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inHours < 1) return '${diff.inMinutes}min';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

// ============================================================
// Thumbnail widget
// ============================================================

class _ThumbnailWidget extends StatelessWidget {
  final Uint8List? thumbnail;
  final String mimeType;

  const _ThumbnailWidget({required this.thumbnail, required this.mimeType});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      _VaultFileItem._iconForMimeType(mimeType),
      size: 24,
      color: BmoColors.textMuted,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 40,
        height: 40,
        child: thumbnail != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    thumbnail!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Container(
                      color: BmoColors.screenBgElevated,
                      child: Center(child: icon),
                    ),
                  ),
                  if (mimeType.startsWith('video/'))
                    Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                ],
              )
            : Container(
                color: BmoColors.screenBgElevated,
                child: Center(child: icon),
              ),
      ),
    );
  }
}

// ============================================================
// Progress bar
// ============================================================

class _ProgressBar extends StatelessWidget {
  final double progress;
  final String label;

  const _ProgressBar({required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: BmoColors.screenBgElevated,
        border: const Border(
          bottom: BorderSide(color: BmoColors.textMuted, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: BmoColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: BmoColors.textMuted.withValues(alpha: 0.2),
              color: BmoColors.accentGreen,
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: BmoColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Delete vault dialog (password confirmation)
// ============================================================

class _DeleteVaultDialog extends StatefulWidget {
  @override
  State<_DeleteVaultDialog> createState() => _DeleteVaultDialogState();
}

class _DeleteVaultDialogState extends State<_DeleteVaultDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BmoColors.screenBgElevated,
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: BmoColors.accentYellow, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Deletar cofre?',
            style: TextStyle(color: BmoColors.textPrimary, fontSize: 14),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esta ação é irreversível.\n'
            'Todos os arquivos do cofre serão\n'
            'permanentemente apagados.',
            style: TextStyle(
              color: BmoColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) =>
                Navigator.of(context).pop(_passwordController.text),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: BmoColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Senha',
              hintText: 'Digite a senha do cofre para confirmar',
              hintStyle:
                  const TextStyle(fontSize: 13, color: BmoColors.textMuted),
              labelStyle:
                  const TextStyle(fontSize: 13, color: BmoColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: BmoColors.textMuted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              filled: true,
              fillColor: BmoColors.screenBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: BmoColors.textMuted.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: BmoColors.accentYellow),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () =>
              Navigator.of(context).pop(_passwordController.text),
          child: const Text('Deletar cofre'),
        ),
      ],
    );
  }
}

// ============================================================
// Shared widgets
// ============================================================

/// Styled text field for vault forms.
///
/// Uses **Inter** (NOT PressStart2P) for readability in form fields.
class _VaultTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _VaultTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: BmoColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: BmoColors.textMuted,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: BmoColors.textSecondary,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: BmoColors.screenBgElevated,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: BmoColors.textMuted.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BmoColors.accentGreen),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: BmoColors.textMuted.withValues(alpha: 0.2)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

/// Error view with message and retry button.
class _VaultErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _VaultErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: BmoColors.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: BmoColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
