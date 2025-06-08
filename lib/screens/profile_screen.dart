import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import 'detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String fullName = '';
  String description = '';
  String? base64Image;
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

    setState(() {
      fullName = userDoc.data()?['fullName'] ?? '';
      description = userDoc.data()?['description'] ?? '';
      base64Image = userDoc.data()?['photoBase64'];
      userPosts = postSnapshot.docs;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text("Profil")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: base64Image != null
                      ? MemoryImage(base64Decode(base64Image!))
                      : const AssetImage('assets/images/dummy_profile.png') as ImageProvider,
                ),
                const SizedBox(height: 20),
                Text(fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Postingan Saya",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                if (userPosts.isEmpty)
                  const Text("Belum ada postingan."),
                ...userPosts.map((doc) {
                  final data = doc.data()!;
                  final title = data['title'] ?? '';
                  final description = data['description'] ?? '';
                  final imageBase64 = data['image'];
                  final createdAtStr = data['createdAt'];
                  final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
                  final latitude = data['latitude'] ?? 0.0;
                  final longitude = data['longitude'] ?? 0.0;
                  final heroTag = 'profile-post-${createdAt.millisecondsSinceEpoch}';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
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
                              viewedUserId: currentUserId,
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
                                Text(
                                  "${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
