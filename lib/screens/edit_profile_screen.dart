import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  String? base64Image;
  Map<String, String>? domisili;
  double? latitude;
  double? longitude;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      fullNameController.text = data['fullName'] ?? '';
      descriptionController.text = data['description'] ?? '';
      base64Image = data['photoBase64'];
      addressController.text = data['alamat'] ?? '';
      final rawDomisili = data['domisili'];
      if (rawDomisili != null) {
        domisili = Map<String, String>.from(rawDomisili);
      }
      latitude = data['latitude'];
      longitude = data['longitude'];
      setState(() {});
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final originalBytes = await picked.readAsBytes();
    final compressedBytes = await FlutterImageCompress.compressWithList(
      originalBytes,
      quality: 70,
    );

    setState(() {
      base64Image = base64Encode(compressedBytes);
    });
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

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fullName': fullNameController.text.trim(),
      'description': descriptionController.text.trim(),
      if (base64Image != null) 'photoBase64': base64Image,
      if (addressController.text.isNotEmpty) 'alamat': addressController.text,
      if (domisili != null) 'domisili': domisili,
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
      },
    });

    setState(() => isLoading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profil")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: base64Image != null
                        ? MemoryImage(base64Decode(base64Image!))
                        : const AssetImage('assets/images/dummy_profile.png') as ImageProvider,
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: fullNameController,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Deskripsi'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Alamat Sekarang'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _getLocation,
              icon: const Icon(Icons.location_on),
              label: const Text("Ambil Lokasi"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveProfile,
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }
}
