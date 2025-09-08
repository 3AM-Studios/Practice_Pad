import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'clipper.dart';

class ConcentricPageView extends StatefulWidget {
  final Function(int index) itemBuilder;
  final Function(int page)? onChange;
  final Function? onFinish;
  final int? itemCount;
  final PageController? pageController;
  final bool pageSnapping;
  final bool reverse;
  final List<Color> colors;
  final ValueNotifier? notifier;
  final double scaleFactor;
  final double opacityFactor;
  final double radius;
  final double verticalPosition;
  final Axis direction;
  final ScrollPhysics? physics;
  final Duration duration;
  final Curve curve;
  final Key? pageViewKey;

  /// Useful for adding a next icon to the page view button
  final WidgetBuilder? nextButtonBuilder;
  
  /// Support for multi-image screens
  final List<int>? imagesPerScreen;
  final Function(int screenIndex, int imageIndex)? onImageChange;

  const ConcentricPageView({
    Key? key,
    required this.itemBuilder,
    required this.colors,
    this.pageViewKey,
    this.onChange,
    this.onFinish,
    this.itemCount,
    this.pageController,
    this.pageSnapping = true,
    this.reverse = false,
    this.notifier,
    this.scaleFactor = 0.3,
    this.opacityFactor = 0.0,
    this.radius = 40.0,
    this.verticalPosition = 0.88,
    this.direction = Axis.horizontal,
    this.physics = const ClampingScrollPhysics(),
    this.duration = const Duration(milliseconds: 1500),
    this.curve = Curves.easeInOutSine, // const Cubic(0.7, 0.5, 0.5, 0.1),
    this.nextButtonBuilder,
    this.imagesPerScreen,
    this.onImageChange,
  })  : assert(colors.length >= 2),
        super(key: key);

  @override
  _ConcentricPageViewState createState() => _ConcentricPageViewState();
}

class _ConcentricPageViewState extends State<ConcentricPageView> {
  late PageController _pageController;
  double _progress = 0;
  int _prevPage = 0;
  Color? _prevColor;
  Color? _nextColor;
  
  // Multi-image support
  int _currentScreenIndex = 0;
  int _currentImageIndex = 0;
  
  // Debouncing
  bool _isProcessing = false;
  DateTime? _lastTapTime;

