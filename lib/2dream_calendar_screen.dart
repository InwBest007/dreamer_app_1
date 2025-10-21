//เป็นหน้าคลังปฏิทิน ที่เอาไว้สำหรับอ่านความฝันที่เคยบันทึกเท่านั้น***
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
//import 'dream_input_screen.dart';

class DreamCalendarScreen extends StatefulWidget {
  const DreamCalendarScreen({super.key});

  @override
  State<DreamCalendarScreen> createState() => _DreamCalendarScreenState();
}

class _DreamCalendarScreenState extends State<DreamCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _dreamsByDate = {};

  final TextEditingController _searchController = TextEditingController();
  String? _selectedType;
  String? _selectedEmotion;

  @override
  void initState() {
    super.initState();
    _loadDreamEntries();
  }

  Future<void> _loadDreamEntries() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('dreamEntries')
        .orderBy('date', descending: true)
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> dreams = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final Timestamp ts = data['date'];
      final date =
          DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);

      dreams.putIfAbsent(date, () => []);
      dreams[date]!.add({
        'id': doc.id,
        'title': data['title'],
        'content': data['content'],
        'type': data['type'],
        'emotion': data['emotion'],
        'model': data['model'],
        'luckyNumber': data['luckyNumber'] ?? data['luckynumber'] ?? '-',
        'interpretations': data['interpretations'] ?? [],
        'date': date,
      });
    }

    setState(() {
      _dreamsByDate = dreams;
    });
  }

  List<Map<String, dynamic>> _getDreamsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _dreamsByDate[dateKey] ?? [];
  }

  void _showDreamsForDay(DateTime day) {
    final dreams = _getDreamsForDay(day);
    if (dreams.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: dreams.length,
          itemBuilder: (context, index) {
            final dream = dreams[index];
            return Card(
              color: Colors.pink[50],
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(
                  dream['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  dream['content'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios,
                    color: Colors.pinkAccent),
                onTap: () {
                  Navigator.pop(context);
                  _showDreamDetail(dream);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showDreamDetail(Map<String, dynamic> dream) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final interpretations = dream['interpretations'];
      final luckyNumber = dream['luckyNumber'];
      final bool hasInterpretation = interpretations != null && interpretations.isNotEmpty;
      final bool hasLuckyNumber = luckyNumber != null && luckyNumber != '-';

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Header Title
              Center(
                child: Container(
                  width: 60,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Text(
                dream['title'] ?? 'ไม่มีชื่อเรื่อง',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${DateFormat('dd MMMM yyyy', 'th_TH').format(dream['date'])}",
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // 🔹 Content
              Text(
                dream['content'] ?? 'ไม่มีเนื้อหา',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 20),

              // 🔹 Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text("ประเภท: ${dream['type']}"),
                    backgroundColor: Colors.purple[100],
                  ),
                  Chip(
                    label: Text("อารมณ์: ${dream['emotion']}"),
                    backgroundColor: Colors.pink[100],
                  ),
                  Chip(
                    label: Text("โมเดล: ${dream['model']}"),
                    backgroundColor: Colors.blue[100],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 🔹 Interpretation
              const Text(
                '🪞 คำทำนาย',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              if (hasInterpretation)
                ...List.generate(interpretations.length, (i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      interpretations[i]['interpretation'] ??
                          'ไม่มีข้อมูลคำทำนาย',
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  );
                })
              else
                const Text(
                  'ไม่มีข้อมูลคำทำนาย',
                  style: TextStyle(color: Colors.grey),
                ),

              const SizedBox(height: 20),

              // 🔹 Lucky Number
              const Text(
                '🎲 เลขนำโชค',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              if (hasLuckyNumber)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    luckyNumber,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                )
              else
                const Text('ไม่มีข้อมูลเลขนำโชค',
                    style: TextStyle(color: Colors.grey)),

              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    },
  );
}

  List<Map<String, dynamic>> _filterDreams() {
    final query = _searchController.text.toLowerCase();
    final List<Map<String, dynamic>> allDreams =
        _dreamsByDate.values.expand((list) => list).toList();

    return allDreams.where((dream) {
      final matchesTitle = dream['title'].toLowerCase().contains(query);
      final matchesType =
          _selectedType == null || dream['type'] == _selectedType;
      final matchesEmotion =
          _selectedEmotion == null || dream['emotion'] == _selectedEmotion;
      return matchesTitle && matchesType && matchesEmotion;
    }).toList()
      ..sort((a, b) => b['date'].compareTo(a['date']));
  }

  @override
  Widget build(BuildContext context) {
    final filteredDreams = _filterDreams();

    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5), // ม่วงพาสเทลอ่อน
      appBar: AppBar(
        title: const Text('ปฏิทินบันทึกความฝัน',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔍 ช่องค้นหา
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อความฝัน...',
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ฟิลเตอร์แท็กตัวกรอง
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton<String>(
                  value: _selectedType,
                  hint: const Text('ประเภท'),
                  dropdownColor: Colors.white,
                  items: [
                    'ความฝันปกติ',
                    'ฝันร้าย',
                    'ฝันว่าตื่น',
                    'ความฝันที่รู้ตัวว่ากำลังฝัน'
                  ]
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t,
                                style: const TextStyle(color: Colors.black)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedType = v),
                ),
                DropdownButton<String>(
                  value: _selectedEmotion,
                  hint: const Text('อารมณ์'),
                  dropdownColor: Colors.white,
                  items: [
                    'กลัว',
                    'เศร้า',
                    'ตื่นเต้น',
                    'โกรธ',
                    'เพลิดเพลิน',
                    'ประหลาดใจ'
                  ]
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e,
                                style: const TextStyle(color: Colors.black)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedEmotion = v),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ปฏิทิน
            Expanded(
              flex: 3,
              child: TableCalendar(
                locale: 'th_TH',
                focusedDay: _focusedDay,
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2050, 12, 31),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _showDreamsForDay(selectedDay);
                },
                eventLoader: _getDreamsForDay,
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: TextStyle(color: Colors.black),
                  weekendTextStyle: TextStyle(color: Colors.black87),
                  markerDecoration: BoxDecoration(
                    color: Colors.pinkAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle:
                      TextStyle(color: Colors.deepPurple, fontSize: 18),
                  leftChevronIcon:
                      Icon(Icons.chevron_left, color: Colors.deepPurple),
                  rightChevronIcon:
                      Icon(Icons.chevron_right, color: Colors.deepPurple),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // แสดงผลเฉพาะเมื่อมีการค้นหาหรือเลือก filter
            if (_searchController.text.isNotEmpty ||
                _selectedType != null ||
                _selectedEmotion != null)
              Expanded(
                flex: 2,
                child: ListView.builder(
                  itemCount: filteredDreams.length,
                  itemBuilder: (context, index) {
                    final dream = filteredDreams[index];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 4),
                      child: ListTile(
                        title: Text(dream['title'],
                            style: const TextStyle(color: Colors.black)),
                        subtitle: Text(
                          "${DateFormat('dd/MM/yyyy').format(dream['date'])} - ${dream['type']} (${dream['emotion']})",
                          style: const TextStyle(color: Colors.black54),
                        ),
                        onTap: () => _showDreamsForDay(dream['date']),
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
