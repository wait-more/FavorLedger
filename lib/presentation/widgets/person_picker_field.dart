import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/data/local/database.dart';
import 'package:favor_ledger/presentation/widgets/person_avatar.dart';
import 'package:flutter/material.dart';

/// 可搜索的亲友选择字段（记一笔、流水筛选等共用）。
class PersonPickerField extends FormField<String?> {
  PersonPickerField({
    super.key,
    required List<Person> people,
    required String? value,
    required ValueChanged<String?> onChanged,
    String labelText = '亲友',
    String hintText = '选择亲友',
    bool allowClear = false,
    String clearLabel = '全部亲友',
    bool isDense = false,
    super.validator,
    AutovalidateMode autovalidateMode = AutovalidateMode.disabled,
  }) : super(
          initialValue: value,
          autovalidateMode: autovalidateMode,
          builder: (state) {
            if (state.value != value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (state.mounted) state.didChange(value);
              });
            }

            Person? selected;
            for (final p in people) {
              if (p.id == value) {
                selected = p;
                break;
              }
            }
            final showClearLabel = allowClear && value == null;
            final display = selected?.name ?? (showClearLabel ? clearLabel : null);

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                final picked = await showPersonPickerSheet(
                  state.context,
                  people: people,
                  selectedId: value,
                  allowClear: allowClear,
                  clearLabel: clearLabel,
                  title: labelText,
                );
                if (picked == null) return;
                state.didChange(picked.id);
                onChanged(picked.id);
              },
              child: InputDecorator(
                isEmpty: display == null || display.isEmpty,
                decoration: InputDecoration(
                  labelText: labelText,
                  hintText: hintText,
                  isDense: isDense,
                  errorText: state.errorText,
                  suffixIcon: Icon(
                    Icons.unfold_more_rounded,
                    color: AppColors.jadeDeep.withValues(alpha: 0.75),
                  ),
                ),
                child: Text(
                  display ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(state.context).textTheme.bodyLarge?.copyWith(
                        color: selected != null || showClearLabel
                            ? AppColors.ink
                            : AppColors.inkMuted,
                      ),
                ),
              ),
            );
          },
        );
}

/// 用户确认选择的结果；点遮罩关闭时返回 `null`（取消）。
class PersonPickerSelection {
  const PersonPickerSelection(this.id);

  /// `null` 表示「全部亲友」等清空选项。
  final String? id;
}

Future<PersonPickerSelection?> showPersonPickerSheet(
  BuildContext context, {
  required List<Person> people,
  String? selectedId,
  bool allowClear = false,
  String clearLabel = '全部亲友',
  String title = '选择亲友',
}) {
  return showModalBottomSheet<PersonPickerSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _PersonPickerSheet(
      people: people,
      selectedId: selectedId,
      allowClear: allowClear,
      clearLabel: clearLabel,
      title: title,
    ),
  );
}

class _PersonPickerSheet extends StatefulWidget {
  const _PersonPickerSheet({
    required this.people,
    required this.selectedId,
    required this.allowClear,
    required this.clearLabel,
    required this.title,
  });

  final List<Person> people;
  final String? selectedId;
  final bool allowClear;
  final String clearLabel;
  final String title;

  @override
  State<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

/// 列表项固定高度，便于按索引滚到当前选中项。
const _kPickerTileExtent = 66.0;

class _PersonPickerSheetState extends State<_PersonPickerSheet> {
  final _query = TextEditingController();
  late final ScrollController _scrollController;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    // 直接以选中项为初始偏移，打开时已在位，不再做滚动动画
    _scrollController = ScrollController(
      initialScrollOffset: _initialOffsetForSelected(),
    );
  }

  @override
  void dispose() {
    _query.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int? _selectedIndex(List<Person> people) {
    if (widget.allowClear && widget.selectedId == null) return 0;
    final personIndex = people.indexWhere((p) => p.id == widget.selectedId);
    if (personIndex < 0) return null;
    return widget.allowClear ? personIndex + 1 : personIndex;
  }

  double _initialOffsetForSelected() {
    final index = _selectedIndex(widget.people);
    if (index == null || index <= 0) return 0;
    // 视口高度此时未知，先按条目顶对齐估算；过大时由 ScrollPosition 夹紧
    return index * _kPickerTileExtent;
  }

  List<Person> get _filtered {
    if (_filter.isEmpty) return widget.people;
    final q = _filter.toLowerCase();
    return widget.people.where((p) {
      return p.name.contains(_filter) || p.namePinyin.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final filtered = _filtered;
    final height = MediaQuery.sizeOf(context).height * 0.72;
    final showClear = widget.allowClear && _filter.isEmpty;
    final itemCount = filtered.isEmpty
        ? (showClear ? 1 : 0) + 1
        : (showClear ? 1 : 0) + filtered.length;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mistDeep,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.inkMuted,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _query,
                // 有选中项时先不抢焦点，避免键盘挤掉滚动定位
                autofocus: widget.selectedId == null && widget.people.length > 8,
                decoration: const InputDecoration(
                  hintText: '搜索姓名或拼音',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filter = v.trim()),
              ),
            ),
            Expanded(
              child: filtered.isEmpty && !showClear
                  ? Center(
                      child: Text(
                        widget.people.isEmpty ? '暂无亲友' : '没有匹配的亲友',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemExtent: _kPickerTileExtent,
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (showClear && index == 0) {
                          return _PickerTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.mist,
                                border: Border.all(color: AppColors.line),
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                size: 20,
                                color: AppColors.jadeDeep,
                              ),
                            ),
                            title: widget.clearLabel,
                            selected: widget.selectedId == null,
                            onTap: () => Navigator.pop(
                              context,
                              const PersonPickerSelection(null),
                            ),
                          );
                        }

                        final personIndex = showClear ? index - 1 : index;
                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              '没有匹配的亲友',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                          );
                        }

                        final person = filtered[personIndex];
                        return _PickerTile(
                          leading: PersonAvatar(name: person.name, size: 40),
                          title: person.name,
                          selected: person.id == widget.selectedId,
                          onTap: () => Navigator.pop(
                            context,
                            PersonPickerSelection(person.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected
            ? AppColors.jadeSoft.withValues(alpha: 0.75)
            : AppColors.mist.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? AppColors.jadeDeep : AppColors.ink,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    color: AppColors.jade,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
