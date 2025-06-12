import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class EditPostScreen extends StatefulWidget {
  final String postId;

  const EditPostScreen({super.key, required this.postId});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  List<String> base64Images = [];
  Map<String, bool> facilities = {};
  Map<String, TextEditingController> specs = {};

  final titleController = TextEditingController();
  final addressController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();

  String availability = 'Tersedia';
  String propertyType = 'Rumah';
  int price = 0;
  Map<String, String> domisili = {};
  double? latitude;
  double? longitude;
  String fullName = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _initializeSpecControllers();
    _loadPostData();
  }

  void _initializeSpecControllers() {
    final fields = getSpecFieldsByType(propertyType);
    for (var field in fields) {
      specs[field] = TextEditingController();
    }
  }

  List<String> getFacilitiesByType(String type) {
    switch (type) {
      case 'Rumah':
      case 'Apartemen':
        return ['AC', 'Kolam Renang', 'Keamanan 24 Jam', 'Garasi'];
      case 'Kost':
        return ['WiFi', 'Kamar Mandi Dalam', 'Dapur Bersama'];
      default:
        return [];
    }
  }

  List<String> getSpecFieldsByType(String type) {
    switch (type) {
      case 'Rumah':
      case 'Apartemen':
        return ['Kamar Tidur', 'Kamar Mandi', 'Luas Bangunan'];
      case 'Kost':
        return ['Luas Kamar', 'Fasilitas Kamar'];
      default:
        return [];
    }
  }

  Future<void> _loadUserInfo() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    setState(() {
      fullName = userDoc['fullName'] ?? '';
    });
  }

  Future<void> _loadPostData() async {
    final doc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        titleController.text = data['title'] ?? '';
        addressController.text = data['address'] ?? '';
        descriptionController.text = data['description'] ?? '';
        price = data['price'];
        priceController.text = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(price);
        availability = data['availability'] ?? 'Tersedia';
        propertyType = data['propertyType'] ?? 'Rumah';
        base64Images = List<String>.from(data['images'] ?? []);
        domisili = Map<String, String>.from(data['domisili'] ?? {});
        latitude = data['location']?['latitude'];
        longitude = data['location']?['longitude'];
        fullName = data['fullName'] ?? '';

        // Init spec fields and values
        _initializeSpecControllers();
        final loadedSpecs = Map<String, String>.from(data['specs'] ?? {});
        for (var key in specs.keys) {
          specs[key]?.text = loadedSpecs[key] ?? '';
        }

        // Init facilities
        final facilityList = List<String>.from(data['facilities'] ?? []);
        facilities = {
          for (var f in getFacilitiesByType(propertyType)) f: facilityList.contains(f)
        };
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      setState(() {
        base64Images.add(base64Image);
      });
    }
  }

  void _updatePost() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedFacilities = facilities.entries.where((e) => e.value).map((e) => e.key).toList();
    final selectedSpecsMap = {
      for (var entry in specs.entries) entry.key: entry.value.text
    };

    final updatedData = {
      "title": titleController.text,
      "address": addressController.text,
      "availability": availability,
      "domisili": domisili,
      "facilities": selectedFacilities,
      "fullName": fullName,
      "location": {
        "latitude": latitude,
        "longitude": longitude
      },
      "price": price,
      "specs": selectedSpecsMap,
      "userId": FirebaseAuth.instance.currentUser?.uid,
      "images": base64Images,
      "description": descriptionController.text,
      "propertyType": propertyType,
    };

    try {
      await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update(updatedData);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Postingan berhasil diperbarui')));
      Navigator.pop(context);
    } catch (e) {
      print('Gagal update post: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui post')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final specFields = getSpecFieldsByType(propertyType);
    final facilityOptions = getFacilitiesByType(propertyType);

    return Scaffold(
      appBar: AppBar(title: Text('Edit Properti')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Judul'),
                validator: (val) => val == null || val.isEmpty ? 'Judul wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'Alamat Lengkap'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: propertyType,
                items: ['Rumah', 'Apartemen', 'Kost'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      propertyType = value;
                      _initializeSpecControllers();
                      facilities = {
                        for (var f in getFacilitiesByType(value)) f: false
                      };
                    });
                  }
                },
                decoration: InputDecoration(labelText: 'Jenis Properti'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Harga (Rp)'),
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  val = val.replaceAll(RegExp(r'[^0-9]'), '');
                  setState(() {
                    price = int.tryParse(val) ?? 0;
                    priceController.text = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(price);
                    priceController.selection = TextSelection.fromPosition(
                      TextPosition(offset: priceController.text.length),
                    );
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Deskripsi'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: specFields.map((field) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      controller: specs[field],
                      decoration: InputDecoration(labelText: field),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: facilityOptions.map((facility) {
                  return FilterChip(
                    label: Text(facility),
                    selected: facilities[facility] ?? false,
                    onSelected: (val) {
                      setState(() {
                        facilities[facility] = val;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: Text('Tambah Gambar'),
                  ),
                  const SizedBox(width: 12),
                  Text('${base64Images.length} gambar terpilih'),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updatePost,
                child: Text('Perbarui Postingan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
