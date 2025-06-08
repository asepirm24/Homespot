import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:homespot/screens/detail_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoriteScreen> {
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _getFavoritePosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final favDoc = await FirebaseFirestore.instance.collection('favorites').doc(user.uid).get();
    final likedPostIds = List<String>.from(favDoc.data()?['likedPostIds'] ?? []);

    if (likedPostIds.isEmpty) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where(FieldPath.documentId, whereIn: likedPostIds)
        .get();

    return snapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Favorit')),
      body: FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: _getFavoritePosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada post yang difavoritkan."));
          }

          final posts = snapshot.data!;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final data = posts[index].data()!;
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
              final heroTag = 'fav-image-${createdAt.millisecondsSinceEpoch}';

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
                            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(fullName, style: const TextStyle(fontStyle: FontStyle.italic)),
                                Text("${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}"),
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
      ),
    );
  }
}