  @override
  void initState() {
    _prevColor = widget.colors[_prevPage];
    _nextColor = widget.colors[_prevPage + 1];
    _pageController = (widget.pageController ?? PageController(initialPage: 0))
      ..addListener(_onScroll);
    super.initState();
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _buildClipper(),
        _buildPageView(),
        Positioned(
          top: MediaQuery.of(context).size.height * widget.verticalPosition,
          child: _Button(
            pageController: _pageController,
            widget: widget,
            currentScreenIndex: _currentScreenIndex,
            currentImageIndex: _currentImageIndex,
            onNextImage: _handleNextImage,
          ),
        ),
      ],
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      key: widget.pageViewKey,
      scrollBehavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        overscroll: false,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
        },
      ),
      clipBehavior: Clip.none,
      scrollDirection: widget.direction,
      controller: _pageController,
      reverse: widget.reverse,
      physics: widget.physics,
      itemCount: widget.itemCount,
      pageSnapping: widget.pageSnapping,
      onPageChanged: (int page) {
        if (widget.onChange != null) {
          widget.onChange!(page);
        }
      },
      itemBuilder: (context, index) {
        final child = widget.itemBuilder(index);
        if (!_pageController.position.hasContentDimensions) {
          return child;
        }
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            final progress = _pageController.page! - index;
            if (widget.opacityFactor != 0) {
              child = Opacity(
                opacity: (1 - (progress.abs() * widget.opacityFactor))
                    .clamp(0.0, 1.0),
                child: child,
              );
            }
            if (widget.scaleFactor != 0) {
              child = Transform.scale(
                scale:
                    (1 - (progress.abs() * widget.scaleFactor)).clamp(0.0, 1.0),
                child: child,
              );
            }
            return child!;
          },
          child: child,
        );
      },
    );
  }

  Widget _buildClipper() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (ctx, _) {
        return ColoredBox(
          color: _prevColor!,
          child: ClipPath(
            clipper: ConcentricClipper(
              progress: _progress,
              reverse: widget.reverse,
              radius: widget.radius,
              verticalPosition: widget.verticalPosition,
            ),
            child: ColoredBox(
              color: _nextColor!,
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }

  void _onScroll() {
    final direction = _pageController.position.userScrollDirection;
    double page = _pageController.page ?? 0;

    if (direction == ScrollDirection.forward) {
      _prevPage = page.toInt();
      _progress = page - _prevPage;
    } else {
      _prevPage = page.toInt();
      _progress = page - _prevPage;
    }

    final total = widget.colors.length;
    final prevIndex = _prevPage % total;
    int nextIndex = prevIndex + 1;

    if (prevIndex == total - 1) {
      nextIndex = 0;
    }

    _prevColor = widget.colors[prevIndex];
    _nextColor = widget.colors[nextIndex];

    widget.notifier?.value = page - _prevPage;
  }
  
  void _handleNextImage() {
    // Debounce rapid taps
    final now = DateTime.now();
    if (_isProcessing || (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 300)) {
      return;
    }
    
    _lastTapTime = now;
    _isProcessing = true;
    
    if (widget.imagesPerScreen == null) {
      // Standard behavior - go to next screen
      _nextScreen();
      return;
    }
    
    // Add bounds check to prevent RangeError
    if (_currentScreenIndex >= widget.imagesPerScreen!.length) {
      _isProcessing = false;
      return; // Don't do anything if we're out of bounds
    }
    
    final imagesInCurrentScreen = widget.imagesPerScreen![_currentScreenIndex];
    
    if (_currentImageIndex < imagesInCurrentScreen - 1) {
      // Move to next image in current screen
      setState(() {
        _currentImageIndex++;
      });
      widget.onImageChange?.call(_currentScreenIndex, _currentImageIndex);
      _isProcessing = false;
    } else {
      // All images in current screen viewed, move to next screen
      _nextScreen();
    }
  }
  
  void _nextScreen() {
    final currentPage = _pageController.page?.round() ?? 0;
    final isFinal = currentPage >= widget.colors.length - 1;
    
    if (isFinal && widget.onFinish != null) {
      widget.onFinish!();
      _isProcessing = false;
      return;
    }
    
    // Don't proceed if we're already at or past the last page
    if (currentPage >= widget.colors.length - 1) {
      _isProcessing = false;
      return;
    }
    
    _pageController.nextPage(
      duration: widget.duration,
      curve: widget.curve,
    ).then((_) {
      // Update the state AFTER the page transition completes
      // This prevents showing the first image of the next screen during transition
      setState(() {
        _currentScreenIndex++;
        _currentImageIndex = 0;
      });
      widget.onImageChange?.call(_currentScreenIndex, _currentImageIndex);
      _isProcessing = false;
    });
  }
}

class _Button extends StatelessWidget {
  const _Button({
    Key? key,
    required this.pageController,
    required this.widget,
    required this.currentScreenIndex,
    required this.currentImageIndex,
    required this.onNextImage,
  }) : super(key: key);

  final PageController pageController;
  final ConcentricPageView widget;
  final int currentScreenIndex;
  final int currentImageIndex;
  final VoidCallback onNextImage;

  @override
  Widget build(BuildContext context) {
    Widget? child = widget.nextButtonBuilder != null
        ? widget.nextButtonBuilder!(context)
        : null;

    child = GestureDetector(
      excludeFromSemantics: true,
      onTap: onNextImage,
      child: DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Center(child: child),
      ),
    );

    return AnimatedBuilder(
      animation: pageController,
      builder: (context, child) {
        final currentPage = pageController.page?.floor() ?? 0;
        final progress = (pageController.page ?? 0) - currentPage;
        return AnimatedOpacity(
          opacity: progress > 0.01 ? 0.0 : 1.0,
          curve: Curves.ease,
          duration: const Duration(milliseconds: 150),
          child: IconTheme(
            data: IconThemeData(
              color: widget.colors[currentPage % widget.colors.length],
            ),
            child: child!,
          ),
        );
      },
      child: child,
    );
  }
}
