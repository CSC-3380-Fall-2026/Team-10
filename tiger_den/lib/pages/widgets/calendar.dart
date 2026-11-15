import 'package:flutter/material.dart';

import '../../base_designs/sitewide/design_main.dart';
import '../../models/calendar_entry.dart';
import '../../services/firestore_service.dart';
import '../../services/session_service.dart';

/// The logged-in user's personal calendar: a month grid showing their
/// calendar entries (events they RSVP'd "going"/"interested" to, plus
/// personal entries) on the right days, with their times.
///
/// By default it shows whoever is logged in (SessionService). Pass
/// [currentUserId] to show a specific user's calendar instead (e.g. in tests).
class Calendar extends StatefulWidget {
  const Calendar({super.key, this.currentUserId, this.firestoreService});

  /// Whose calendar to show. Null = the logged-in user.
  final String? currentUserId;

  final FirestoreService? firestoreService;

  @override
  State<Calendar> createState() => CalendarState();
}

class CalendarState extends State<Calendar> {
  ///Today's date
  DateTime today = DateTime.now();

  ///Will be the day the user clicks on the calendar
  DateTime? dayClicked;

  late final FirestoreService firestoreService;
  final SessionService session = SessionService.instance;

  /// The user whose calendar is loaded
  String? loadedUid;

  /// One live connection to the user's calendar. It's only replaced when a
  /// different user logs in, NOT when the page redraws or the month changes,
  /// so switching months doesn't cost extra database reads.
  Stream<List<CalendarEntry>>? entriesStream;

