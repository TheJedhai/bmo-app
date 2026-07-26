import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../../../core/widgets/calendar_color_picker.dart';
import '../data/calendar_providers.dart';
import '../data/models/calendar.dart';

class CalendarsScreen extends ConsumerStatefulWidget {
  const CalendarsScreen({super.key});

  @override
  ConsumerState<CalendarsScreen> createState() => _CalendarsScreenState();
}

class _CalendarsScreenState extends ConsumerState<CalendarsScreen> {
  @override
  Widget build(BuildContext context) {
    final calendarsAsync = ref.watch(calendarsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BmoBackButton(),
        title: Text(
          'Calendários',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: calendarsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: BmoColors.accentGreen,
            strokeWidth: 2,
          ),
        ),
        error: (_, _) => const Center(
          child: Text(
            'Erro ao carregar calendários',
            style: TextStyle(
              fontFamily: 'Inter',
              color: BmoColors.textMuted,
            ),
          ),
        ),
        data: (calendars) {
          final personal = calendars.where((c) => c.type == 'personal').toList();
          final shared = calendars.where((c) => c.type == 'shared').toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (personal.isNotEmpty) ...[
                _SectionHeader(title: 'Meus'),
                ...personal.map((c) => _CalendarRow(
                  calendar: c,
                  onEdit: () => _openForm(calendar: c),
                  onDelete: c.isDefault ? null : () => _confirmDelete(c),
                )),
                const SizedBox(height: 8),
              ],
              if (shared.isNotEmpty) ...[
                _SectionHeader(title: 'De nós dois'),
                ...shared.map((c) => _CalendarRow(
                  calendar: c,
                  onEdit: () => _openForm(calendar: c),
                  onDelete: c.isDefault ? null : () => _confirmDelete(c),
                )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: BmoColors.accentGreen,
        foregroundColor: BmoColors.screenBg,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openForm({Calendar? calendar}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalendarFormSheet(calendar: calendar),
    );
  }

  Future<void> _confirmDelete(Calendar calendar) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text(
          'Excluir calendário?',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 13,
            color: BmoColors.textPrimary,
          ),
        ),
        content: Text(
          'Os eventos do calendário "${calendar.name}" serão movidos para '
          '"Casa". Eventos que eram pessoais passarão a ser visíveis para os dois.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: BmoColors.accentRed),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final notifier = ref.read(calendarsProvider.notifier);
      final moved = await notifier.delete(calendar.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$moved evento(s) movidos para "Casa".',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: BmoColors.textSecondary,
        ),
      ),
    );
  }
}

class _CalendarRow extends StatelessWidget {
  final Calendar calendar;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CalendarRow({
    required this.calendar,
    this.onEdit,
    this.onDelete,
  });

  Color get _color {
    final cleaned = calendar.color.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return BmoColors.accentGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BmoColors.screenBgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              calendar.name,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: BmoColors.textPrimary,
              ),
            ),
          ),
          if (calendar.isDefault)
            const Text(
              'padrão',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: BmoColors.textMuted,
              ),
            ),
          const SizedBox(width: 4),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: BmoColors.textMuted,
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: BmoColors.textMuted,
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet for creating/editing a calendar.
class _CalendarFormSheet extends ConsumerStatefulWidget {
  final Calendar? calendar;

  const _CalendarFormSheet({this.calendar});

  @override
  ConsumerState<_CalendarFormSheet> createState() => _CalendarFormSheetState();
}

class _CalendarFormSheetState extends ConsumerState<_CalendarFormSheet> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _personal = true;
  Color _selectedColor = BmoColors.accentGreen;
  bool _saving = false;

  bool get _isEditing => widget.calendar != null;

  @override
  void initState() {
    super.initState();
    final c = widget.calendar;
    if (c != null) {
      _nameCtrl.text = c.name;
      _personal = c.type == 'personal';
      _selectedColor = _parseColor(c.color);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return BmoColors.accentGreen;
  }

  String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: BmoColors.screenBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BmoColors.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEditing ? 'Editar calendário' : 'Novo calendário',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    color: BmoColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Name
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: BmoColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    labelStyle: const TextStyle(
                      fontFamily: 'Inter',
                      color: BmoColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: BmoColors.screenBgElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Color picker
                const Text(
                  'Cor',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BmoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                CalendarColorPicker(
                  selectedColor: _selectedColor,
                  onChanged: (c) => setState(() => _selectedColor = c),
                ),
                const SizedBox(height: 20),

                // Personal / Shared toggle
                if (!_isEditing) ...[
                  const Text(
                    'Tipo',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: BmoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ToggleOption(
                          label: 'Pessoal',
                          subtitle: 'Só você vê',
                          active: _personal,
                          onTap: () => setState(() => _personal = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ToggleOption(
                          label: 'Compartilhado',
                          subtitle: 'Os dois veem',
                          active: !_personal,
                          onTap: () => setState(() => _personal = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // Save
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmoColors.accentGreen,
                      foregroundColor: BmoColors.screenBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BmoColors.screenBg,
                            ),
                          )
                        : Text(_isEditing ? 'Salvar' : 'Criar'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final notifier = ref.read(calendarsProvider.notifier);
      if (_isEditing) {
        await notifier.updateCalendar(
          widget.calendar!.id,
          name: name,
          color: _colorToHex(_selectedColor),
        );
      } else {
        await notifier.create(
          name: name,
          color: _colorToHex(_selectedColor),
          personal: _personal,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? BmoColors.accentGreen.withValues(alpha: 0.15)
              : BmoColors.screenBgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? BmoColors.accentGreen.withValues(alpha: 0.4)
                : BmoColors.textMuted.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? BmoColors.accentGreen : BmoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: active
                    ? BmoColors.accentGreen.withValues(alpha: 0.7)
                    : BmoColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
