// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../crypto/vault_crypto.dart' as crypto;
import '../data/vault_client.dart';
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import '../data/vault_models.dart';
import '../data/vault_file_save.dart';
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

    if (session == null) {
      return const _LockedVaultView();
    }

    return _UnlockedVaultView(session: session);
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
// Unlock view — password or recovery key
// ============================================================

class _UnlockView extends ConsumerStatefulWidget {
  final VoidCallback onCreateTap;

  const _UnlockView({required this.onCreateTap});

  @override
  ConsumerState<_UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends ConsumerState<_UnlockView> {
  final _passwordController = TextEditingController();
  final _recoveryController = TextEditingController();
  bool _obscurePassword = true;
  bool _useRecoveryKey = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final notifier = ref.read(vaultSessionProvider.notifier);

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      if (_useRecoveryKey) {
        await notifier.unlockWithRecoveryKey(_recoveryController.text.trim());
      } else {
        await notifier.unlockWithPassword(_passwordController.text);
      }
      // Success — VaultScreen rebuilds automatically.
    } on crypto.WrongPasswordException {
      setState(() => _errorMessage = 'Senha incorreta.');
    } on WrongRecoveryKeyException {
      setState(() => _errorMessage = 'Chave de recuperação inválida.');
    } on FormatException {
      setState(() =>
          _errorMessage = 'Formato inválido. A chave deve ter 64 caracteres hexadecimais.');
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

            // Toggle: password vs recovery key
            _UnlockModeToggle(
              useRecoveryKey: _useRecoveryKey,
              onChanged: (v) => setState(() {
                _useRecoveryKey = v;
                _errorMessage = null;
              }),
            ),
            const SizedBox(height: 20),

            // Input field
            if (_useRecoveryKey)
              _VaultTextField(
                controller: _recoveryController,
                label: 'Chave de recuperação (64 hex)',
                hint: 'abcd1234...',
                enabled: !_isLoading,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _unlock(),
              )
            else
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

  /// Show recovery key once, ask for confirmation redigitation.
  showRecoveryKey,

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
  final _recoveryConfirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  _CreatePhase _phase = _CreatePhase.form;
  String? _errorMessage;
  String? _recoveryKeyDisplay; // Held ONLY during showRecoveryKey phase.

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _recoveryConfirmController.dispose();
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
      final recoveryKeyHex = await notifier.createVault(
        _nameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      setState(() {
        _recoveryKeyDisplay = recoveryKeyHex;
        _phase = _CreatePhase.showRecoveryKey;
      });
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

  // ---- Recovery key confirmation ----

  Future<void> _confirmRecoveryKey() async {
    final entered = _recoveryConfirmController.text.trim();
    if (entered.isEmpty) {
      setState(() =>
          _errorMessage = 'Digite a chave de recuperação para confirmar.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _phase = _CreatePhase.creating;
    });

    try {
      final notifier = ref.read(vaultSessionProvider.notifier);
      final ok = await notifier.verifyRecoveryKey(entered);

      if (!mounted) return;

      if (ok) {
        // Vault is already created and unlocked — just clear the recovery key
        // from memory and signal completion.
        _recoveryKeyDisplay = null;
        widget.onVaultCreated();
      } else {
        setState(() {
          _errorMessage =
              'A chave digitada não confere. Confira e tente novamente.';
          _phase = _CreatePhase.showRecoveryKey;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao verificar a chave. Tente novamente.';
        _phase = _CreatePhase.showRecoveryKey;
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
            ] else if (_phase == _CreatePhase.showRecoveryKey) ...[
              _buildRecoveryKeyConfirmation(isMobile),
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
          'Crie um cofre protegido por senha\ne guarde a chave de recuperação',
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

  Widget _buildRecoveryKeyConfirmation(bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Warning icon
        Icon(
          Icons.warning_amber_rounded,
          size: isMobile ? 48 : 64,
          color: BmoColors.accentYellow,
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          'Guarde sua chave',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: isMobile ? 12 : 14,
            color: BmoColors.accentYellow,
          ),
        ),
        const SizedBox(height: 12),

        // Warning text
        Text(
          'Esta é a ÚNICA forma de recuperar seu cofre\n'
          'se você esquecer a senha. Copie e guarde\n'
          'em um local seguro agora.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: isMobile ? 12 : 13,
            color: BmoColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),

        // Recovery key display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BmoColors.screenBgElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BmoColors.accentYellow.withValues(alpha: 0.3)),
          ),
          child: SelectableText(
            _recoveryKeyDisplay ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: isMobile ? 11 : 13,
              color: BmoColors.textPrimary,
              letterSpacing: 1.2,
              wordSpacing: 4,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Confirmation field
        Text(
          'Digite a chave abaixo para confirmar que a guardou:',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: isMobile ? 12 : 13,
            color: BmoColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _VaultTextField(
          controller: _recoveryConfirmController,
          label: 'Chave de recuperação',
          hint: 'Cole ou digite a chave de 64 caracteres',
          enabled: true,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _confirmRecoveryKey(),
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

        // Confirm button
        SizedBox(
          width: isMobile ? double.infinity : 320,
          height: 48,
          child: ElevatedButton(
            onPressed: _confirmRecoveryKey,
            style: ElevatedButton.styleFrom(
              backgroundColor: BmoColors.accentYellow,
              foregroundColor: BmoColors.screenBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Confirmar chave',
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

  // Download state
  String? _downloadingItemId;
  double _downloadProgress = 0;
  String _downloadFileName = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
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

  /// Opens the browser file picker and returns the selected file, or `null`
  /// if the user cancelled the dialog.
  ///
  /// Uses window focus to detect dialog dismissal — when the file dialog
  /// closes without a file being selected, `onChange` never fires, so we
  /// complete with `null` on the next window focus event after a short delay
  /// to let a legitimate `onChange` event arrive first.
  Future<html.File?> _pickFile() async {
    final input = html.FileUploadInputElement()
      ..accept = '*/*'
      ..multiple = false;

    final completer = Completer<html.File?>();

    input.onChange.listen((_) {
      completer.complete(input.files?.first);
    });

    // Detect cancel: when window regains focus after file dialog closes,
    // give onChange a short window to fire, then treat as cancelled.
    late final StreamSubscription<html.Event> focusSub;
    focusSub = html.window.onFocus.listen((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
    });

    input.click();

    try {
      return await completer.future;
    } finally {
      focusSub.cancel();
    }
  }

  Future<void> _pickAndUploadFile() async {
    final file = await _pickFile();
    if (file == null) return; // User cancelled the dialog.

    // Read file bytes in browser
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;

    final bytes = Uint8List.fromList(reader.result as List<int>);
    final fileName = file.name;
    final mimeType =
        file.type.isNotEmpty ? file.type : 'application/octet-stream';

    if (!mounted) return;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadFileName = fileName;
    });

    try {
      final repo = ref.read(vaultRepositoryProvider);
      await repo.uploadItem(
        _session.vaultId,
        _session.dek,
        bytes,
        fileName,
        mimeType,
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = total > 0 ? sent / total : 0;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadFileName = '';
      });
      await _loadItems();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadFileName = '';
      });
      _showError('Falha no upload: ${_friendlyError(e)}');
    }
  }

  // ----------------------------------------------------------
  // Download
  // ----------------------------------------------------------

  Future<void> _downloadItem(VaultItemDecrypted item) async {
    final isLarge = item.originalSize >= _kLargeFileThreshold;
    final canStream = isFileSystemAccessApiAvailable;

    if (isLarge && canStream) {
      await _downloadItemStreaming(item);
    } else if (isLarge && !canStream) {
      _showError(
        'Arquivo muito grande para este navegador.\n'
        'Use Chrome ou Brave para baixar arquivos grandes.',
      );
    } else {
      await _downloadItemBlob(item);
    }
  }

  /// Streaming download via fetchChunkRange + File System Access API.
  ///
  /// Fetches the 21-byte header, opens a save dialog, then downloads and
  /// decrypts each chunk sequentially — writing each to disk immediately
  /// via the File System Access API. Never holds the full file in memory.
  Future<void> _downloadItemStreaming(VaultItemDecrypted item) async {
    setState(() {
      _downloadingItemId = item.id;
      _downloadProgress = 0;
      _downloadFileName = item.fileName;
    });

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

      // 3. Open save dialog (File System Access API).
      final result = await openSaveStream(item.fileName);
      if (result == null) {
        // User cancelled the save dialog — clean up without error.
        if (!mounted) return;
        setState(() {
          _downloadingItemId = null;
          _downloadFileName = '';
        });
        return;
      }
      final stream = result.stream;

      // 4. Fetch, decrypt, and write each chunk sequentially.
      for (var i = 0; i < totalChunks; i++) {
        if (!mounted) {
          await closeStream(stream);
          return;
        }

        try {
          final (plaintext, statusCode, _) = await repo.fetchChunkRange(
            _session.vaultId,
            _session.dek,
            item.id,
            i,
            header,
          );

          if (statusCode != 206 && plaintext.isEmpty) {
            await closeStream(stream);
            if (!mounted) return;
            setState(() {
              _downloadingItemId = null;
              _downloadFileName = '';
            });
            _showError(
              'Falha no download: servidor retornou status $statusCode.',
            );
            return;
          }

          await writeChunk(stream, plaintext);

          if (mounted) {
            setState(() {
              _downloadProgress = (i + 1) / totalChunks;
            });
          }
        } on VaultApiException catch (e) {
          await closeStream(stream);
          if (!mounted) return;
          setState(() {
            _downloadingItemId = null;
            _downloadFileName = '';
          });
          if (e.statusCode == 410) {
            _showError(
                'Arquivo não encontrado no servidor. O blob foi removido.');
          } else {
            _showError('Falha no download: ${_friendlyError(e)}');
          }
          return;
        }
      }

      // 5. Finalize the file.
      await closeStream(stream);

      if (!mounted) return;
      setState(() {
        _downloadingItemId = null;
        _downloadFileName = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadingItemId = null;
        _downloadFileName = '';
      });
      _showError('Falha no download: ${_friendlyError(e)}');
    }
  }

  /// Small-file download via decryptAll + Blob URL.
  ///
  /// Suitable for files < 25 MB. For larger files the streaming path
  /// ([_downloadItemStreaming]) avoids double memory allocation.
  Future<void> _downloadItemBlob(VaultItemDecrypted item) async {
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
      if (!mounted) return;

      // Save file via browser download
      final blob = html.Blob([plaintext], item.mimeType);
      final url = html.Url.createObjectUrl(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', item.fileName)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      setState(() {
        _downloadingItemId = null;
        _downloadFileName = '';
      });
    } on VaultApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadingItemId = null;
        _downloadFileName = '';
      });
      if (e.statusCode == 410) {
        _showError(
            'Arquivo não encontrado no servidor. O blob foi removido.');
      } else {
        _showError('Falha no download: ${_friendlyError(e)}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadingItemId = null;
        _downloadFileName = '';
      });
      _showError('Falha no download: ${_friendlyError(e)}');
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
  // Open viewer
  // ----------------------------------------------------------

  void _openViewer(VaultItemDecrypted item) {
    openVaultItemViewer(
      context,
      item: item,
      session: _session,
      ref: ref,
      onDownload: () => _downloadItem(item),
    );
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
          onAddFile: _pickAndUploadFile,
          onLock: () => ref.read(vaultSessionProvider.notifier).lock(),
          onDeleteVault: _deleteVault,
        ),
        const Divider(color: BmoColors.textMuted, height: 1),

        // Upload progress bar
        if (_isUploading)
          _ProgressBar(
            progress: _uploadProgress,
            label: 'Enviando $_uploadFileName…',
          ),

        // Download progress bar
        if (_downloadingItemId != null)
          _ProgressBar(
            progress: _downloadProgress,
            label: 'Baixando $_downloadFileName…',
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
          onTap: () => _openViewer(item),
          onDownload: () => _downloadItem(item),
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
  final VoidCallback onAddFile;
  final VoidCallback onLock;
  final VoidCallback onDeleteVault;

  const _VaultHeader({
    required this.vaultName,
    required this.isMobile,
    required this.isUploading,
    required this.onAddFile,
    required this.onLock,
    required this.onDeleteVault,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      child: Row(
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

          // Add file button
          _HeaderIconButton(
            icon: Icons.add,
            tooltip: 'Adicionar arquivo',
            isLoading: isUploading,
            onPressed: onAddFile,
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
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isLoading;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isLoading ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BmoColors.accentGreen,
                  ),
                )
              : Icon(icon, size: 20, color: BmoColors.textSecondary),
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
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _VaultFileItem({
    required this.item,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onDownload,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // Tap target: icon + text opens the viewer
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(_iconForMimeType(item.mimeType),
                        size: 24, color: BmoColors.textMuted),
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

          // Download progress indicator (or menu)
          if (isDownloading)
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

/// Toggle button for switching between password and recovery key unlock.
class _UnlockModeToggle extends StatelessWidget {
  final bool useRecoveryKey;
  final ValueChanged<bool> onChanged;

  const _UnlockModeToggle({
    required this.useRecoveryKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleOption(
          label: 'Senha',
          isSelected: !useRecoveryKey,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 1),
        _ToggleOption(
          label: 'Chave de recuperação',
          isSelected: useRecoveryKey,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? BmoColors.accentGreen.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isSelected ? BmoColors.accentGreen : BmoColors.textMuted.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? BmoColors.accentGreen : BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}

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
