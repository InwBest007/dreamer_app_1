import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:project_dreamer_app/main.dart';
import 'package:intl/intl.dart';
import 'package:project_dreamer_app/screens/dream_input_screen.dart';

class DreamCalendarScreen extends StatefulWidget {
  const DreamCalendarScreen({super.key});

  @override
  State<DreamCalendarScreen> createState() => _DreamCalendarScreenState();
}

class _DreamCalendarScreenState extends State<DreamCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

 // List<String> _getDreamsForDay(DateTime day) {
  //  return dreamEntries[DateTime.utc(day.year, day.month, day.day)] ?? [];
  //}
  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Calendar Dream Journal', style: TextStyle(color: Colors.white),),
        centerTitle: true,
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'th_TH',
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2050, 12, 31),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay){
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              Navigator.pushNamed(context, '/dream_input_screen', arguments: selectedDay);
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              defaultTextStyle: TextStyle(color: Colors.white),
              weekendTextStyle: TextStyle(color: Colors.white70),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) => null,
              defaultBuilder: (context, day, focusedDay){
                return Center(
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}
