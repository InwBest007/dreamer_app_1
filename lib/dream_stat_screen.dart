//DreamStatScreen
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
//import 'package:intl/intl.dart';

class DreamStatScreen extends StatefulWidget {
  const DreamStatScreen({super.key});

  @override
  State<DreamStatScreen> createState() => _DreamStatScreenState();
}

class _DreamStatScreenState extends State<DreamStatScreen> {
  Map<String, int> typeCounts = {};
  Map<String, int> emotionCounts = {};
  Map<String, int> dailyCounts = {};

  // ✨ เพิ่มตัวแปรใหม่เพื่อเก็บข้อมูลเสียงเฉลี่ยและสรุปผล
  Map<String, double> avgSoundPerType = {};
  String soundDreamInsight = "";

  String selectedView = "รายเดือน"; // default
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  final List<String> views = ["รายสัปดาห์", "รายเดือน"];
  final List<String> thaiMonths = [
    "มกราคม",
    "กุมภาพันธ์",
    "มีนาคม",
    "เมษายน",
    "พฤษภาคม",
    "มิถุนายน",
    "กรกฎาคม",
    "สิงหาคม",
    "กันยายน",
    "ตุลาคม",
    "พฤศจิกายน",
    "ธันวาคม"
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // ฟังก์ชันหาช่วงเวลา
  DateTimeRange _getDateRange() {
    if (selectedView == "รายเดือน") {
      final start = DateTime(selectedYear, selectedMonth, 1);
      final end = DateTime(selectedYear, selectedMonth + 1, 0);
      return DateTimeRange(start: start, end: end);
    } else {
      final now = DateTime.now();
      final weekday = now.weekday; // จันทร์=1 ... อาทิตย์=7
      final start = now.subtract(Duration(days: weekday - 1));
      final end = start.add(const Duration(days: 6));
      return DateTimeRange(start: start, end: end);
    }
  }

  Future<void> _loadStats() async {
    final range = _getDateRange();

    final snapshot = await FirebaseFirestore.instance
        .collection("dreamEntries")
        .where("date", isGreaterThanOrEqualTo: range.start)
        .where("date", isLessThanOrEqualTo: range.end)
        .get();

    final Map<String, int> tempTypeCounts = {};
    final Map<String, int> tempEmotionCounts = {};
    final Map<String, int> tempDailyCounts = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final type = data['type'] ?? 'ไม่ระบุ';
      final emotion = data['emotion'] ?? 'ไม่ระบุ';
      final date = (data['date'] as Timestamp).toDate();

      // นับประเภทความฝัน
      tempTypeCounts[type] = (tempTypeCounts[type] ?? 0) + 1;

      // นับอารมณ์
      tempEmotionCounts[emotion] = (tempEmotionCounts[emotion] ?? 0) + 1;

      // นับความถี่รายวัน
      final dayKey = "${date.day}/${date.month}";
      tempDailyCounts[dayKey] = (tempDailyCounts[dayKey] ?? 0) + 1;
    }

    // ---------------------- ส่วน Audio ที่เพิ่มใหม่ ----------------------

    // ดึงข้อมูลเสียงทั้งหมดในช่วงเวลาเดียวกัน
    final soundSnapshot = await FirebaseFirestore.instance
        .collection("sound_data")
        .where("timestamp", isGreaterThanOrEqualTo: range.start)
        .where("timestamp", isLessThanOrEqualTo: range.end)
        .get();

    final List<Map<String, dynamic>> sounds =
        soundSnapshot.docs.map((d) => d.data()).toList();

    final Map<String, List<double>> soundByDreamType = {};

    for (var dreamDoc in snapshot.docs) {
      final data = dreamDoc.data();
      final dreamDate = (data['date'] as Timestamp).toDate();
      final type = data['type'] ?? 'ไม่ระบุ';

      // หาเสียงในช่วงใกล้เคียง (±6 ชั่วโมง)
      final relatedSounds = sounds.where((sound) {
        final soundDate = (sound['timestamp'] as Timestamp).toDate();
        return soundDate.isAfter(dreamDate.subtract(const Duration(hours: 6))) &&
            soundDate.isBefore(dreamDate.add(const Duration(hours: 6)));
      }).toList();

      if (relatedSounds.isEmpty) continue;

      // คำนวณค่าเฉลี่ยระดับเสียง
      final avgDecibel = relatedSounds
              .map((s) => (s['maxDecibel'] ?? 0).toDouble())
              .fold(0.0, (a, b) => a + b) /
          relatedSounds.length;

      soundByDreamType.putIfAbsent(type, () => []).add(avgDecibel);
    }

    // หาค่าเฉลี่ยระดับเสียงต่อประเภทฝัน
    final Map<String, double> tempAvgSoundPerType = {};
    soundByDreamType.forEach((type, list) {
      final avg = list.reduce((a, b) => a + b) / list.length;
      tempAvgSoundPerType[type] = double.parse(avg.toStringAsFixed(2));
    });

    // วิเคราะห์แนวโน้มความสัมพันธ์ระหว่างเสียงกับประเภทความฝัน
    String tempInsight = "";
    if (tempAvgSoundPerType.isNotEmpty) {
      final sorted = tempAvgSoundPerType.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final quietest = sorted.first;
      final loudest = sorted.last;

      tempInsight =
          "คืนที่เสียงเฉลี่ย ${loudest.value} dB มักสัมพันธ์กับ '${loudest.key}' "
          "ขณะที่คืนที่เงียบกว่า (${quietest.value} dB) มักเป็น '${quietest.key}'";
    }

    setState(() {
      typeCounts = tempTypeCounts;
      emotionCounts = tempEmotionCounts;
      dailyCounts = tempDailyCounts;
      avgSoundPerType = tempAvgSoundPerType;
      soundDreamInsight = tempInsight;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("แสดงผลสถิติความฝัน"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Dropdown เลือกช่วงเวลา
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedView,
                    items: views
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedView = val!;
                      });
                      _loadStats();
                    },
                    decoration: const InputDecoration(labelText: "แสดงผล"),
                  ),
                ),
                const SizedBox(width: 12),
                if (selectedView == "รายเดือน") ...[
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selectedMonth,
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(thaiMonths[i]),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          selectedMonth = val!;
                        });
                        _loadStats();
                      },
                      decoration: const InputDecoration(labelText: "เดือน"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selectedYear,
                      items: List.generate(
                        5,
                        (i) {
                          final year = DateTime.now().year - i;
                          return DropdownMenuItem(
                            value: year,
                            child: Text("$year"),
                          );
                        },
                      ),
                      onChanged: (val) {
                        setState(() {
                          selectedYear = val!;
                        });
                        _loadStats();
                      },
                      decoration: const InputDecoration(labelText: "ปี"),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),
            const Text("📊 ความถี่การบันทึกความฝัน (รายวัน)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: _buildLineChart()),

            const SizedBox(height: 24),
            const Text("🌙 ประเภทความฝัน",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: _buildPieChart(typeCounts)),

            const SizedBox(height: 24),
            const Text("😊 ประเภทอารมณ์",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: _buildPieChart(emotionCounts)),

            // ---------------------- 🔊 ส่วนแสดงผลข้อมูลเสียง ----------------------
            const SizedBox(height: 24),
            const Text("🔉 ค่าเสียงเฉลี่ยเทียบกับประเภทความฝัน",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: _buildBarChart(avgSoundPerType)),

            if (soundDreamInsight.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "🔎 วิเคราะห์: $soundDreamInsight",
                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // กราฟเส้น = ความถี่รายวัน
  Widget _buildLineChart() {
    if (dailyCounts.isEmpty) return const Center(child: Text("ไม่มีข้อมูล"));

    final spots = <FlSpot>[];
    int index = 0;
    dailyCounts.forEach((day, count) {
      spots.add(FlSpot(index.toDouble(), count.toDouble()));
      index++;
    });

    return LineChart(LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          color: Colors.deepPurple,
          dotData: FlDotData(show: true),
        )
      ],
      titlesData: FlTitlesData(show: false),
    ));
  }

  // กราฟวงกลม = ประเภทฝัน / อารมณ์
  Widget _buildPieChart(Map<String, int> dataMap) {
    if (dataMap.isEmpty) return const Center(child: Text("ไม่มีข้อมูล"));

    final sections = <PieChartSectionData>[];
    int i = 0;
    dataMap.forEach((label, value) {
      sections.add(PieChartSectionData(
        value: value.toDouble(),
        title: "$label\n($value)",
        color: Colors.primaries[i % Colors.primaries.length],
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
      ));
      i++;
    });

    return PieChart(PieChartData(sections: sections));
  }

  // กราฟแท่ง = ค่าเสียงเฉลี่ยเทียบกับประเภทความฝัน
  Widget _buildBarChart(Map<String, double> dataMap) {
    if (dataMap.isEmpty) return const Center(child: Text("ไม่มีข้อมูลเสียงในช่วงนี้"));

    final barGroups = <BarChartGroupData>[];
    int index = 0;
    dataMap.forEach((label, value) {
      barGroups.add(BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: Colors.deepPurple,
            width: 18,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
        showingTooltipIndicators: [0],
      ));
      index++;
    });

    return BarChart(BarChartData(
      barGroups: barGroups,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 30),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final labels = dataMap.keys.toList();
              if (value.toInt() < 0 || value.toInt() >= labels.length) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(labels[value.toInt()],
                    style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: false),
    ));
  }
}
