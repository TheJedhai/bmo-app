import 'package:flutter/material.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/models/coding_project.dart';
import 'folder_picker_dialog.dart';

/// Resultado do formulário de projeto.
class ProjectFormResult {
  final String name;
  final String primaryPath;
  final List<String> extraPaths;
  final String permissionMode;
  final List<String> allowRules;
  final List<String> denyRules;
  final String? knowledge;

  const ProjectFormResult({
    required this.name,
    required this.primaryPath,
    required this.extraPaths,
    required this.permissionMode,
    required this.allowRules,
    required this.denyRules,
    this.knowledge,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primary_path': primaryPath,
      'extra_paths': extraPaths,
      'permission_mode': permissionMode,
      'allow_rules': allowRules,
      'deny_rules': denyRules,
      if (knowledge != null && knowledge!.isNotEmpty) 'knowledge': knowledge,
    };
  }
}

/// Diálogo de criação/edição de projeto.
class ProjectFormDialog extends StatefulWidget {
  const ProjectFormDialog({
    super.key,
    this.initial,
  });

  final CodingProject? initial;

  /// Abre o diálogo e retorna [ProjectFormResult] ou null se cancelado.
  static Future<ProjectFormResult?> show(
    BuildContext context, {
    CodingProject? initial,
  }) {
    return showDialog<ProjectFormResult>(
      context: context,
      builder: (_) => ProjectFormDialog(initial: initial),
    );
  }

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _primaryPathCtrl;
  late final TextEditingController _extraPathsCtrl;
  late final TextEditingController _allowRulesCtrl;
  late final TextEditingController _denyRulesCtrl;
  late final TextEditingController _knowledgeCtrl;
  late String _permissionMode;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _primaryPathCtrl = TextEditingController(text: p?.primaryPath ?? '');
    _extraPathsCtrl =
        TextEditingController(text: p?.extraPaths.join('\n') ?? '');
    _allowRulesCtrl =
        TextEditingController(text: p?.allowRules.join('\n') ?? '');
    _denyRulesCtrl =
        TextEditingController(text: p?.denyRules.join('\n') ?? '');
    _knowledgeCtrl = TextEditingController(text: p?.knowledge ?? '');
    _permissionMode = p?.permissionMode ?? 'default';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _primaryPathCtrl.dispose();
    _extraPathsCtrl.dispose();
    _allowRulesCtrl.dispose();
    _denyRulesCtrl.dispose();
    _knowledgeCtrl.dispose();
    super.dispose();
  }

  List<String> _parseLines(TextEditingController ctrl) {
    return ctrl.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      ProjectFormResult(
        name: _nameCtrl.text.trim(),
        primaryPath: _primaryPathCtrl.text.trim(),
        extraPaths: _parseLines(_extraPathsCtrl),
        permissionMode: _permissionMode,
        allowRules: _parseLines(_allowRulesCtrl),
        denyRules: _parseLines(_denyRulesCtrl),
        knowledge:
            _knowledgeCtrl.text.trim().isEmpty ? null : _knowledgeCtrl.text.trim(),
      ),
    );
  }

  Future<void> _pickFolder(TextEditingController ctrl) async {
    final picked = await FolderPickerDialog.show(
      context,
      initialPath: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
    );
    if (picked != null) {
      setState(() => ctrl.text = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar projeto' : 'Novo projeto';

    return AlertDialog(
      backgroundColor: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: BmoColors.accentGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 11,
          color: BmoColors.accentGreen,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  'Nome',
                  _nameCtrl,
                  hint: 'Meu Projeto',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),
                _pathField(
                  'Pasta primária',
                  _primaryPathCtrl,
                  hint: 'ex: projetos/meu-app',
                ),
                const SizedBox(height: 12),
                _pathField(
                  'Pastas extras (uma por linha)',
                  _extraPathsCtrl,
                  hint: 'lib\nassets',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                // Modo de permissão
                _sectionLabel('Modo de permissão'),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _permissionMode,
                  decoration: _inputDecoration(),
                  dropdownColor: BmoColors.screenBgElevated,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: BmoColors.textPrimary,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'default',
                      child: Text('Default (allow + deny)'),
                    ),
                    DropdownMenuItem(
                      value: 'allow_all',
                      child: Text('Permitir tudo'),
                    ),
                    DropdownMenuItem(
                      value: 'deny_all',
                      child: Text('Negar tudo'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _permissionMode = v);
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  'Regras allow (uma por linha)',
                  _allowRulesCtrl,
                  hint: 'ext: .py, .ts\npath: src/',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _field(
                  'Regras deny (uma por linha)',
                  _denyRulesCtrl,
                  hint: 'ext: .env\npath: secrets/',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _field(
                  'Knowledge (contexto do projeto)',
                  _knowledgeCtrl,
                  hint: 'Breve descrição do que este projeto faz...',
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text(
            'Cancelar',
            style: TextStyle(
              fontFamily: 'Inter',
              color: BmoColors.textSecondary,
            ),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: BmoColors.accentGreen,
            foregroundColor: const Color(0xFF0F1115),
          ),
          child: Text(
            _isEditing ? 'Salvar' : 'Criar',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: BmoColors.textSecondary,
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          decoration: _inputDecoration(hint: hint),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textPrimary,
          ),
          maxLines: maxLines,
          validator: validator,
        ),
      ],
    );
  }

  Widget _pathField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: ctrl,
                decoration: _inputDecoration(hint: hint),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: BmoColors.textPrimary,
                ),
                maxLines: maxLines,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => _pickFolder(ctrl),
              icon: const Icon(Icons.folder_open, size: 20),
              color: BmoColors.accentGreen,
              tooltip: 'Navegar pastas',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: BmoColors.textMuted,
      ),
      filled: true,
      fillColor: BmoColors.screenBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: BmoColors.accentGreen),
      ),
    );
  }
}
