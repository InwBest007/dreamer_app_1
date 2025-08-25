import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class DreamStatScreen extends StatefulWidget {
  const DreamStatScreen({super.key});

  @override
  State<DreamStatScreen> createState() => _DreamStatScreenState();
}

class _DreamStatScreenState extends State<DreamStatScreen> {
  Map<String, int> typeCounts = {};
  Map<String, int> emotionCounts = {};
  Map<String, int> dailyCounts = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final snapshot =
        await FirebaseFirestore.instance.collection("dreamEntries").get();

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

    setState(() {
      typeCounts = tempTypeCounts;
      emotionCounts = tempEmotionCounts;
      dailyCounts = tempDailyCounts;
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
          ],
        ),
      ),
    );
  }

  // 📈 กราฟเส้น = ความถี่รายวัน
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

  // 🥧 กราฟวงกลม = ประเภทฝัน / อารมณ์
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
}
