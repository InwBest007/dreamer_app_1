import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArticlesScreen extends StatefulWidget{
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}
class _ArticlesScreenState extends State<ArticlesScreen>{
  String selectedCategory = 'ทั้งหมด';
  String searchText = '';

  List<String> categories = ['ทั้งหมด', ...'กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ'.split('')];

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('บทความคำทำนายความฝัน'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child:  Row(
              children: [
                const Text('หมวด: '),
                DropdownButton<String>(
                  value: selectedCategory,
                  items: categories.map((cat){
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    ); 
                  }).toList(),
                  onChanged: (val){
                    setState(() {
                      selectedCategory = val!;
                    });
                  },
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TextField(
                    onChanged: (val){
                      setState(() {
                        searchText = val.trim();
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาบทความ..',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('dream_articles_v2').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if(!snapshot.hasData){
                    return const Center(child:  CircularProgressIndicator());
                  }
                  final articles = snapshot.data!.docs.where((doc) {
                    final category = doc['category'] ?? '';
                    final title = doc['title']?.toString().toLowerCase() ?? '';
                    final desc = doc['description']?.toString().toLowerCase() ?? '';
                    final search = searchText.toLowerCase();

                    final matchCategory = selectedCategory == 'ทั้งหมด' || category == selectedCategory;
                    final matchSearch = title.contains(search) || desc.contains(search);

                    return matchCategory && matchSearch;
                  }).toList();
                  if(articles.isEmpty){
                    return const Center(child: Text('ไม่พบบทความ...'),);
                  }
                  return ListView.builder(
                  itemCount: articles.length,
                    itemBuilder: (context, index){
                      final article = articles[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: article['imagePath'] != null && article['imagePath'].toString().isNotEmpty
                              ? Image.network(
                                article['imagePath'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              )
                              : null,
                          title: Text(article['title'] ?? 'ไม่มีชื่อ'),
                          subtitle: Text(
                            article['description'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: (){
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArticleDetailScreen(
                                  title: article['title'] ?? '',
                                  content: article['content'] ?? '',
                                  imageUrl: article['imagePath'] ?? '',
                                )
                              ),
                            );
                          },
                        ),
                      );
                    },           
                  );
                },
              )
            ),
        ],
      ),
    );
  }
}
class ArticleDetailScreen extends StatelessWidget {
  final String title;
  final String content;
  final String imageUrl;

  const ArticleDetailScreen({
    super.key,
    required this.title,
    required this.content,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text(title),  
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if(imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 16),
            Text(
              content,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}