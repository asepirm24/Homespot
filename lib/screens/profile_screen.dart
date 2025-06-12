import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:homespot/screens/edit_profile_screen.dart';
import 'package:homespot/screens/edit_post_screen.dart';
import 'package:homespot/screens/detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String fullName = '';
  String description = '';
  String? base64Image;
  String domisiliKota = '';
  List<DocumentSnapshot<Map<String, dynamic>>> userPosts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final postSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    final domisiliData = userDoc.data()?['domisili'];
    String kota = '';
    if (domisiliData is Map) {
      kota = domisiliData['kota'] ?? '';
    }

    setState(() {
      fullName = userDoc.data()?['fullName'] ?? '';
      description = userDoc.data()?['description'] ?? '';
      base64Image = userDoc.data()?['photoBase64'];
      domisiliKota = kota;
      userPosts = postSnapshot.docs;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundImage: base64Image != null
                    ? MemoryImage(base64Decode(base64Image!))
                    : const AssetImage('assets/images/dummy_profile.png') as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              fullName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              domisiliKota,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(description, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ).then((_) => loadData());
              },
              child: const Text("Edit Profil"),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const Text(
              "Postingan Saya",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (userPosts.isEmpty) const Text("Belum ada postingan."),
            ...userPosts.map((doc) {
              final data = doc.data()!;
              final images = List<String>.from(data['images'] ?? []);
              final heroTag = 'profile-post-${doc.id}';

              final timestamp = data['createdAt'];
              final createdAt = timestamp is Timestamp
                  ? timestamp.toDate()
                  : DateTime.now();
              final createdAtStr =
              DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(createdAt);

              final likes = List<String>.from(data['likes'] ?? []);
              final likeCount = likes.length;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(postId: doc.id),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (images.isNotEmpty)
                            Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: Image.memory(
                                  base64Decode(images.first),
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
                                  data['title'] ?? '',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  data['description'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  createdAtStr,
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.favorite, size: 16, color: Colors.red),
                                    const SizedBox(width: 4),
                                    Text('$likeCount suka'),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditPostScreen(postId: doc.id),
                            ),
                          ).then((_) => loadData());
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text("Edit Post"),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}