import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final picker = ImagePicker();
  List<String> base64Images = [];
  String fullAddress = '';
  double? latitude;
  double? longitude;
  String availability = 'Tersedia';
  String propertyType = 'Rumah';
  int? price;
  String description = '';
  String fullName = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  Map<String, bool> facilities = {};
  Map<String, TextEditingController> specs = {};

  final titleController = TextEditingController();
  final addressController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();

  Map<String, String> domisili = {
    'kecamatan': '',
    'kota': '',
    'provinsi': '',
  };

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _initializeSpecControllers();
  }

  void _initializeSpecControllers() {
    specs['Jumlah kamar tidur'] = TextEditingController();
    specs['Jumlah kamar mandi'] = TextEditingController();
    specs['Luas bangunan (m²)'] = TextEditingController();
    specs['Ukuran kamar (m²)'] = TextEditingController();
    specs['Jumlah kamar tersedia'] = TextEditingController();
    specs['Lantai ke-'] = TextEditingController();
    specs['Luas unit (m²)'] = TextEditingController();
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

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
    });

    List<Placemark> placemarks = await placemarkFromCoordinates(latitude!, longitude!);
    Placemark place = placemarks.first;

    String kecamatan = place.subLocality?.trim().isNotEmpty == true ? place.subLocality! : 'Tidak diketahui';
    String kota = place.locality?.trim().isNotEmpty == true
        ? place.locality!
        : (place.subAdministrativeArea?.trim().isNotEmpty == true ? place.subAdministrativeArea! : 'Tidak diketahui');
    String provinsi = place.administrativeArea?.trim().isNotEmpty == true ? place.administrativeArea! : 'Tidak diketahui';

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
      for (XFile image in pickedFiles) {
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

  Future<void> _submitPost() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final selectedFacilities = facilities.entries.where((e) => e.value).map((e) => e.key).toList();

    final selectedSpecsMap = <String, String>{};
    for (var key in getSpecFieldsByType(propertyType)) {
      selectedSpecsMap[key] = specs[key]?.text ?? '';
    }

    final doc = {
      "title": titleController.text,
      "address": addressController.text,
      "availability": availability,
      "createdAt": now.toIso8601String(),
      "domisili": domisili,
      "facilities": selectedFacilities,
      "fullName": fullName,
      "location": {
        "latitude": latitude,
        "longitude": longitude
      },
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

      setState(() {
        titleController.clear();
        addressController.clear();
        descriptionController.clear();
        priceController.clear();
        base64Images.clear();
        facilities.clear();
        specs.forEach((key, controller) => controller.clear());
        price = null;
      });
    } catch (e) {
      print('Error saat menambahkan post: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengunggah post')));
    }
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
                  ElevatedButton(onPressed: _pickImages, child: Text('Ambil dari Galeri')),
                  SizedBox(width: 8),
                  ElevatedButton(onPressed: _pickCameraImage, child: Text('Ambil dari Kamera')),
                ],
              ),
              Wrap(
                children: base64Images.asMap().entries.map((entry) {
                  int index = entry.key;
                  String img = entry.value;
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.memory(base64Decode(img), height: 80),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            base64Images.removeAt(index);
                          });
                        },
                        child: Icon(Icons.close, color: Colors.red),
                      ),
                    ],
                  );
                }).toList(),
              ),
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Judul Properti'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Judul tidak boleh kosong';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'Alamat Lengkap'),
              ),
              ElevatedButton(onPressed: _getLocation, child: Text('Gunakan Lokasi Saat Ini')),
              TextFormField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Deskripsi'),
              ),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Harga Sewa (Rp)'),
                onChanged: (val) {
                  String numeric = val.replaceAll(RegExp(r'[^0-9]'), '');
                  if (numeric.isEmpty) numeric = '0';
                  price = int.tryParse(numeric) ?? 0;
                  priceController.value = TextEditingValue(
                    text: f.format(price),
                    selection: TextSelection.collapsed(offset: f.format(price).length),
                  );
                },
              ),
              DropdownButtonFormField(
                value: propertyType,
                items: ['Rumah', 'Kost', 'Apartemen', 'Kontrakan']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => propertyType = val!),
                decoration: InputDecoration(labelText: 'Jenis Properti'),
              ),
              DropdownButtonFormField(
                value: availability,
                items: ['Tersedia', 'Dipakai']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => availability = val!),
                decoration: InputDecoration(labelText: 'Status Ketersediaan'),
              ),
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
              ElevatedButton(onPressed: _submitPost, child: Text('Submit')),
            ],
          ),
        ),
      ),
    );
  }
}
