import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:homespot/screens/detail_screen.dart';
import 'package:homespot/screens/setting_screen.dart';
import 'package:homespot/screens/add_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>> _getPostsStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _formatDateTime(String createdAtStr) {
    final dateTime = DateTime.parse(createdAtStr);
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _toggleFavorite(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final favRef = FirebaseFirestore.instance.collection('favorites').doc(user.uid);
    final doc = await favRef.get();

    List favorites = [];

    if (doc.exists && doc.data()!.containsKey('likedPostIds')) {
      favorites = List<String>.from(doc.data()!['likedPostIds']);
    }

    if (favorites.contains(postId)) {
      favorites.remove(postId);
    } else {
      favorites.add(postId);
    }

    await favRef.set({'likedPostIds': favorites});
  }

  Future<bool> _isFavorite(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final favDoc = await FirebaseFirestore.instance.collection('favorites').doc(user.uid).get();
    final likedPostIds = List<String>.from(favDoc.data()?['likedPostIds'] ?? []);

    return likedPostIds.contains(postId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Homespot"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: StreamBuilder(
          stream: _getPostsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final posts = snapshot.data!.docs;

            if (posts.isEmpty) {
              return const Center(
                child: Text("Belum ada laporan tersedia."),
              );
            }

            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final data = posts[index].data();
                final postId = posts[index].id;
                final imageBase64 = data['image'];
                final description = data['description'] ?? '';
                final title = data['title'] ?? '';
                final createdAtStr = data['createdAt'];
                final fullName = data['fullName'] ?? 'Anonim';
                final latitude = data['latitude'] ?? 0.0;
                final longitude = data['longitude'] ?? 0.0;
                final userId = data['userId'] ?? '';
                final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                final createdAt = DateTime.parse(createdAtStr);

                String heroTag = 'homespot-image-${createdAt.millisecondsSinceEpoch}';

                return FutureBuilder<bool>(
                  future: _isFavorite(postId),
                  builder: (context, snapshot) {
                    final isFavorite = snapshot.data ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(
                                imageBase64: imageBase64,
                                description: description,
                                title: title,
                                createdAt: createdAt,
                                fullName: fullName,
                                latitude: latitude,
                                longitude: longitude,
                                heroTag: heroTag,
                                currentUserId: currentUserId,
                                viewedUserId: userId,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: Image.memory(
                                  base64Decode(imageBase64),
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        fullName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      Text(
                                        _formatDateTime(createdAtStr),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isFavorite ? Icons.favorite : Icons.favorite_border,
                                          color: isFavorite ? Colors.red : null,
                                        ),
                                        onPressed: () async {
                                          await _toggleFavorite(postId);
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPostScreen()),
          );
        },
        child: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
