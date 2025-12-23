import 'dart:math';

import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/monthSelector.dart';
import 'package:budget/widgets/navigationSidebar.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/transactionEntries.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime selectedMonth = DateTime.now().firstDayOfMonth();
  DateTime selectedDay = DateTime.now().justDay();

  void _setSelectedMonth(DateTime month) {
    final DateTime monthStart = month.firstDayOfMonth();
    final DateTime lastDay = DateTime(monthStart.year, monthStart.month + 1, 0);
    final int desiredDay = min(selectedDay.day, lastDay.day);
    setState(() {
      selectedMonth = monthStart;
      selectedDay = DateTime(monthStart.year, monthStart.month, desiredDay);
    });
  }

  void _setSelectedDay(DateTime day) {
    setState(() {
      selectedDay = day.justDay();
    });
  }

  DateTime _monthEnd(DateTime monthStart) {
    return DateTime(monthStart.year, monthStart.month + 1, 0).justDay();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime monthStart = selectedMonth.firstDayOfMonth();
    final DateTime monthEnd = _monthEnd(monthStart);

    return PageFramework(
      title: "calendar".tr(),
      bodyBuilder: (scrollController, scrollPhysics, sliverAppBar) {
        return Column(
          children: [
            sliverAppBar,
            Expanded(
              child: StreamBuilder<List<TransactionWithCategory>>(
                stream: database.getTransactionCategoryWithDay(
                  monthStart,
                  monthEnd,
                  budgetTransactionFilters: null,
                  memberTransactionFilters: null,
                ),
                builder: (context, snapshot) {
                  final Map<DateTime, _CalendarDaySummary> daySummaries = {};
                  for (final entry in snapshot.data ?? []) {
                    final DateTime day = entry.transaction.dateCreated.justDay();
                    final summary = daySummaries.putIfAbsent(
                      day,
                      () => _CalendarDaySummary(),
                    );
                    summary.register(entry.transaction);
                  }

                  final bool twoColumns = enableDoubleColumn(context);

                  if (twoColumns) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _CalendarPanel(
                            monthStart: monthStart,
                            daySummaries: daySummaries,
                            selectedDay: selectedDay,
                            onSelectDay: _setSelectedDay,
                            onSelectMonth: _setSelectedMonth,
                            scrollable: true,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: getColor(context, "dividerColor"),
                        ),
                        Expanded(
                          flex: 5,
                          child: _TransactionPanel(
                            selectedDay: selectedDay,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _CalendarPanel(
                        monthStart: monthStart,
                        daySummaries: daySummaries,
                        selectedDay: selectedDay,
                        onSelectDay: _setSelectedDay,
                        onSelectMonth: _setSelectedMonth,
                        scrollable: false,
                      ),
                      Expanded(
                        child: _TransactionPanel(
                          selectedDay: selectedDay,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CalendarDaySummary {
  bool hasIncome = false;
  bool hasExpense = false;
  int count = 0;

  void register(Transaction transaction) {
    count += 1;
    if (transaction.income) {
      hasIncome = true;
    } else {
      hasExpense = true;
    }
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.monthStart,
    required this.daySummaries,
    required this.selectedDay,
    required this.onSelectDay,
    required this.onSelectMonth,
    required this.scrollable,
  });

  final DateTime monthStart;
  final Map<DateTime, _CalendarDaySummary> daySummaries;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<DateTime> onSelectMonth;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 8),
          MonthSelector(
            setSelectedDateStart: (dateTime, index) {
              onSelectMonth(dateTime);
            },
          ),
          SizedBox(height: 12),
          _CalendarWeekdayHeader(),
          SizedBox(height: 8),
          _CalendarGrid(
            monthStart: monthStart,
            daySummaries: daySummaries,
            selectedDay: selectedDay,
            onSelectDay: onSelectDay,
          ),
        ],
      ),
    );

    if (scrollable) {
      return SingleChildScrollView(child: content);
    }
    return content;
  }
}

class _CalendarWeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final firstDay = localizations.firstDayOfWeekIndex;
    final weekdays = localizations.shortWeekdays;

    final orderedWeekdays = List<String>.generate(
      7,
      (index) => weekdays[(firstDay + index) % 7],
    );

    return Row(
      children: [
        for (final day in orderedWeekdays)
          Expanded(
            child: TextFont(
              text: day,
              fontSize: 12,
              textAlign: TextAlign.center,
              textColor: getColor(context, "textLight"),
            ),
          ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.monthStart,
    required this.daySummaries,
    required this.selectedDay,
    required this.onSelectDay,
  });

  final DateTime monthStart;
  final Map<DateTime, _CalendarDaySummary> daySummaries;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;

  int _weekdayIndex(DateTime date) {
    return date.weekday % 7;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime monthEnd =
        DateTime(monthStart.year, monthStart.month + 1, 0);
    final localizations = MaterialLocalizations.of(context);
    final int firstDayOfWeekIndex = localizations.firstDayOfWeekIndex;
    final int leadingEmptyDays =
        (_weekdayIndex(monthStart) - firstDayOfWeekIndex + 7) % 7;

    final int totalDays = monthEnd.day;
    final int totalCells = leadingEmptyDays + totalDays;
    final int trailingEmptyDays = (7 - (totalCells % 7)) % 7;

    final List<DateTime?> calendarDays = [
      ...List<DateTime?>.filled(leadingEmptyDays, null),
      for (int day = 1; day <= totalDays; day++)
        DateTime(monthStart.year, monthStart.month, day),
      ...List<DateTime?>.filled(trailingEmptyDays, null),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: calendarDays.length,
      itemBuilder: (context, index) {
        final date = calendarDays[index];
        if (date == null) {
          return const SizedBox.shrink();
        }

        final bool isSelected = date.justDay() == selectedDay.justDay();
        final bool isToday = date.justDay() == DateTime.now().justDay();
        final summary = daySummaries[date.justDay()];
        final bool hasTransactions = summary != null && summary.count > 0;

        final Color primary = Theme.of(context).colorScheme.primary;
        final Color borderColor = isSelected
            ? primary.withOpacity(0.7)
            : isToday
                ? primary.withOpacity(0.5)
                : hasTransactions
                    ? primary.withOpacity(0.2)
                    : Colors.transparent;

        return Tappable(
          borderRadius: 12,
          onTap: () => onSelectDay(date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: borderColor == Colors.transparent ? 0 : 1.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFont(
                  text: date.day.toString(),
                  fontSize: 14,
                  fontWeight:
                      isSelected || isToday ? FontWeight.bold : FontWeight.w600,
                  textAlign: TextAlign.center,
                ),
                if (hasTransactions) ...[
                  const SizedBox(height: 6),
                  _DayIndicators(summary: summary!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayIndicators extends StatelessWidget {
  const _DayIndicators({required this.summary});

  final _CalendarDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final Color incomeColor = getColor(context, "incomeAmount");
    final Color expenseColor = getColor(context, "expenseAmount");

    final List<Widget> dots = [];
    if (summary.hasIncome) {
      dots.add(_Dot(color: incomeColor));
    }
    if (summary.hasExpense) {
      dots.add(_Dot(color: expenseColor));
    }

    if (dots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dots
          .expand((dot) => [dot, const SizedBox(width: 4)])
          .toList()
        ..removeLast(),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _TransactionPanel extends StatelessWidget {
  const _TransactionPanel({required this.selectedDay});

  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 16, bottom: 8),
            child: TextFont(
              text: getWordedDate(
                selectedDay,
                includeMonthDate: true,
                includeYearIfNotCurrentYear: true,
              ),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: TransactionEntries(
              selectedDay.justDay(),
              selectedDay.justDay(),
              renderType: TransactionEntriesRenderType.nonSlivers,
              listID: "Calendar",
              includeDateDivider: false,
              useHorizontalPaddingConstrained: false,
              showNoResults: true,
              noResultsMessage: "no-transactions-found".tr(),
            ),
          ),
        ],
      ),
    );
  }
}
