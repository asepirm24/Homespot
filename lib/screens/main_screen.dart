import 'package:flutter/material.dart';
import 'package:homespot/screens/home_screen.dart';
import 'package:homespot/screens/search_screen.dart';
import 'package:homespot/screens/favorite_screen.dart';
import 'package:homespot/screens/add_post_screen.dart';
import 'package:homespot/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    FavoriteScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          color: colorScheme.surface,
          notchMargin: 6,
          elevation: 10,
          child: SizedBox(
            height: 50, // Lebih ramping
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () => _onItemTapped(0),
                  color: _selectedIndex == 0
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.6),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _onItemTapped(1),
                  color: _selectedIndex == 1
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 40), // Ruang untuk FAB
                IconButton(
                  icon: const Icon(Icons.favorite),
                  onPressed: () => _onItemTapped(2),
                  color: _selectedIndex == 2
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.6),
                ),
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () => _onItemTapped(3),
                  color: _selectedIndex == 3
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPostScreen()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Tambah Post',
        shape: const CircleBorder(),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