  ///Gets the the number of days for the month of whatever date is put in
  int daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  ///Get the weekday of the 1st of the month
  ///Monday = 1, etc
  int firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday;
  }

  ///Gets today's date
  DateTime getToday() {
    return today;
  }

  /// The user whose calendar to show right now
  String? get currentUid => widget.currentUserId ?? session.currentUid;

  @override
  void initState() {
    super.initState();
    firestoreService = widget.firestoreService ?? FirestoreService();
    session.addListener(onSessionChanged);
    connectToCalendar();
  }

  @override
  void didUpdateWidget(Calendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUserId != widget.currentUserId) {
      connectToCalendar();
    }
  }

  @override
  void dispose() {
    session.removeListener(onSessionChanged);
    super.dispose();
  }

  /// Reconnects only if a different user is now logged in
  void onSessionChanged() {
    if (widget.currentUserId == null && session.currentUid != loadedUid) {
      setState(connectToCalendar);
    }
  }

  /// Connects to the current user's calendar entries in Firestore
  void connectToCalendar() {
    final String? uid = currentUid;
    loadedUid = uid;
    entriesStream = uid == null ? null : firestoreService.streamCalendar(uid);
  }

  /// Just the date part (no time), used to match entries to grid days
  DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  /// Groups entries by the days they fall on in [month]. An entry that spans
  /// several days (e.g. a weekend trip) shows up on each of those days.
  Map<DateTime, List<CalendarEntry>> entriesByDay(
      List<CalendarEntry> entries, DateTime month) {
    final DateTime monthStart = DateTime(month.year, month.month, 1);
    final DateTime monthEnd = DateTime(month.year, month.month + 1, 0);
    final Map<DateTime, List<CalendarEntry>> byDay =
        <DateTime, List<CalendarEntry>>{};

    for (final CalendarEntry entry in entries) {
      DateTime day = dateOnly(entry.startTime);
      DateTime lastDay = dateOnly(entry.endTime);
      if (lastDay.isBefore(day)) lastDay = day; // bad data: treat as one day
      if (lastDay.isBefore(monthStart) || day.isAfter(monthEnd)) continue;
      if (day.isBefore(monthStart)) day = monthStart;
      if (lastDay.isAfter(monthEnd)) lastDay = monthEnd;

      while (!day.isAfter(lastDay)) {
        byDay.putIfAbsent(day, () => <CalendarEntry>[]).add(entry);
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }

    // Within a day: all-day entries first, then by start time.
    for (final List<CalendarEntry> dayEntries in byDay.values) {
      dayEntries.sort((CalendarEntry a, CalendarEntry b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return a.startTime.compareTo(b.startTime);
      });
    }
    return byDay;
  }

  /// A short time like "6p" or "6:30p", to fit in a small day square
  String shortTime(DateTime time) {
    final int hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final String minutes =
        time.minute == 0 ? '' : ':${time.minute.toString().padLeft(2, '0')}';
    final String period = time.hour < 12 ? 'a' : 'p';
    return '$hour$minutes$period';
  }

  /// The entry's own color (e.g. '#4A90E2'), or the app's purple
  Color entryColor(CalendarEntry entry) {
    final String? hex = entry.color;
    if (hex != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }
    return AppColors.purple;
  }

  /// One small colored label inside a day square: "6p Mixer"
  Widget buildEntryChip(CalendarEntry entry, DateTime day) {
    // Show the time only on the day the entry starts.
    final bool startsToday = dateOnly(entry.startTime) == day;
    final String label = (entry.allDay || !startsToday)
        ? entry.title
        : '${shortTime(entry.startTime)} ${entry.title}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: entryColor(entry),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9,
          height: 1.2,
          color: AppColors.white,
        ),
      ),
    );
  }

  ///Builds the date grid with all the dates
  Widget buildCalendarGrid(AppStyle style, ThemeData theme,
      Map<DateTime, List<CalendarEntry>> byDay) {
    dayClicked ??= getToday();
    final DateTime month = dayClicked!;
    final int totalDays = daysInMonth(month);
    final int firstDay = firstDayOfMonth(month);
    final int offset = firstDay - 1;
    final int totalBoxes = totalDays + offset;
    const int maxChips = 2;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: style.spaceExtraSmall,
        crossAxisSpacing: style.spaceExtraSmall,
        // Taller than wide, so there's room for event labels.
        childAspectRatio: 0.55,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalBoxes,
      itemBuilder: (BuildContext context, int index) {
        if (index < offset) {
          return const SizedBox.shrink();
        }
        final int dateNum = (index - offset) + 1;
        final DateTime day = DateTime(month.year, month.month, dateNum);
        final List<CalendarEntry> dayEntries =
            byDay[day] ?? <CalendarEntry>[];
        final bool isToday = day == dateOnly(today);
        final int hiddenCount = dayEntries.length - maxChips;

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isToday ? AppColors.purple : theme.colorScheme.outline,
              width: isToday ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: InkWell(
            onTap: () {
///gotta put our like button logic here
            },
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$dateNum',
                    style: style.textTheme.bodyMedium?.copyWith(
                      fontWeight: isToday ? FontWeight.bold : null,
                      color: isToday ? AppColors.purple : null,
                    ),
                  ),
                  for (final CalendarEntry entry in dayEntries.take(maxChips))
                    buildEntryChip(entry, day),
                  if (hiddenCount > 0)
                    Text(
                      '+$hiddenCount more',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  ///Builds labels for the week days
  Widget buildWeekdayLabels(AppStyle style, ThemeData theme) {
    const List<String> weekdays = <String>[
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    return Row(
      children: <Widget>[
        for (final String weekday in weekdays)
          makeDayLabel(weekday, style, theme),
      ],
    );
  }

  ///makes the labels for the weekdays
  Expanded makeDayLabel(String weekday, AppStyle style, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: style.spaceSmall),
        alignment: Alignment.center,
        child: Text(
          weekday,
          style: style.textTheme.labelLarge,
        ),
      ),
    );
  }

  ///Builds the header, top buttons, and logic for switching calendar pages
  Widget buildCalendarTop(AppStyle style) {
    dayClicked ??= getToday();
    const List<String> monthName = <String>[
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: style.spaceMedium),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              dayClicked = DateTime(dayClicked!.year, dayClicked!.month - 1);
            }),
          ),
          Text(
            '${dayClicked!.year} - ${monthName[dayClicked!.month - 1]}',
            style: style.textTheme.headlineMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              dayClicked = DateTime(dayClicked!.year, dayClicked!.month + 1);
            }),
          ),
        ],
      ),
    );
  }

  /// A small note shown under the grid (e.g. not logged in, load errors)
  Widget buildNote(AppStyle style, String text) {
    return Padding(
      padding: EdgeInsets.only(top: style.spaceMedium),
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  ///Builds the calendar
  @override
  Widget build(BuildContext context) {
    final AppStyle style = context.style;
    final ThemeData theme = Theme.of(context);
    dayClicked ??= getToday();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          // Padding around the whole calendar
          padding: EdgeInsets.symmetric(
            horizontal: style.spaceMedium,
            vertical: style.spaceSmall,
          ),
          child: StreamBuilder<List<CalendarEntry>>(
            stream: entriesStream,
            builder: (BuildContext context,
                AsyncSnapshot<List<CalendarEntry>> snapshot) {
              final List<CalendarEntry> entries =
                  snapshot.data ?? <CalendarEntry>[];
              final Map<DateTime, List<CalendarEntry>> byDay =
                  entriesByDay(entries, dayClicked!);
              return Column(
                children: <Widget>[
                  buildCalendarTop(style),
                  buildWeekdayLabels(style, theme),
                  buildCalendarGrid(style, theme, byDay),
                  if (currentUid == null)
                    buildNote(style, 'Log in to see your events here.'),
                  if (snapshot.hasError)
                    buildNote(style,
                        'Could not load your calendar: ${snapshot.error}'),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
