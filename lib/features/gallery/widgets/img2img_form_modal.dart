import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import 'package:bmo_app/features/settings/data/flux_model.dart';
import 'package:bmo_app/features/settings/providers/settings_provider.dart';
import '../data/images_client.dart';
import '../providers/images_provider.dart';

void showImg2ImgFormModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _Img2ImgFormModal(),
  );
}

class _Img2ImgFormModal extends ConsumerStatefulWidget {
  const _Img2ImgFormModal();

  @override
  ConsumerState<_Img2ImgFormModal> createState() => _Img2ImgFormModalState();
}

class _Img2ImgFormModalState extends ConsumerState<_Img2ImgFormModal> {
  final _promptCtrl = TextEditingController();
  final _negativeCtrl = TextEditingController();

  Uint8List? _sourceBytes;
  String? _sourceFileName;
  double _strength = 0.35;
  String? _selectedModel;
  bool _isSubmitting = false;

  String? _sourceError;
  String? _promptError;

  @override
  void dispose() {
    _promptCtrl.dispose();
    _negativeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSource() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao ler arquivo. Tente outro.')),
          );
        }
        return;
      }
      setState(() {
        _sourceBytes = Uint8List.fromList(bytes);
        _sourceFileName = file.name;
        _sourceError = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivo: $e')),
        );
      }
    }
  }

  bool _validate() {
    var ok = true;
    setState(() {
      if (_sourceBytes == null) {
        _sourceError = 'Selecione uma imagem fonte';
        ok = false;
      } else {
        _sourceError = null;
      }
      if (_promptCtrl.text.trim().isEmpty) {
        _promptError = 'Prompt é obrigatório';
        ok = false;
      } else {
        _promptError = null;
      }
    });
    return ok;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(imagesRepositoryProvider);
      await repo.generateImg2img(
        sourceBytes: _sourceBytes!,
        fileName: _sourceFileName!,
        prompt: _promptCtrl.text.trim(),
        negativePrompt: _negativeCtrl.text.trim().isEmpty
            ? null
            : _negativeCtrl.text.trim(),
        model: _selectedModel,
        strength: _strength,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ImagesApiException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao enviar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final modelsAsync = ref.watch(imageModelsProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Dialog(
      backgroundColor: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BmoColors.bodyGreen, width: 2),
      ),
      insetPadding: isMobile
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 520,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Novo img2img',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: BmoColors.textSecondary),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ---------- Source image picker ----------
                    _FormLabel('Imagem fonte'),
                    const SizedBox(height: 6),
                    _SourcePicker(
                      bytes: _sourceBytes,
                      error: _sourceError,
                      onPick: _pickSource,
                    ),
                    const SizedBox(height: 20),

                    // ---------- Prompt ----------
                    _FormLabel('Prompt *'),
                    const SizedBox(height: 6),
                    _BmoTextField(
                      controller: _promptCtrl,
                      hintText: 'Descreva a imagem desejada...',
                      error: _promptError,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // ---------- Negative prompt ----------
                    _FormLabel('Negative prompt'),
                    const SizedBox(height: 6),
                    _BmoTextField(
                      controller: _negativeCtrl,
                      hintText: 'O que evitar na imagem...',
                    ),
                    const SizedBox(height: 16),

                    // ---------- Strength ----------
                    _FormLabel('Strength'),
                    const SizedBox(height: 6),
                    _StrengthSlider(
                      value: _strength,
                      onChanged: (v) => setState(() => _strength = v),
                    ),
                    const SizedBox(height: 16),

                    // ---------- Model ----------
                    _FormLabel('Modelo'),
                    const SizedBox(height: 6),
                    _ModelDropdown(
                      modelsAsync: modelsAsync,
                      settingsAsync: settingsAsync,
                      value: _selectedModel,
                      onChanged: (m) => setState(() => _selectedModel = m),
                    ),
                  ],
                ),
              ),
            ),
            // Footer buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: BmoColors.accentGreen,
                      foregroundColor: BmoColors.screenBg,
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BmoColors.screenBg,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_isSubmitting ? 'Enviando...' : 'Gerar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Form label
// ============================================================

class _FormLabel extends StatelessWidget {
  final String text;

  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: BmoColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ============================================================
// BMO-styled text field
// ============================================================

class _BmoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? error;
  final int maxLines;

  const _BmoTextField({
    required this.controller,
    this.hintText,
    this.error,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: BmoColors.textPrimary,
              ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BmoColors.textMuted,
                ),
            filled: true,
            fillColor: BmoColors.screenBg,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: BmoColors.textMuted.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: BmoColors.accentGreen,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Colors.redAccent,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// Source image picker
// ============================================================

class _SourcePicker extends StatelessWidget {
  final Uint8List? bytes;
  final String? error;
  final VoidCallback onPick;

  const _SourcePicker({
    required this.bytes,
    required this.error,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: BmoColors.screenBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: error != null
                    ? Colors.redAccent
                    : BmoColors.textMuted.withValues(alpha: 0.3),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(bytes!, fit: BoxFit.cover),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: BmoColors.screenBg.withValues(alpha: 0.7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Text(
                            'Clique para trocar a imagem',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: BmoColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: BmoColors.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Selecionar imagem',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: BmoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Colors.redAccent,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// Strength slider
// ============================================================

class _StrengthSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _StrengthSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: BmoColors.accentGreen,
              inactiveTrackColor:
                  BmoColors.accentGreen.withValues(alpha: 0.15),
              thumbColor: BmoColors.accentGreen,
              overlayColor: BmoColors.accentGreen.withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 42,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: BmoColors.accentGreen,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Model dropdown
// ============================================================

class _ModelDropdown extends StatelessWidget {
  final AsyncValue<List<FluxModel>> modelsAsync;
  final AsyncValue<Map<String, String>> settingsAsync;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _ModelDropdown({
    required this.modelsAsync,
    required this.settingsAsync,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return modelsAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: BmoColors.accentGreen,
            ),
          ),
        ),
      ),
      error: (e, _) => Text(
        'Erro ao carregar modelos',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Colors.redAccent,
        ),
      ),
      data: (models) {
        // Determine the effective value: explicit selection > settings default
        // > model with isDefault > null (server default)
        final settingsMap = settingsAsync.valueOrNull ?? const {};
        final settingsDefault = settingsMap['image.default_model'];

        final effectiveValue = value ??
            settingsDefault ??
            (models
                .where((m) => m.isDefault)
                .map((m) => m.name)
                .firstOrNull);

        // Build items: server default + each model name
        final items = <String?>[null, ...models.map((m) => m.name)];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: BmoColors.screenBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: BmoColors.textMuted.withValues(alpha: 0.3),
            ),
          ),
          child: DropdownButton<String?>(
            value: effectiveValue,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: BmoColors.screenBgElevated,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: BmoColors.textPrimary,
            ),
            selectedItemBuilder: (_) => items.map((m) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  m ?? 'Padrão do servidor',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: m == null
                        ? BmoColors.textMuted
                        : BmoColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            items: items.map((m) {
              final isDefault = m == null;
              final display = isDefault ? 'Padrão do servidor' : m;
              return DropdownMenuItem<String?>(
                value: m,
                child: Text(
                  display,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color:
                        isDefault ? BmoColors.textMuted : BmoColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}
