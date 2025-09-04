import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:concentric_transition/concentric_transition.dart';
import 'package:practice_pad/widgets/wooden_border_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreenData {
  final String title;
  final String subtitle;
  final List<String> imagePaths;
  final Color bgColor;
  final Color textColor;

  const OnboardingScreenData({
    required this.title,
    required this.subtitle,
    required this.imagePaths,
    required this.bgColor,
    required this.textColor,
  });
}


class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({Key? key, required this.onComplete}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentScreenIndex = 0;
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final List<OnboardingScreenData> onboardingScreens = [
   OnboardingScreenData(
    title: "Practice Pad",
    subtitle: "The only app that organizes your practice, manages your scores, and helps you transcribe songs—all in one place",
    imagePaths: [
      'assets/images/onboarding/page_1/image_1.png',
    ],
    bgColor: Theme.of(context).colorScheme.primary,
    textColor: Colors.white,
  ),
  const OnboardingScreenData(
    title: "Organize Your Practice",
    subtitle: "Create structured practice routines and track your progress with integrated timers and session management",
    imagePaths: [
      'assets/images/onboarding/page_2/image_1.png',
      'assets/images/onboarding/page_2/image_2.png',
      'assets/images/onboarding/page_2/image_3.png',
    ],
    bgColor: Colors.white,
    textColor: Colors.black,
  ),
   OnboardingScreenData(
    title: "All Your Music, One Place",
    subtitle: "Access 1,400+ jazz standards plus your entire personal library. Add melodies to chord sheets or upload and annotate PDFs",
    imagePaths: [
      'assets/images/onboarding/page_3/image_1.png',
      'assets/images/onboarding/page_3/image_2.png',
      'assets/images/onboarding/page_3/image_3.png',
    ],
    bgColor: Theme.of(context).colorScheme.primary,
    textColor: Colors.white,
  ),
  const OnboardingScreenData(
    title: "Transcribe Songs",
    subtitle: "Add custom YouTube video loops to help transcribe songs! Save a youtube video for each song",
    imagePaths: [
      'assets/images/onboarding/page_4/image_1.png',
      'assets/images/onboarding/page_4/image_2.png',
    ],
    bgColor: Colors.white,
    textColor: Colors.black,
  ),
];

    return WoodenBorderWrapper(
      cornerRadius: 60,
      imagePath: 'assets/images/wood_texture.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ConcentricPageView(
          duration: const Duration(milliseconds: 800),
          colors: onboardingScreens.map((screen) => screen.bgColor).toList(),
          radius: 30,
          imagesPerScreen: onboardingScreens.map((screen) => screen.imagePaths.length).toList(),
          onImageChange: (screenIndex, imageIndex) {
            setState(() {
              _currentScreenIndex = screenIndex;
              _currentImageIndex = imageIndex;
            });
          },
          nextButtonBuilder: (context) => Center(
            child: Icon(
              Icons.navigate_next,
              size: screenWidth * 0.08,
            ),
          ),
          onFinish: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboarding_completed', true);
            widget.onComplete();
          },
          itemBuilder: (index) {
            final screen = onboardingScreens[index % onboardingScreens.length];
            return SafeArea(
              child: _OnboardingPage(
                screen: screen,
                currentImageIndex: index == _currentScreenIndex ? _currentImageIndex : 0,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingScreenData screen;
  final int currentImageIndex;

  const _OnboardingPage({
    Key? key,
    required this.screen,
    required this.currentImageIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    space(double p) => SizedBox(height: screenHeight * p / 100);

    return Column(
      children: [
        space(8),
        
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            screen.title,
            style: TextStyle(
              fontSize: screenHeight * 0.045,
              fontWeight: FontWeight.bold,
              color: screen.textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        space(3),
        
        // Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
            screen.subtitle,
            style: TextStyle(
              fontSize: screenHeight * 0.022,
              color: screen.textColor.withOpacity(0.9),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        space(6),
        
        // Image with progress indicator
        Expanded(
          child: Column(
            children: [
              // Main image
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  color: Colors.transparent,

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _ImageWidget(
                      imagePath: screen.imagePaths[currentImageIndex.clamp(0, screen.imagePaths.length - 1)],
                    ),
                  ),
                ),
              ),
              
              space(4),
              
              // Progress indicators (if multiple images)
              if (screen.imagePaths.length > 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    screen.imagePaths.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == currentImageIndex
                            ? screen.textColor
                            : screen.textColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                space(2),
              ],
            ],
          ),
        ),
        
        space(8),
      ],
    );
  }
}

class _ImageWidget extends StatelessWidget {
  final String imagePath;

  const _ImageWidget({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return imagePath.startsWith('assets/')
        ? Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _PlaceholderImage(),
          )
        : _PlaceholderImage();
  }
}

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Icon(
          CupertinoIcons.photo,
          size: 64,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class OnboardingService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  
  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }
  
  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
  }
  
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompletedKey);
  }
}