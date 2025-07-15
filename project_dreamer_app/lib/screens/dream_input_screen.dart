import 'package:flutter/material.dart';

class DreamInputScreen  extends StatefulWidget{
  const DreamInputScreen({super.key});

  @override
  State<DreamInputScreen> createState() => _DreamInputScreeState();
}

class _DreamInputScreeState extends State<DreamInputScreen>{
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();

  String? selectedType;
  String? selectedEmotion;
  String selectedPrediction = 'AI';

  final List<String> dreamTypes = ['Recurring dream','Epic dream','Healing dream','Nightmare','Prophetic dream','Lucid Dream'];
  final List<String> emotions = ['กลัว', 'เศร้า', 'ตื่นเต้น', 'โกรธ'];

  @override
  Widget build(BuildContext context){
    final selectedDate = ModalRoute.of(context)!.settings.arguments as DateTime;
    return Scaffold(
      appBar: AppBar(
        title: Text('บันทึกความฝัน ของวันที่ (${selectedDate.day}/${selectedDate.month}/${selectedDate.year})', style: TextStyle(color: Colors.white),),
        centerTitle: true,
        leading: BackButton(color: Colors.deepPurple),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ชื่อเรื่องความฝัน', style: TextStyle(fontSize: 16)),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  hintText: 'พิมพ์ชื่อเรื่องความฝัน...',
                  filled: true,
                  fillColor: Color(0xFFF5F5FF),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
              const SizedBox(height: 16),
              const Text('ภาพความฝัน'),
              Container(
                height: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('ภาพจาก AI จะแสดงที่นี่..'),),
              ),
                const SizedBox(height: 16),

                const Text('เนื้อหาความฝัน'),
                TextField(
                  controller: _content,
                  maxLength: null,
                  decoration: const InputDecoration(
                    hintText: 'กรอกความฝันของคุณ...',
                    filled: true,
                    fillColor: Color(0xFFF5F5FF),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
                const SizedBox(height: 16,),

                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: dreamTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  decoration: const InputDecoration(labelText: 'ประเภทความฝัน'),
                  onChanged: (value) => setState(() => selectedType = value),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: selectedEmotion,
                  items: emotions.map((emo) => DropdownMenuItem(value: emo, child: Text(emo))).toList(),
                  decoration: const InputDecoration(labelText: 'ความรู้สึกในความฝัน'),
                  onChanged: (value) => setState(()=> selectedEmotion = value),
                ),
                const SizedBox(height: 16),

                const Text('เลือกวิธีการทำนาย'),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: const Text('AI'),
                        value: 'AI',
                        groupValue: selectedPrediction, 
                        onChanged: (value) => setState(() => selectedPrediction = value!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: const Text('ตำราโหราศาสตร์ไทย'), 
                        value: 'astro', 
                        groupValue: selectedPrediction, 
                        onChanged: (value) => setState(() => selectedPrediction = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (){
                      // TODO: บันทึกข้อมูล
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('บันทึกความฝัน', style: TextStyle(fontSize: 16, color: Colors.white),),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}