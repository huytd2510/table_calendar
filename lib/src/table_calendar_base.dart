// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

import 'shared/utils.dart';
import 'widgets/calendar_core.dart';

class TableCalendarBase extends StatefulWidget {
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime focusedDay;
  final CalendarFormat calendarFormat;
  final DayBuilder? dowBuilder;
  final FocusedDayBuilder dayBuilder;
  final double? dowHeight;
  final double rowHeight;
  final bool sixWeekMonthsEnforced;
  final bool dowVisible;
  final Decoration? dowDecoration;
  final Decoration? rowDecoration;
  final Duration formatAnimationDuration;
  final Curve formatAnimationCurve;
  final StartingDayOfWeek startingDayOfWeek;
  final AvailableGestures availableGestures;
  final SimpleSwipeConfig simpleSwipeConfig;
  final Map<CalendarFormat, String> availableCalendarFormats;
  final SwipeCallback? onVerticalSwipe;
  final void Function(DateTime focusedDay)? onPageChanged;
  final void Function(PageController pageController)? onCalendarCreated;

  TableCalendarBase({
    Key? key,
    required this.firstDay,
    required this.lastDay,
    required this.focusedDay,
    this.calendarFormat = CalendarFormat.month,
    this.dowBuilder,
    required this.dayBuilder,
    this.dowHeight,
    required this.rowHeight,
    this.sixWeekMonthsEnforced = false,
    this.dowVisible = true,
    this.dowDecoration,
    this.rowDecoration,
    this.formatAnimationDuration = const Duration(milliseconds: 200),
    this.formatAnimationCurve = Curves.linear,
    this.startingDayOfWeek = StartingDayOfWeek.sunday,
    this.availableGestures = AvailableGestures.all,
    this.simpleSwipeConfig = const SimpleSwipeConfig(
      verticalThreshold: 25.0,
      swipeDetectionBehavior: SwipeDetectionBehavior.continuousDistinct,
    ),
    this.availableCalendarFormats = const {
      CalendarFormat.month: 'Month',
      CalendarFormat.twoWeeks: '2 weeks',
      CalendarFormat.week: 'Week',
    },
    this.onVerticalSwipe,
    this.onPageChanged,
    this.onCalendarCreated,
  })  : assert(!dowVisible || (dowHeight != null && dowBuilder != null)),
        assert(isSameDay(focusedDay, firstDay) || focusedDay.isAfter(firstDay)),
        assert(isSameDay(focusedDay, lastDay) || focusedDay.isBefore(lastDay)),
        super(key: key);

  @override
  _TableCalendarBaseState createState() => _TableCalendarBaseState();
}

