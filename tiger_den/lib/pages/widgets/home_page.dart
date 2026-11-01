import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../base_designs/sitewide/design_main.dart';
import '../../services/auth_service.dart';

// Home Page for Tiger Den App
// TODO: Hook in pulling images/names from database, add in navigation

// Event Info class for slideshow
class EventInfo {
  final String imagePath;
  final String eventName;

  EventInfo({required this.imagePath, required this.eventName});
}

// Club Info class for bottom slideshow
class ClubInfo {
  final String imagePath;
  final String clubName;

  ClubInfo({required this.imagePath, required this.clubName});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  
  //Club and Event slideshow pause button setup
  final CarouselSliderController _eventController = CarouselSliderController();
  final CarouselSliderController _clubController = CarouselSliderController();
  bool _isEventPlaying = true;
  bool _isClubPlaying = true;
  int _currentMenuIndex = 0;

  // Placeholder hardcoded collections
  final List<EventInfo> _events = [
    EventInfo(imagePath: 'assets/event1.jpg', eventName: 'Mike Watch 2k26'),
    EventInfo(imagePath: 'assets/event2.jpg', eventName: 'Homecoming Tailgate Bash'),
    EventInfo(imagePath: 'assets/event3.jpg', eventName: 'Intramural Championship Match'),
  ];

  final List<ClubInfo> _clubs = [
    ClubInfo(imagePath: 'assets/club1.jpg', clubName: 'Tiger Photography Guild'),
    ClubInfo(imagePath: 'assets/club2.jpg', clubName: 'LSU Chess & Strategy Group'),
    ClubInfo(imagePath: 'assets/club3.jpg', clubName: 'Rec Outdoor Adventure Club'),
  ];

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double carouselHeight = screenHeight * 0.25;

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.purple,
        backgroundColor: Colors.grey,
        title: const Text('Tiger Den Home'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Event Slideshow
            SizedBox(
              height: carouselHeight,
              child: CarouselSlider(
                carouselController: _eventController,
                options: CarouselOptions(
                  viewportFraction: 0.9,
                  enlargeCenterPage: true,
                  autoPlay: _isEventPlaying,
                  autoPlayInterval: const Duration(seconds: 4),
                  height: carouselHeight,
                ),
                items: _events.map((event) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Stack(
                      children: [
                        SizedBox.expand(
                          child: Image.asset(event.imagePath, fit: BoxFit.cover),
                        ),
                        // Dark overlay gradient mask
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withAlpha(160),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Label text + Play/Pause trigger row
                        Positioned(
                          bottom: 12.0,
                          left: 12.0,
                          right: 12.0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  event.eventName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(
                                  () => _isEventPlaying = !_isEventPlaying,
                                ),
                                child: Icon(
                                  _isEventPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Info Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.8,
                children: [
                  _buildMenuButton(context, 'Categories', Icons.grid_view_rounded, Colors.purple),
                  _buildMenuButton(context, 'Locations', Icons.location_on, Colors.purple),
                  _buildMenuButton(context, 'Group Admin', Icons.admin_panel_settings, Colors.purple),
                  _buildMenuButton(context, 'App Info', Icons.info_outline_rounded, Colors.purple),
                ],
              ),
            ),

            // Club Slideshow
            Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 24.0),
              child: SizedBox(
                height: carouselHeight,
                child: CarouselSlider(
                  options: CarouselOptions(
                    viewportFraction: 0.9,
                    enlargeCenterPage: true,
                    autoPlay: _isClubPlaying,
                    autoPlayInterval: const Duration(seconds: 5),
                    height: carouselHeight,
                  ),
                  items: _clubs.map((club) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Stack(
                        children: [
                          SizedBox.expand(
                            child: Image.asset(club.imagePath, fit: BoxFit.cover),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withAlpha(160),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                          bottom: 12.0,
                          left: 12.0,
                          right: 12.0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  club.clubName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(
                                  () => _isEventPlaying = !_isEventPlaying,
                                ),
                                child: Icon(
                                  _isEventPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  color: Colors.white,
                                  size: 28,
                                )
                              )
                        ],
                      ),
                    )
                ]
            )
        );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentMenuIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentMenuIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  // Placeholder menu button widget
  Widget _buildMenuButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return ElevatedButton.icon(
      onPressed: () {
        // TODO: complete navigation
      },
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }
}