import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<String> base64Images = [];
  String fullName = '';
  String availability = 'Tersedia';
  String propertyType = 'Rumah';
  double? latitude;
  double? longitude;
  int? price;
  Map<String, String> domisili = {'kecamatan': '', 'kota': '', 'provinsi': ''};
  Map<String, bool> facilities = {};
  Map<String, TextEditingController> specs = {};

  final titleController = TextEditingController();
  final addressController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _initializeSpecControllers();
  }

  void _initializeSpecControllers() {
    specs = {
      'Jumlah kamar tidur': TextEditingController(),
      'Jumlah kamar mandi': TextEditingController(),
      'Luas bangunan (m²)': TextEditingController(),
      'Ukuran kamar (m²)': TextEditingController(),
      'Jumlah kamar tersedia': TextEditingController(),
      'Lantai ke-': TextEditingController(),
      'Luas unit (m²)': TextEditingController(),
    };
  }

  Future<void> _loadUserInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          fullName = doc['fullName'] ?? '';
        });
      }
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
    });

    final placemarks = await placemarkFromCoordinates(latitude!, longitude!);
    final place = placemarks.first;

    final kecamatan = place.subLocality?.isNotEmpty == true ? place.subLocality! : 'Tidak diketahui';
    final kota = place.locality?.isNotEmpty == true ? place.locality! : place.subAdministrativeArea ?? 'Tidak diketahui';
    final provinsi = place.administrativeArea ?? 'Tidak diketahui';

    setState(() {
      addressController.text = '${place.street}, $kecamatan, $kota, $provinsi, ${place.country}';
      domisili = {
        'kecamatan': kecamatan,
        'kota': kota,
        'provinsi': provinsi,
      };
    });
  }

  Future<void> _pickImages() async {
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      for (var image in pickedFiles) {
        final compressed = await FlutterImageCompress.compressWithFile(
          image.path,
          minWidth: 600,
          minHeight: 600,
          quality: 80,
        );
        if (compressed != null) {
          base64Images.add(base64Encode(compressed));
        }
      }
      setState(() {});
    }
  }

  Future<void> _pickCameraImage() async {
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final compressed = await FlutterImageCompress.compressWithFile(
        image.path,
        minWidth: 600,
        minHeight: 600,
        quality: 80,
      );
      if (compressed != null) {
        setState(() {
          base64Images.add(base64Encode(compressed));
        });
      }
    }
  }

  List<String> getFacilitiesByType(String type) {
    switch (type) {
      case 'Rumah':
        return ['Furnished', 'AC', 'Garasi', 'Taman', 'Dapur'];
      case 'Kost':
        return ['Kamar mandi dalam', 'Wi-Fi', 'AC', 'Untuk putra', 'Untuk putri'];
      case 'Apartemen':
        return ['Furnished', 'Lift', 'AC', 'Kolam renang', 'Parkir'];
      case 'Kontrakan':
        return ['Dapur', 'Parkir motor', 'AC', 'Terpisah dari pemilik', 'Halaman kecil'];
      default:
        return [];
    }
  }

  List<String> getSpecFieldsByType(String type) {
    switch (type) {
      case 'Rumah':
        return ['Jumlah kamar tidur', 'Jumlah kamar mandi', 'Luas bangunan (m²)'];
      case 'Kost':
        return ['Ukuran kamar (m²)', 'Jumlah kamar tersedia'];
      case 'Apartemen':
        return ['Lantai ke-', 'Luas unit (m²)', 'Jumlah kamar tidur'];
      case 'Kontrakan':
        return ['Jumlah kamar tidur', 'Jumlah kamar mandi'];
      default:
        return [];
    }
  }

  Future<void> _generateDescriptionWithAI({
    required String address,
    required List<String> facilities,
    required Map<String, String> specs,
  }) async {
    setState(() => _isGenerating = true);
    try {
      const apiKey = 'AIzaSyBlKsOM5jOf2v7jNctojKJ-KtHkBJjEuIs';
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                "Buat deskripsi menarik untuk iklan properti berdasarkan data berikut:\n\n"
                    "Alamat: $address\n"
                    "Fasilitas: ${facilities.join(', ')}\n"
                    "Spesifikasi: ${specs.entries.map((e) => '${e.key}: ${e.value}').join(', ')}\n\n"
                    "Tulis deskripsi dalam 3 kalimat menggunakan bahasa persuasif."
              }
            ]
          }
        ]
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        if (text != null && text.isNotEmpty) {
          setState(() {
            descriptionController.text = text.trim();
          });
        }
      } else {
        debugPrint('Request failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('AI error: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _submitPost() async {
    final user = _auth.currentUser;
    if (user == null || !_formKey.currentState!.validate()) return;

    if (base64Images.isEmpty || latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mohon lengkapi semua data!')));
      return;
    }

    final selectedFacilities = facilities.entries.where((e) => e.value).map((e) => e.key).toList();
    final selectedSpecsMap = <String, String>{};
    for (var key in getSpecFieldsByType(propertyType)) {
      selectedSpecsMap[key] = specs[key]?.text ?? '';
    }

    final doc = {
      "title": titleController.text,
      "address": addressController.text,
      "availability": availability,
      "createdAt": DateTime.now().toIso8601String(),
      "domisili": domisili,
      "facilities": selectedFacilities,
      "fullName": fullName,
      "location": {"latitude": latitude, "longitude": longitude},
      "price": price,
      "specs": selectedSpecsMap,
      "userId": user.uid,
      "images": base64Images,
      "description": descriptionController.text,
      "propertyType": propertyType,
    };

    try {
      final docRef = await FirebaseFirestore.instance.collection('posts').add(doc);
      await docRef.update({'postId': docRef.id});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post berhasil ditambahkan')));
      _resetForm();
    } catch (e) {
      debugPrint('Error submit: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengunggah post')));
    }
  }

  void _resetForm() {
    setState(() {
      titleController.clear();
      addressController.clear();
      descriptionController.clear();
      priceController.clear();
      base64Images.clear();
      facilities.clear();
      for (var c in specs.values) {
        c.clear();
      }
      price = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: Text('Tambah Post')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ElevatedButton(onPressed: _pickImages, child: Text('Galeri')),
                  SizedBox(width: 8),
                  ElevatedButton(onPressed: _pickCameraImage, child: Text('Kamera')),
                ],
              ),
              Wrap(
                children: base64Images.asMap().entries.map((entry) {
                  final index = entry.key;
                  final img = entry.value;
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.memory(base64Decode(img), height: 80),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => base64Images.removeAt(index));
                        },
                        child: Icon(Icons.close, color: Colors.red),
                      ),
                    ],
                  );
                }).toList(),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Judul'),
                validator: (val) => val == null || val.isEmpty ? 'Judul wajib diisi' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'Alamat'),
                validator: (val) => val == null || val.isEmpty ? 'Alamat wajib diisi' : null,
              ),
              SizedBox(height: 8),
              ElevatedButton(onPressed: _getLocation, child: Text('Gunakan Lokasi Saat Ini')),
              SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Harga sewa perbulan (Rp)'),
                validator: (val) => val == null || val.isEmpty ? 'Harga wajib diisi' : null,
                onChanged: (val) {
                  final numeric = val.replaceAll(RegExp(r'[^0-9]'), '');
                  price = int.tryParse(numeric) ?? 0;
                  priceController.value = TextEditingValue(
                    text: f.format(price),
                    selection: TextSelection.collapsed(offset: f.format(price).length),
                  );
                },
              ),
              SizedBox(height: 12),
              DropdownButtonFormField(
                value: propertyType,
                items: ['Rumah', 'Kost', 'Apartemen', 'Kontrakan']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => propertyType = val!),
                decoration: InputDecoration(labelText: 'Jenis Properti'),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField(
                value: availability,
                items: ['Tersedia', 'Dipakai']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => availability = val!),
                decoration: InputDecoration(labelText: 'Status'),
              ),
              SizedBox(height: 12),
              ...getFacilitiesByType(propertyType).map((e) => CheckboxListTile(
                title: Text(e),
                value: facilities[e] ?? false,
                onChanged: (val) => setState(() => facilities[e] = val!),
              )),
              ...getSpecFieldsByType(propertyType).map((e) => TextFormField(
                controller: specs[e],
                decoration: InputDecoration(labelText: e),
              )),
              SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Deskripsi',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.multiline,
                minLines: 3,
                maxLines: 10,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final selectedFacilities = facilities.entries.where((e) => e.value).map((e) => e.key).toList();
                  final selectedSpecs = <String, String>{};
                  for (var key in getSpecFieldsByType(propertyType)) {
                    selectedSpecs[key] = specs[key]?.text ?? '';
                  }
                  _generateDescriptionWithAI(
                    address: addressController.text,
                    facilities: selectedFacilities,
                    specs: selectedSpecs,
                  );
                },
                child: _isGenerating ? CircularProgressIndicator(color: Colors.white) : Text('Generate Deskripsi AI'),
              ),
              SizedBox(height: 16),
              ElevatedButton(onPressed: _submitPost, child: Text('Unggah Post')),
            ],
          ),
        ),
      ),
    );
  }
}
