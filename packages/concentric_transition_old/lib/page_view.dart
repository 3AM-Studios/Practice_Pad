import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'clipper.dart';
import 'dart:ui' as ui;
import 'dart:math';

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
  static const List<bool> applyTexture = [true, false, false];

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
    this.verticalPosition = 0.75,
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
  final List<double> _applyTextureToPages = [0, 0, 0, 0];
  double? _prevTextureOpacity;
  double? _nextTextureOpacity;
  ui.Image? texture;
  
  // Multi-image support
  int _currentScreenIndex = 0;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTexture();
    _prevColor = widget.colors[_prevPage];
    _nextColor = widget.colors[_prevPage + 1];
    _prevTextureOpacity = _applyTextureToPages[_prevPage];
    _nextTextureOpacity = _applyTextureToPages[_prevPage + 1];

    _pageController = (widget.pageController ?? PageController(initialPage: 0))
      ..addListener(_onScroll);
  }

  Future<void> _loadTexture() async {
    try {
      const imageProvider = AssetImage('assets/images/wood_texture_rotated.jpg');
      final imageStream = imageProvider.resolve(ImageConfiguration.empty);
      imageStream.addListener(ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            texture = info.image;
          });
        }
      }));
    } catch (e) {
      // If texture loading fails, set to null and continue without texture
      texture = null;
    }
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
        return Stack(
          children: [
            ColoredBox(
              color: _prevColor!,
              child: const SizedBox.expand(),
            ),
            if (texture != null)
              CustomPaint(
                painter: ConcentricRingPainter(
                    texture: texture!,
                    thickness: 12, // Adjust for desired ring thickness
                    progress: -_progress,
                    radius: widget.radius,
                    verticalPosition: widget.verticalPosition,
                    reverse: widget.reverse),
                child: const SizedBox.expand(),
              ),
            ClipPath(
              clipper: ConcentricClipper(
                progress: _progress,
                reverse: widget.reverse,
                radius: widget.radius,
                verticalPosition: widget.verticalPosition,
              ),
              child: Stack(
                children: [
                  ColoredBox(
                    color: _nextColor!,
                    child: const SizedBox.expand(),
                  ),
                  if (texture != null)
                    Opacity(
                      opacity: 1,
                      child: CustomPaint(
                        painter: ConcentricRingPainter(
                            texture: texture!,
                            thickness: 10, // Adjust for desired ring thickness
                            progress: _progress,
                            radius: widget.radius,
                            verticalPosition: widget.verticalPosition,
                            reverse: widget.reverse),
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
    if (widget.imagesPerScreen == null) {
      // Standard behavior - go to next screen
      _nextScreen();
      return;
    }
    
    final imagesInCurrentScreen = widget.imagesPerScreen![_currentScreenIndex];
    
    if (_currentImageIndex < imagesInCurrentScreen - 1) {
      // Move to next image in current screen
      setState(() {
        _currentImageIndex++;
      });
      widget.onImageChange?.call(_currentScreenIndex, _currentImageIndex);
    } else {
      // All images in current screen viewed, move to next screen
      _nextScreen();
    }
  }
  
  void _nextScreen() {
    final isFinal = _pageController.page == widget.colors.length - 1;
    if (isFinal && widget.onFinish != null) {
      widget.onFinish!();
      return;
    }
    
    _pageController.nextPage(
      duration: widget.duration,
      curve: widget.curve,
    );
    
    setState(() {
      _currentScreenIndex++;
      _currentImageIndex = 0;
    });
  }
}

class ConcentricRingPainter extends CustomPainter {
  final double radius;
  final double limit;
  final double verticalPosition;
  final double progress;
  final double growFactor;
  final bool reverse;
  final ui.Image texture;
  final double thickness;

  ConcentricRingPainter({
    required this.texture,
    required this.thickness,
    this.progress = 0.0,
    this.verticalPosition = 0.85,
    this.radius = 30.0,
    this.growFactor = 30.0,
    this.reverse = false,
  }) : limit = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.fillType = PathFillType.evenOdd;

    final halfWidth = size.width / 2;
    final centerY = (size.height * verticalPosition) + radius;

    // Keep the radius constant, or adjust as needed
    // print('prog $progress'); // Debug only
    double r = radius * 0.7 - radius * 0.8 * sin(pi * (1 - progress));

    // Calculate the displacement needed to move the ring offscreen to the right
    double displacement = halfWidth + radius + 30;

    // Use the sine function to calculate centerX
    // This moves the ring from center to right offscreen and back to center
    double centerX = halfWidth + displacement * sin(pi * progress);

    if (reverse) {
      // If reverse is true, mirror the movement to the left
      centerX = size.width - centerX;
    }

    final circleCenter = Offset(centerX, centerY);
    final shape = Rect.fromCircle(center: circleCenter, radius: r);

    // Build the clipping path
    path.addOval(shape);

    // Save the canvas state before clipping
    canvas.save();

    // Clip the canvas to the path
    canvas.clipPath(path);

    // Draw the content that should appear inside the clip
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.transparent,
    );

    // Restore the canvas state
    canvas.restore();

    // Now, draw the textured ring
    final paint = Paint()
      ..shader = ImageShader(
        texture,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    // Draw the ring
    canvas.drawArc(
      shape,
      0,
      2 * pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ConcentricRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.reverse != reverse;
  }
}

class TexturePainter extends CustomPainter {
  final ui.Image texture;

  TexturePainter({required this.texture});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..shader = ImageShader(
        texture,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    final size = widget.radius * 2;
    Widget? child = widget.nextButtonBuilder != null
        ? widget.nextButtonBuilder!(context)
        : null;

    child = GestureDetector(
      excludeFromSemantics: true,
      onTap: onNextImage,
      child: DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: SizedBox.fromSize(
          size: Size.square(size),
          child: child,
        ),
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
