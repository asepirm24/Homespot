import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:homespot/screens/add_post_screen.dart';
import 'package:homespot/screens/detail_screen.dart';
import 'package:homespot/screens/setting_screen.dart';
import 'package:homespot/screens/sign_in_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Rumah', 'Kost', 'Apartemen', 'Kontrakan'];
  late ScrollController _scrollController;
  bool showTrending = true;
  double _lastOffset = 0;
  Timer? _debounce;
  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> trendingFuture;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    trendingFuture = getTrendingPosts(); // Cache trending post
  }

  void _onScroll() {
    final offset = _scrollController.offset;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (offset > _lastOffset && showTrending) {
        setState(() => showTrending = false);
      } else if (offset < _lastOffset && !showTrending) {
        setState(() => showTrending = true);
      }
      _lastOffset = offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<String?> getUserPhoto(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.data()?['photoBase64'];
  }

  Future<void> toggleLike(String postId, List likes, String userId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final updatedLikes = likes.contains(userId)
        ? FieldValue.arrayRemove([userId])
        : FieldValue.arrayUnion([userId]);
    await postRef.update({'likes': updatedLikes});
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getTrendingPosts() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userDomisili = userDoc.data()?['domisili']?['kota'];
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

    final query = await FirebaseFirestore.instance
        .collection('posts')
        .where('createdAt', isGreaterThanOrEqualTo: oneMonthAgo.toIso8601String())
        .where('domisili.kota', isEqualTo: userDomisili)
        .get();

    var docs = query.docs;
    if (selectedCategory != 'All') {
      docs = docs.where((doc) => doc['propertyType'] == selectedCategory).toList();
    }

    docs.sort((a, b) => (b['likes']?.length ?? 0).compareTo(a['likes']?.length ?? 0));
    return docs.take(5).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getPostsStream() {
    final baseQuery = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true);

    if (selectedCategory == 'All') {
      return baseQuery.snapshots();
    } else {
      return baseQuery.where('propertyType', isEqualTo: selectedCategory).snapshots();
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 10 / 5,
            child: Image.asset('assets/images/homescreen.png', fit: BoxFit.cover),
          ),
          SizedBox(
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
                  onSelected: (_) => setState(() {
                    selectedCategory = cat;
                    trendingFuture = getTrendingPosts(); // refresh on category change
                  }),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              future: trendingFuture,
              builder: (context, trendingSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _getPostsStream(),
                  builder: (context, postSnapshot) {
                    if (!postSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final posts = postSnapshot.data!.docs;

                    return ListView(
                      controller: _scrollController,
                      children: [
                        if (showTrending &&
                            trendingSnapshot.connectionState == ConnectionState.done &&
                            trendingSnapshot.hasData &&
                            trendingSnapshot.data!.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text("Trending Post", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: trendingSnapshot.data!.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final p = trendingSnapshot.data![i].data();
                                final id = trendingSnapshot.data![i].id;
                                final image = (p['images'] as List?)?.cast<String>().firstOrNull;
                                final title = p['title'] ?? '';
                                final likes = (p['likes'] as List?)?.length ?? 0;
                                final date = DateFormat('d MMM yyyy', 'id').format(
                                  DateTime.tryParse(p['createdAt']) ?? DateTime.now(),
                                );
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(postId: id)));
                                  },
                                  child: Container(
                                    width: 160,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Theme.of(context).cardColor,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (image != null)
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                            child: Image.memory(
                                              base64Decode(image),
                                              height: 100,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                              Text("$likes suka", style: const TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text("Terbaru di sekitarmu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        ...posts.map((doc) {
                          final p = doc.data();
                          final id = doc.id;
                          final imgs = (p['images'] as List?)?.cast<String>() ?? [];
                          final likes = (p['likes'] as List?)?.cast<String>() ?? [];
                          final liked = likes.contains(uid);
                          final createdAt = DateTime.tryParse(p['createdAt']) ?? DateTime.now();
                          final formattedDate = DateFormat('d MMMM yyyy', 'id').format(createdAt);
                          return FutureBuilder<String?>(
                            future: getUserPhoto(p['userId']),
                            builder: (context, snap) {
                              final photo = snap.data;
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DetailScreen(postId: id)),
                                  ),
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
                                              itemBuilder: (context, idx) => ClipRRect(
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
                                        Text(p['domisili']?['kota'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 4),
                                        Text(p['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        Text('Rp ${p['price']?.toString() ?? '0'}', style: const TextStyle(fontSize: 13, color: Colors.green)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            photo != null
                                                ? CircleAvatar(radius: 14, backgroundImage: MemoryImage(base64Decode(photo)))
                                                : const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 14)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                p['fullName'] ?? '',
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
                                              onPressed: () => toggleLike(id, likes, uid),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                            Text('${likes.length}', style: const TextStyle(fontSize: 15)),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ],
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