class _TableCalendarBaseState extends State<TableCalendarBase>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<double> _pageHeight;
  late final PageController _pageController;
  late DateTime _focusedDay;
  late int _previousIndex;
  late bool _pageCallbackDisabled;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDay;

    final rowCount = _getRowCount(widget.calendarFormat, _focusedDay);
    _pageHeight = ValueNotifier(_getPageHeight(rowCount));

    final initialPage = _calculateFocusedPage(
        widget.calendarFormat, widget.firstDay, _focusedDay);

    _pageController = PageController(initialPage: initialPage);
    widget.onCalendarCreated?.call(_pageController);

    _previousIndex = initialPage;
    _pageCallbackDisabled = false;
  }

  @override
  void didUpdateWidget(TableCalendarBase oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_focusedDay != widget.focusedDay ||
        widget.calendarFormat != oldWidget.calendarFormat ||
        widget.startingDayOfWeek != oldWidget.startingDayOfWeek) {
      _focusedDay = widget.focusedDay;
      _updatePage();
    }

    if (widget.rowHeight != oldWidget.rowHeight ||
        widget.dowHeight != oldWidget.dowHeight ||
        widget.dowVisible != oldWidget.dowVisible ||
        widget.sixWeekMonthsEnforced != oldWidget.sixWeekMonthsEnforced) {
      final rowCount = _getRowCount(widget.calendarFormat, _focusedDay);
      _pageHeight.value = _getPageHeight(rowCount);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageHeight.dispose();
    super.dispose();
  }

  bool get _canScrollHorizontally =>
      widget.availableGestures == AvailableGestures.all ||
      widget.availableGestures == AvailableGestures.horizontalSwipe;

  bool get _canScrollVertically =>
      widget.availableGestures == AvailableGestures.all ||
      widget.availableGestures == AvailableGestures.verticalSwipe;

  void _updatePage() {
    final currentIndex = _calculateFocusedPage(
        widget.calendarFormat, widget.firstDay, _focusedDay);

    final endIndex = _calculateFocusedPage(
        widget.calendarFormat, widget.firstDay, widget.lastDay);

    if (currentIndex != _previousIndex ||
        currentIndex == 0 ||
        currentIndex == endIndex) {
      _pageCallbackDisabled = true;
    }

    _previousIndex = currentIndex;
    final rowCount = _getRowCount(widget.calendarFormat, _focusedDay);
    _pageHeight.value = _getPageHeight(rowCount);

    _pageController.jumpToPage(currentIndex);
    _pageCallbackDisabled = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SimpleGestureDetector(
          onVerticalSwipe: _canScrollVertically ? widget.onVerticalSwipe : null,
          swipeConfig: widget.simpleSwipeConfig,
          child: ValueListenableBuilder<double>(
            valueListenable: _pageHeight,
            builder: (context, value, child) {
              final height = value;

              return AnimatedSize(
                vsync: this,
                duration: widget.formatAnimationDuration,
                curve: widget.formatAnimationCurve,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: height,
                  child: child,
                ),
              );
            },
            child: CalendarCore(
              constraints: constraints,
              pageController: _pageController,
              scrollPhysics: _canScrollHorizontally
                  ? PageScrollPhysics()
                  : NeverScrollableScrollPhysics(),
              firstDay: widget.firstDay,
              lastDay: widget.lastDay,
              startingDayOfWeek: widget.startingDayOfWeek,
              calendarFormat: widget.calendarFormat,
              previousIndex: _previousIndex,
              focusedDay: _focusedDay,
              sixWeekMonthsEnforced: widget.sixWeekMonthsEnforced,
              dowVisible: widget.dowVisible,
              dowHeight: widget.dowHeight,
              rowHeight: widget.rowHeight,
              dowDecoration: widget.dowDecoration,
              rowDecoration: widget.rowDecoration,
              onPageChanged: (index, focusedMonth) {
                if (!_pageCallbackDisabled) {
                  if (!isSameDay(_focusedDay, focusedMonth)) {
                    _focusedDay = focusedMonth;
                  }

                  if (widget.calendarFormat == CalendarFormat.month &&
                      !widget.sixWeekMonthsEnforced &&
                      !constraints.hasBoundedHeight) {
                    final rowCount = _getRowCount(
                      widget.calendarFormat,
                      focusedMonth,
                    );
                    _pageHeight.value = _getPageHeight(rowCount);
                  }

                  _previousIndex = index;
                  widget.onPageChanged?.call(focusedMonth);
                }

                _pageCallbackDisabled = false;
              },
              dowBuilder: widget.dowBuilder,
              dayBuilder: widget.dayBuilder,
            ),
          ),
        );
      },
    );
  }

  double _getPageHeight(int rowCount) {
    final dowHeight = widget.dowVisible ? widget.dowHeight! : 0.0;
    return dowHeight + rowCount * widget.rowHeight;
  }

  int _calculateFocusedPage(
      CalendarFormat format, DateTime startDay, DateTime focusedDay) {
    switch (format) {
      case CalendarFormat.month:
        return _getMonthCount(startDay, focusedDay);
      case CalendarFormat.twoWeeks:
        return _getTwoWeekCount(startDay, focusedDay);
      case CalendarFormat.week:
        return _getWeekCount(startDay, focusedDay);
      default:
        return _getMonthCount(startDay, focusedDay);
    }
  }

  int _getMonthCount(DateTime first, DateTime last) {
    final yearDif = last.year - first.year;
    final monthDif = last.month - first.month;

    return yearDif * 12 + monthDif;
  }

  int _getWeekCount(DateTime first, DateTime last) {
    return last.difference(_firstDayOfWeek(first)).inDays ~/ 7;
  }

  int _getTwoWeekCount(DateTime first, DateTime last) {
    return last.difference(_firstDayOfWeek(first)).inDays ~/ 14;
  }

  int _getRowCount(CalendarFormat format, DateTime focusedDay) {
    if (format == CalendarFormat.twoWeeks) {
      return 2;
    } else if (format == CalendarFormat.week) {
      return 1;
    } else if (widget.sixWeekMonthsEnforced) {
      return 6;
    }

    final first = _firstDayOfMonth(focusedDay);
    final daysBefore = _getDaysBefore(first);
    final firstToDisplay = first.subtract(Duration(days: daysBefore));

    final last = _lastDayOfMonth(focusedDay);
    final daysAfter = _getDaysAfter(last);
    final lastToDisplay = last.add(Duration(days: daysAfter));

    return (lastToDisplay.difference(firstToDisplay).inDays + 1) ~/ 7;
  }

  int _getDaysBefore(DateTime firstDay) {
    return (firstDay.weekday + 7 - getWeekdayNumber(widget.startingDayOfWeek)) %
        7;
  }

  int _getDaysAfter(DateTime lastDay) {
    int invertedStartingWeekday =
        8 - getWeekdayNumber(widget.startingDayOfWeek);

    int daysAfter = 7 - ((lastDay.weekday + invertedStartingWeekday) % 7);
    if (daysAfter == 7) {
      daysAfter = 0;
    }

    return daysAfter;
  }

  DateTime _firstDayOfWeek(DateTime week) {
    final daysBefore = _getDaysBefore(week);
    return week.subtract(Duration(days: daysBefore));
  }

  DateTime _firstDayOfMonth(DateTime month) {
    return DateTime.utc(month.year, month.month, 1);
  }

  DateTime _lastDayOfMonth(DateTime month) {
    final date = month.month < 12
        ? DateTime.utc(month.year, month.month + 1, 1)
        : DateTime.utc(month.year + 1, 1, 1);
    return date.subtract(const Duration(days: 1));
  }
}
