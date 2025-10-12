import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  String selectedCategory = 'ทั้งหมด';
  String searchText = '';

  List<String> categories = [
    'ทั้งหมด',
    ...'กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ'.split(''),
  ];

  Future<void> fetchAndUploadSanookArticles() async {
    const feedUrl = "https://rssfeeds.sanook.com/rss/feeds/sanook/health.xml";
    try {
      final response = await http.get(Uri.parse(feedUrl));
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        int addedCount = 0;

        String extractImage(String desc) {
          final exp = RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false);
          final match = exp.firstMatch(desc);
          return match?.group(1) ?? '';
        }

        for (var item in items) {
          final title = item.findElements('title').first.text.trim();
          final link = item.findElements('link').first.text.trim();
          final description = item.findElements('description').isNotEmpty
              ? item.findElements('description').first.text.trim()
              : '';

          String imageUrl = extractImage(description);
          if (imageUrl.isEmpty) imageUrl = '';

          final exists = await FirebaseFirestore.instance
              .collection('dream_articles_v2')
              .where('title', isEqualTo: title)
              .get();

          if (exists.docs.isEmpty) {
            await FirebaseFirestore.instance
                .collection('dream_articles_v2')
                .add({
                  'title': title,
                  'description': description,
                  'category': 'ส',
                  'imagePath': imageUrl,
                  'link': link,
                  'createdAt': DateTime.now(),
                });
            addedCount++;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ เพิ่มบทความใหม่ $addedCount รายการ')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching articles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B5BE0),
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'บทความคำทำความฝัน🌙',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download, color: Colors.white),
            tooltip: "ดึงบทความจาก Sanook",
            onPressed: fetchAndUploadSanookArticles,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5B5BE0), Color(0xFF9FA8DA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'หมวด:',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    dropdownColor: const Color(0xFF5B5BE0),
                    value: selectedCategory,
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(
                          cat,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedCategory = val!),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) =>
                          setState(() => searchText = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาบทความ...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('dream_articles_v2')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final articles = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final cat = data['category'] ?? '';
                    final title = data['title']?.toString().toLowerCase() ?? '';
                    final desc =
                        data['description']?.toString().toLowerCase() ?? '';
                    final search = searchText.toLowerCase();
                    return (selectedCategory == 'ทั้งหมด' ||
                            cat == selectedCategory) &&
                        (title.contains(search) || desc.contains(search));
                  }).toList();

                  if (articles.isEmpty) {
                    return const Center(
                      child: Text(
                        'ไม่พบบทความ...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: articles.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, i) {
                      final data = articles[i].data() as Map<String, dynamic>;
                      final imageUrl = (data['imagePath'] ?? '').toString();

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8C9EFF), Color(0xFF5B5BE0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(2, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.article_outlined,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                          ),
                          title: Text(
                            data['title'] ?? 'ไม่มีชื่อ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            (data['description'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArticleDetailScreen(
                                title: data['title'] ?? '',
                                content: data['content'] ?? '',
                                imageUrl: imageUrl,
                                link: data['link'] ?? '',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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

class ArticleDetailScreen extends StatelessWidget {
  final String title;
  final String content;
  final String imageUrl;
  final String link;

  const ArticleDetailScreen({
    super.key,
    required this.title,
    required this.content,
    required this.imageUrl,
    required this.link,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B5BE0),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1A1A1A),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            if (link.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B5BE0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.open_in_new, color: Colors.white),
                label: const Text(
                  'อ่านต่อบน Sanook',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  final url = Uri.parse(link);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
