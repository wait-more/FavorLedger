import 'package:favor_ledger/core/theme.dart';
import 'package:flutter/material.dart';

/// 人情记日期选择：年、月各自可点开快速选择，再选日。
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  var initial = initialDate;
  if (initial.isBefore(firstDate)) initial = firstDate;
  if (initial.isAfter(lastDate)) initial = lastDate;

  FocusManager.instance.primaryFocus?.unfocus();

  return showDialog<DateTime>(
    context: context,
    builder: (context) => _AppDatePickerDialog(
      initialDate: initial,
      firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
      lastDate: DateTime(lastDate.year, lastDate.month, lastDate.day),
    ),
  );
}

enum _PickerPane { day, year, month }

class _AppDatePickerDialog extends StatefulWidget {
  const _AppDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  late DateTime _selected;
  late DateTime _visibleMonth;
  var _pane = _PickerPane.day;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _visibleMonth = DateTime(_selected.year, _selected.month);
  }

  bool _isYearAllowed(int year) {
    return year >= widget.firstDate.year && year <= widget.lastDate.year;
  }

  bool _isMonthAllowed(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1, 0);
    return !end.isBefore(widget.firstDate) && !start.isAfter(widget.lastDate);
  }

  DateTime _clampDay(int year, int month, int day) {
    final maxDay = DateTime(year, month + 1, 0).day;
    var next = DateTime(year, month, day.clamp(1, maxDay));
    if (next.isBefore(widget.firstDate)) return widget.firstDate;
    if (next.isAfter(widget.lastDate)) return widget.lastDate;
    return next;
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    if (!_isMonthAllowed(next.year, next.month)) return;
    setState(() => _visibleMonth = DateTime(next.year, next.month));
  }

  void _selectYear(int year) {
    if (!_isYearAllowed(year)) return;
    var month = _visibleMonth.month;
    if (!_isMonthAllowed(year, month)) {
      month = _isMonthAllowed(year, widget.firstDate.month)
          ? widget.firstDate.month
          : widget.lastDate.month;
      for (var m = 1; m <= 12; m++) {
        if (_isMonthAllowed(year, m)) {
          month = m;
          break;
        }
      }
    }
    setState(() {
      _visibleMonth = DateTime(year, month);
      _selected = _clampDay(year, month, _selected.day);
      _pane = _PickerPane.month;
    });
  }

  void _selectMonth(int month) {
    final year = _visibleMonth.year;
    if (!_isMonthAllowed(year, month)) return;
    setState(() {
      _visibleMonth = DateTime(year, month);
      _selected = _clampDay(year, month, _selected.day);
      _pane = _PickerPane.day;
    });
  }

  void _selectDay(DateTime day) {
    if (day.isBefore(widget.firstDate) || day.isAfter(widget.lastDate)) {
      return;
    }
    setState(() => _selected = day);
  }

  void _togglePane(_PickerPane target) {
    setState(() => _pane = _pane == target ? _PickerPane.day : target);
  }

  bool get _canPrevMonth {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    return _isMonthAllowed(prev.year, prev.month);
  }

  bool get _canNextMonth {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    return _isMonthAllowed(next.year, next.month);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MonthYearBar(
              year: _visibleMonth.year,
              month: _visibleMonth.month,
              yearSelected: _pane == _PickerPane.year,
              monthSelected: _pane == _PickerPane.month,
              canPrev: _canPrevMonth,
              canNext: _canNextMonth,
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
              onYearTap: () => _togglePane(_PickerPane.year),
              onMonthTap: () => _togglePane(_PickerPane.month),
            ),
            const SizedBox(height: 14),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: switch (_pane) {
                _PickerPane.day => _DayGrid(
                    month: _visibleMonth,
                    selected: _selected,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    onSelect: _selectDay,
                  ),
                _PickerPane.year => _YearGrid(
                    firstYear: widget.firstDate.year,
                    lastYear: widget.lastDate.year,
                    selectedYear: _visibleMonth.year,
                    onSelect: _selectYear,
                  ),
                _PickerPane.month => _MonthGrid(
                    selectedMonth: _selected.year == _visibleMonth.year
                        ? _selected.month
                        : null,
                    visibleMonth: _visibleMonth.month,
                    isAllowed: (m) =>
                        _isMonthAllowed(_visibleMonth.year, m),
                    onSelect: _selectMonth,
                  ),
              },
            ),
            const SizedBox(height: 16),
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
                    onPressed: () => Navigator.pop(context, _selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.jade,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthYearBar extends StatelessWidget {
  const _MonthYearBar({
    required this.year,
    required this.month,
    required this.yearSelected,
    required this.monthSelected,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onYearTap,
    required this.onMonthTap,
  });

  final int year;
  final int month;
  final bool yearSelected;
  final bool monthSelected;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onYearTap;
  final VoidCallback onMonthTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            _NavIcon(
              icon: Icons.chevron_left_rounded,
              tooltip: '上一月',
              enabled: canPrev,
              onTap: onPrev,
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _YearMonthTap(
                      value: '$year',
                      unit: '年',
                      selected: yearSelected,
                      onTap: onYearTap,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: AppColors.line,
                  ),
                  Expanded(
                    child: _YearMonthTap(
                      value: '$month',
                      unit: '月',
                      selected: monthSelected,
                      onTap: onMonthTap,
                    ),
                  ),
                ],
              ),
            ),
            _NavIcon(
              icon: Icons.chevron_right_rounded,
              tooltip: '下一月',
              enabled: canNext,
              onTap: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onTap : null,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: Icon(
          icon,
          size: 22,
          color: enabled
              ? AppColors.jadeDeep
              : AppColors.inkMuted.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

class _YearMonthTap extends StatelessWidget {
  const _YearMonthTap({
    required this.value,
    required this.unit,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String unit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? AppColors.jade : AppColors.ink;

    return Material(
      color: selected
          ? AppColors.jadeSoft.withValues(alpha: 0.65)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? AppColors.jade : AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YearGrid extends StatefulWidget {
  const _YearGrid({
    required this.firstYear,
    required this.lastYear,
    required this.selectedYear,
    required this.onSelect,
  });

  final int firstYear;
  final int lastYear;
  final int selectedYear;
  final ValueChanged<int> onSelect;

  @override
  State<_YearGrid> createState() => _YearGridState();
}

class _YearGridState extends State<_YearGrid> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    final index = (widget.selectedYear - widget.firstYear).clamp(0, 1 << 30);
    // 约 3 列、行高约 48，滚到当前年附近
    final row = index ~/ 3;
    _controller = ScrollController(initialScrollOffset: row * 52.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.lastYear - widget.firstYear + 1;

    return SizedBox(
      height: 240,
      child: GridView.builder(
        controller: _controller,
        itemCount: count,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.7,
        ),
        itemBuilder: (context, index) {
          final year = widget.firstYear + index;
          final selected = year == widget.selectedYear;
          return Material(
            color: selected ? AppColors.jade : AppColors.mist,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => widget.onSelect(year),
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Text(
                  '$year',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: selected ? Colors.white : AppColors.ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.selectedMonth,
    required this.visibleMonth,
    required this.isAllowed,
    required this.onSelect,
  });

  final int? selectedMonth;
  final int visibleMonth;
  final bool Function(int month) isAllowed;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.7,
      ),
      itemBuilder: (context, index) {
        final month = index + 1;
        final allowed = isAllowed(month);
        final selected = selectedMonth == month;
        final browsing = visibleMonth == month && !selected;
        return Material(
          color: !allowed
              ? AppColors.mist.withValues(alpha: 0.35)
              : selected
                  ? AppColors.jade
                  : browsing
                      ? AppColors.jadeSoft.withValues(alpha: 0.7)
                      : AppColors.mist,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: allowed ? () => onSelect(month) : null,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Text(
                '$month月',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: !allowed
                      ? AppColors.inkMuted.withValues(alpha: 0.35)
                      : selected
                          ? Colors.white
                          : AppColors.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.month,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(month.year, month.month, 1);
    final leading = firstDay.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final itemCount = leading + daysInMonth;
    const labels = ['一', '二', '三', '四', '五', '六', '日'];

    return Column(
      children: [
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final day = index - leading + 1;
            final date = DateTime(month.year, month.month, day);
            final allowed =
                !date.isBefore(firstDate) && !date.isAfter(lastDate);
            final isSelected = selected.year == date.year &&
                selected.month == date.month &&
                selected.day == date.day;
            final isToday = DateUtils.isSameDay(date, DateTime.now());

            return Material(
              color: isSelected ? AppColors.jade : Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: allowed ? () => onSelect(date) : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(
                            color: AppColors.jade.withValues(alpha: 0.45),
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: !allowed
                            ? AppColors.inkMuted.withValues(alpha: 0.3)
                            : isSelected
                                ? Colors.white
                                : AppColors.ink,
                        fontWeight:
                            isSelected || isToday ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
