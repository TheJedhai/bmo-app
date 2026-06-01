import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../crypto/vault_crypto.dart' as crypto;
import '../data/vault_client.dart';
import '../providers/vault_providers.dart';

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
// Unlocked vault view — placeholder for Phase 8.3d sub-stage 2
// ============================================================

class _UnlockedVaultView extends ConsumerWidget {
  final VaultSession session;

  const _UnlockedVaultView({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 48,
          vertical: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Unlocked icon
            Icon(
              Icons.lock_open_outlined,
              size: isMobile ? 48 : 64,
              color: BmoColors.accentGreen,
            ),
            const SizedBox(height: 16),

            // Vault name
            Text(
              'Cofre: ${session.decryptedName}',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: isMobile ? 14 : 18,
                color: BmoColors.accentGreen,
              ),
            ),
            const SizedBox(height: 12),

            // Placeholder text
            Text(
              'O cofre está destravado.\n'
              'O envio e a visualização de arquivos\n'
              'estarão disponíveis na próxima atualização.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: isMobile ? 13 : 14,
                color: BmoColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Lock button
            SizedBox(
              width: isMobile ? double.infinity : 320,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(vaultSessionProvider.notifier).lock(),
                icon: const Icon(Icons.lock_outline, size: 20),
                label: Text(
                  'Travar cofre',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BmoColors.accentYellow,
                  side: const BorderSide(color: BmoColors.accentYellow),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
