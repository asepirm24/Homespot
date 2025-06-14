import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DetailScreen extends StatefulWidget {
  final String postId;

  const DetailScreen({super.key, required this.postId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Map<String, dynamic>? postData;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isLiked = false;
  int likeCount = 0;
  final TextEditingController commentController = TextEditingController();
  List<QueryDocumentSnapshot> comments = [];

  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    fetchPostAndUserData();
  }

  Future<void> fetchPostAndUserData() async {
    final postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();

    if (postDoc.exists) {
      postData = postDoc.data();
      final userId = postData!['userId'];
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        userData = userDoc.data();
      }

      final likes = List<String>.from(postData!['likes'] ?? []);
      isLiked = currentUserId != null && likes.contains(currentUserId);
      likeCount = likes.length;

      final commentSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();
      comments = commentSnapshot.docs;
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> toggleLike() async {
    if (currentUserId == null) return;
    final docRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final postDoc = await docRef.get();
    final likes = List<String>.from(postDoc.data()?['likes'] ?? []);

    if (likes.contains(currentUserId)) {
      likes.remove(currentUserId);
      isLiked = false;
    } else {
      likes.add(currentUserId!);
      isLiked = true;
    }

    likeCount = likes.length;

    await docRef.update({'likes': likes});
    setState(() {});
  }

  Future<void> submitComment() async {
    final text = commentController.text.trim();
    if (text.isEmpty || currentUserId == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    final user = userDoc.data();

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'text': text,
      'fullName': user['fullName'] ?? '',
      'photoBase64': user['photoBase64'] ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    });

    commentController.clear();
    fetchPostAndUserData();
  }

  Future<void> openMap(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka Google Maps')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Detail Properti')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final images = List<String>.from(postData?['images'] ?? []);
    final specsMap = Map<String, String>.from(postData?['specs'] ?? {});
    final facilities = List<String>.from(postData?['facilities'] ?? []);
    final createdAt = DateTime.tryParse(postData?['createdAt'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('d MMMM yyyy', 'id').format(createdAt);
    final location = postData?['location'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] as num?)?.toDouble();
    final lon = (location?['longitude'] as num?)?.toDouble();


    return Scaffold(
      appBar: AppBar(title: Text('Detail Properti')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (images.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return Image.memory(base64Decode(images[index]), fit: BoxFit.cover);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          postData?['title'] ?? '',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (userData != null && userData!['photoBase64'] != null)
                    CircleAvatar(
                      backgroundImage: MemoryImage(base64Decode(userData!['photoBase64'])),
                      radius: 20,
                    ),
                  if (userData != null) ...[
                    SizedBox(width: 8),
                    Text(userData!['fullName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                  Spacer(),
                  IconButton(
                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                    onPressed: toggleLike,
                  ),
                  Text(likeCount.toString()),
                ],
              ),
            ),

            Card(
              margin: EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(child: Text(postData?['address'] ?? '-')),
                    IconButton(
                      icon: Icon(Icons.location_on),
                      onPressed: () {
                        final location = postData?['location'] as Map<String, dynamic>?;
                        final lat = (location?['latitude'] as num?)?.toDouble();
                        final lon = (location?['longitude'] as num?)?.toDouble();
                        if (lat != null && lon != null) {
                          openMap(lat, lon);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lokasi tidak tersedia')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            Card(
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(postData?['availability'] ?? '', style: TextStyle(color: Colors.green)),
                    Text(postData?['propertyType'] ?? ''),
                    Text(f.format(postData?['price'] ?? 0), style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(postData?['description'] ?? ''),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spesifikasi:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...specsMap.entries.map((e) => Text('• ${e.key}: ${e.value}')).toList(),
                ],
              ),
            ),
            SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fasilitas:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...facilities.map((e) => Text('• $e')).toList(),
                ],
              ),
            ),
            SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Komentar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 12),
                  ...comments.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final createdAtStr = data['createdAt'] as String?;
                    final commentTime = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();
                    final now = DateTime.now();
                    final difference = now.difference(commentTime);

                    String timeAgo;
                    if (difference.inMinutes < 1) {
                      timeAgo = 'baru saja';
                    } else if (difference.inMinutes < 60) {
                      timeAgo = '${difference.inMinutes} menit lalu';
                    } else if (difference.inHours < 24) {
                      timeAgo = '${difference.inHours} jam lalu';
                    } else if (difference.inDays < 30) {
                      timeAgo = '${difference.inDays} hari lalu';
                    } else if (difference.inDays < 365) {
                      timeAgo = '${(difference.inDays / 30).floor()} bulan lalu';
                    } else {
                      timeAgo = '${(difference.inDays / 365).floor()} tahun lalu';
                    }

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          data['photoBase64'] != null
                              ? CircleAvatar(
                            backgroundImage: MemoryImage(base64Decode(data['photoBase64'])),
                            radius: 16,
                          )
                              : CircleAvatar(child: Icon(Icons.person), radius: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data['fullName'] ?? '',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      timeAgo,
                                      style: TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(data['text'] ?? '', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (currentUserId != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: 'Tulis komentar...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: TextStyle(fontSize: 13),
                        ),
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: submitComment,
                            style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                            child: Text('Kirim', style: TextStyle(fontSize: 13)),
                          ),
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
  }
}
