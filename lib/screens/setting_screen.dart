import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:homespot/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Personalisasi')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Mode Gelap"),
            value: themeProvider.isDarkMode,
            onChanged: themeProvider.toggleTheme,
            secondary: const Icon(Icons.dark_mode),
          ),
        ],
      ),
    );
  }
}
