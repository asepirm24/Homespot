import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:homespot/screens/detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final TextEditingController _searchController = TextEditingController();

  String selectedCategory = 'All';
  String selectedSort = 'Tanggal Terbaru';

  final List<String> categories = ['All', 'Rumah', 'Kos', 'Apartemen', 'Ruko'];
  final List<String> sortOptions = [
    'Tanggal Terbaru',
    'Tanggal Terlama',
    'Like Terbanyak',
    'Harga Terendah',
    'Harga Tertinggi'
  ];

  Future<String?> getUserPhoto(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.data()?['photoBase64'];
  }

  Future<void> toggleLike(String postId, List likes) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final updatedLikes = likes.contains(uid)
        ? FieldValue.arrayRemove([uid])
        : FieldValue.arrayUnion([uid]);
    await postRef.update({'likes': updatedLikes});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari berdasarkan judul, kota, user...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      return ChoiceChip(
                        label: Text(cat),
                        selected: selectedCategory == cat,
                        onSelected: (_) => setState(() => selectedCategory = cat),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: selectedSort,
                items: sortOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) => setState(() => selectedSort = val ?? 'Tanggal Terbaru'),
              ),
              const SizedBox(width: 10),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('posts').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final allPosts = snapshot.data!.docs;

                var filteredPosts = allPosts.where((doc) {
                  final data = doc.data();
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final kota = (data['domisili']?['kota'] ?? '').toString().toLowerCase();
                  final fullName = (data['fullName'] ?? '').toString().toLowerCase();
                  final query = _searchController.text.toLowerCase();

                  final matchesCategory = selectedCategory == 'All' || data['propertyType'] == selectedCategory;

                  final matchesQuery = title.contains(query) || kota.contains(query) || fullName.contains(query);

                  return matchesCategory && matchesQuery;
                }).toList();

                // Sorting logic
                filteredPosts.sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();
                  final aDate = DateTime.tryParse(aData['createdAt'] ?? '') ?? DateTime.now();
                  final bDate = DateTime.tryParse(bData['createdAt'] ?? '') ?? DateTime.now();
                  final aLikes = (aData['likes'] as List?)?.length ?? 0;
                  final bLikes = (bData['likes'] as List?)?.length ?? 0;
                  final aPrice = (aData['price'] as num?) ?? 0;
                  final bPrice = (bData['price'] as num?) ?? 0;

                  switch (selectedSort) {
                    case 'Tanggal Terbaru':
                      return bDate.compareTo(aDate);
                    case 'Tanggal Terlama':
                      return aDate.compareTo(bDate);
                    case 'Like Terbanyak':
                      return bLikes.compareTo(aLikes);
                    case 'Harga Terendah':
                      return aPrice.compareTo(bPrice);
                    case 'Harga Tertinggi':
                      return bPrice.compareTo(aPrice);
                    default:
                      return bDate.compareTo(aDate);
                  }
                });

                if (filteredPosts.isEmpty) {
                  return const Center(child: Text("Tidak ditemukan hasil."));
                }

                return ListView.builder(
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, i) {
                    final post = filteredPosts[i].data();
                    final id = filteredPosts[i].id;
                    final imgs = (post['images'] as List?)?.cast<String>() ?? [];
                    final likes = (post['likes'] as List?)?.cast<String>() ?? [];
                    final liked = likes.contains(uid);

                    return FutureBuilder<String?>(
                      future: getUserPhoto(post['userId']),
                      builder: (c, snap) {
                        final photo = snap.data;
                        return InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(postId: id),
                            ),
                          ),
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imgs.isNotEmpty)
                                    SizedBox(
                                      height: 120,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: imgs.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                                        itemBuilder: (_, idx) => ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.memory(
                                            base64Decode(imgs[idx]),
                                            width: 160,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    post['domisili']?['kota'] ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    post['title'] ?? '',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rp ${post['price']?.toString() ?? '0'}',
                                    style: const TextStyle(fontSize: 13, color: Colors.green),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      photo != null
                                          ? CircleAvatar(
                                        radius: 14,
                                        backgroundImage: MemoryImage(base64Decode(photo)),
                                      )
                                          : const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 14)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          post['fullName'] ?? '',
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          liked ? Icons.favorite : Icons.favorite_border,
                                          size: 18,
                                          color: liked ? Colors.red : Colors.grey,
                                        ),
                                        onPressed: () => toggleLike(id, likes),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      Text('${likes.length}', style: const TextStyle(fontSize: 15)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

