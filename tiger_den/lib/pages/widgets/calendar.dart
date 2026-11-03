import 'package:flutter/material.dart';
import '../../base_designs/sitewide/design_main.dart';
class Calendar extends StatefulWidget {
  const Calendar({super.key});

  @override
  State<Calendar> createState() => CalendarState();
}

class CalendarState extends State<Calendar> {
  ///Today's date
  DateTime today = DateTime.now();
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
  DateTime getToday(){
    return today;
  } 
  ///Will be the day the user clicks on the calendar
  DateTime? dayClicked;

  Widget buildCalendarGrid(AppStyle style, ThemeData theme){
    dayClicked ??= getToday();
    int totalDays = daysInMonth(dayClicked!);
    int firstDay = firstDayOfMonth(dayClicked!);
    int offset = firstDay - 1;   
    int totalBoxes = totalDays + offset;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, 
        mainAxisSpacing: style.spaceSmall,
        crossAxisSpacing: style.spaceSmall,
        childAspectRatio: 1.0
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalBoxes,
      itemBuilder: (context, index) {
        int dateNum = (index - offset) +1;
        if (index < offset){
           return SizedBox.shrink();
        }
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.onSurface),
          ),
          child: InkWell(
            onTap: () {
              
            },
            child: Center(
              child: Text(
                '$dateNum',
                style: style.textTheme.bodyMedium,
              ),
            ),
          ),
        );
      },
    );
  }


  Widget buildWeekdayLabels (AppStyle style, ThemeData theme){
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: [
        makeDayLabel(weekdays[0], style, theme),
        makeDayLabel(weekdays[1], style, theme),
        makeDayLabel(weekdays[2], style, theme),
        makeDayLabel(weekdays[3], style, theme),
        makeDayLabel(weekdays[4], style, theme),
        makeDayLabel(weekdays[5], style, theme),
        makeDayLabel(weekdays[6], style, theme),
      ],
    );
  }
  Expanded makeDayLabel(String weekday, AppStyle style, ThemeData theme) {
    return  Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: style.spaceSmall),
        alignment: Alignment.center,
        child: Text(
          weekday, 
          style: style.textTheme.labelLarge,
          
        ),
      ));
  }


  Widget buildCalendarTop(AppStyle style) {
    dayClicked ??= getToday();
    const monthName = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: style.spaceMedium, horizontal: style.spaceSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              dayClicked = DateTime(dayClicked!.year, dayClicked!.month - 1);
            }),
          ),
          Text(
            '${dayClicked!.year} - ${monthName[dayClicked!.month - 1]}',
            style: style.textTheme.headlineMedium,
          ),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              dayClicked = DateTime(dayClicked!.year, dayClicked!.month + 1);
            }),
          ),
        ],
      ),
    );
  }
  Widget build(BuildContext context) {
    final style = context.style;
    final theme = Theme.of(context);
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            buildCalendarTop(style),
            buildWeekdayLabels(style, theme),
            buildCalendarGrid(style, theme)
          ],
        ),
      ),
    );
  }
}
