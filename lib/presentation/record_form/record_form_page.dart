import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/core/constants.dart';
import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/core/utils/money.dart';
import 'package:favor_ledger/domain/direction.dart';
import 'package:favor_ledger/presentation/widgets/app_backdrop.dart';
import 'package:favor_ledger/presentation/widgets/soft_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RecordFormPage extends ConsumerStatefulWidget {
  const RecordFormPage({super.key, this.personId, this.recordId});

  final String? personId;
  final String? recordId;

  @override
  ConsumerState<RecordFormPage> createState() => _RecordFormPageState();
}

class _RecordFormPageState extends ConsumerState<RecordFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _event = TextEditingController();
  final _note = TextEditingController();
  FavorDirection _direction = FavorDirection.outBound;
  DateTime _occurredAt = DateTime.now();
  String? _personId;
  var _loading = false;
  var _initialized = false;

  bool get _isEdit => widget.recordId != null;

  @override
  void initState() {
    super.initState();
    _personId = widget.personId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _event.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadIfNeeded() async {
    if (_initialized) return;
    if (widget.recordId != null) {
      final record =
          await ref.read(databaseProvider).getRecord(widget.recordId!);
      if (record != null && mounted) {
        _personId = record.personId;
        _direction = FavorDirection.fromCode(record.direction);
        _amount.text = centsToYuan(record.amountCents);
        _event.text = record.event;
        _note.text = record.note;
        _occurredAt = record.occurredAt.toLocal();
      }
    }
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleProvider);

    return AppBackdrop(
      child: FutureBuilder(
        future: _loadIfNeeded(),
        builder: (context, _) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: Text(_isEdit ? '编辑往来' : '记一笔')),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  SoftPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        peopleAsync.when(
                          loading: () =>
                              const LinearProgressIndicator(minHeight: 2),
                          error: (e, _) => Text('加载亲友失败：$e'),
                          data: (people) {
                            return Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    // ignore: deprecated_member_use
                                    value: people.any((p) => p.id == _personId)
                                        ? _personId
                                        : null,
                                    decoration:
                                        const InputDecoration(labelText: '亲友'),
                                    items: people
                                        .map(
                                          (p) => DropdownMenuItem(
                                            value: p.id,
                                            child: Text(p.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _personId = v),
                                    validator: (v) => v == null || v.isEmpty
                                        ? '请选择亲友'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  tooltip: '新建亲友',
                                  onPressed: _createPersonInline,
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.jadeSoft,
                                    foregroundColor: AppColors.jadeDeep,
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        Text('方向',
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _DirectionChoice(
                                label: '送出',
                                selected: _direction == FavorDirection.outBound,
                                color: AppColors.give,
                                onTap: () => setState(
                                  () => _direction = FavorDirection.outBound,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DirectionChoice(
                                label: '收到',
                                selected: _direction == FavorDirection.inBound,
                                color: AppColors.receive,
                                onTap: () => setState(
                                  () => _direction = FavorDirection.inBound,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amount,
                          decoration: const InputDecoration(
                            labelText: '金额（元）',
                            prefixText: '¥ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            try {
                              final cents = yuanToCents(v ?? '');
                              if (cents <= 0) return '金额需大于 0';
                              return null;
                            } catch (_) {
                              return '请输入正确金额';
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Material(
                          color: AppColors.mistDeep.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            title: const Text('日期'),
                            subtitle: Text(
                              DateFormat('yyyy.MM.dd').format(_occurredAt),
                            ),
                            trailing: const Icon(Icons.calendar_month_rounded),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _event,
                          decoration: const InputDecoration(labelText: '事件'),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: AppConstants.eventChips
                              .map(
                                (chip) => ActionChip(
                                  label: Text(chip),
                                  onPressed: () =>
                                      setState(() => _event.text = chip),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _note,
                          decoration:
                              const InputDecoration(labelText: '备注（可选）'),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _save,
                    child: Text(_loading ? '保存中…' : '保存'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createPersonInline() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _CreatePersonDialog(),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final person =
        await ref.read(ledgerActionsProvider).createPerson(name: name);
    setState(() => _personId = person.id);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _occurredAt = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_personId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(ledgerActionsProvider).saveRecord(
            id: widget.recordId,
            personId: _personId!,
            direction: _direction,
            amountCents: yuanToCents(_amount.text),
            occurredAt: _occurredAt,
            event: _event.text,
            note: _note.text,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        SoftToastScope.show(context, '保存失败：$e', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _CreatePersonDialog extends StatefulWidget {
  const _CreatePersonDialog();

  @override
  State<_CreatePersonDialog> createState() => _CreatePersonDialogState();
}

class _CreatePersonDialogState extends State<_CreatePersonDialog> {
  late final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '新建亲友',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: '姓名'),
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请填写姓名';
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        backgroundColor: AppColors.mist,
                        side: const BorderSide(color: Color(0x330F5C4C)),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.jade,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('创建'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionChoice extends StatelessWidget {
  const _DirectionChoice({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : AppColors.inkMuted,
                ),
          ),
        ),
      ),
    );
  }
}
