import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:homespot/screens/full_image_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.imageBase64,
    required this.description,
    required this.title,
    required this.createdAt,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    required this.heroTag,
    required this.currentUserId,
    required this.viewedUserId,
  });

  final String imageBase64;
  final String description;
  final String title;
  final DateTime createdAt;
  final String fullName;
  final double latitude;
  final double longitude;
  final String heroTag;
  final String currentUserId;
  final String viewedUserId;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> openMap() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}',
    );
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka Google Maps')),
      );
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.heroTag) // Gunakan heroTag sebagai ID post
          .collection('comments')
          .add({
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': widget.currentUserId,
      });
      _commentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAtFormatted = DateFormat('dd MMMM yyyy, HH:mm').format(widget.createdAt);

    return Scaffold(
      appBar: AppBar(title: const Text("Detail Laporan")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: widget.heroTag,
                  child: Image.memory(
                    base64Decode(widget.imageBase64),
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageScreen(
                            imageBase64: widget.imageBase64,
                          ),
                        ),
                      );
                    },
                    tooltip: 'Lihat gambar penuh',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 20, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(widget.fullName, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 20, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(createdAtFormatted, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(widget.description, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: openMap,
                    icon: const Icon(Icons.map),
                    label: const Text("Lihat di Google Maps"),
                  ),
                  const Divider(height: 32),
                  const Text('Komentar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Komentar dengan foto profil base64
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.heroTag)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text('Belum ada komentar.', style: TextStyle(color: Colors.grey));
                      }

                      final comments = snapshot.data!.docs;

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final text = comment['text'] ?? '';
                          final userId = comment['userId'] ?? '';

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                            builder: (context, userSnapshot) {
                              if (userSnapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 50,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                                // Kalau user tidak ditemukan
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.comment, size: 20, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(text)),
                                    ],
                                  ),
                                );
                              }

                              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                              final userFullName = userData['fullName'] ?? 'User';
                              final userPhotoBase64 = userData['photoBase64'] ?? '';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    userPhotoBase64.isNotEmpty
                                        ? CircleAvatar(
                                      radius: 16,
                                      backgroundImage: MemoryImage(base64Decode(userPhotoBase64)),
                                    )
                                        : const CircleAvatar(
                                      radius: 16,
                                      child: Icon(Icons.person, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userFullName,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(text),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Tulis komentar...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _addComment,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
