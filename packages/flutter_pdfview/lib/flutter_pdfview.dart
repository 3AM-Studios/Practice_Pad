import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef PDFViewCreatedCallback = void Function(PDFViewController controller);
typedef RenderCallback = void Function(int? pages);
typedef PageChangedCallback = void Function(int? page, int? total);
typedef ErrorCallback = void Function(dynamic error);
typedef PageErrorCallback = void Function(int? page, dynamic error);
typedef LinkHandlerCallback = void Function(String? uri);
typedef DrawingCallback = void Function(List<Offset> points);
typedef DrawingEndCallback = void Function();

enum FitPolicy { WIDTH, HEIGHT, BOTH }

class PDFView extends StatefulWidget {
  const PDFView({
    Key? key,
    this.filePath,
    this.pdfData,
    this.onViewCreated,
    this.onRender,
    this.onPageChanged,
    this.onError,
    this.onPageError,
    this.onLinkHandler,
    this.gestureRecognizers,
    this.enableSwipe = true,
    this.swipeHorizontal = false,
    this.password,
    this.nightMode = false,
    this.autoSpacing = true,
    this.pageFling = true,
    this.pageSnap = true,
    this.fitEachPage = true,
    this.defaultPage = 0,
    this.fitPolicy = FitPolicy.WIDTH,
    this.preventLinkNavigation = false,
    this.backgroundColor,
    this.enableDrawing = false,
    this.drawingEnabled = false,
    this.onDrawing,
    this.onDrawingEnd,
    this.drawingColor,
    this.drawingStrokeWidth = 3.0,
  })  : assert(filePath != null || pdfData != null),
        super(key: key);

  @override
  _PDFViewState createState() => _PDFViewState();

  /// If not null invoked once the PDFView is created.
  final PDFViewCreatedCallback? onViewCreated;

  /// Return PDF page count as a parameter
  final RenderCallback? onRender;

  /// Return current page and page count as a parameter
  final PageChangedCallback? onPageChanged;

  /// Invokes on error that handled on native code
  final ErrorCallback? onError;

  /// Invokes on page cannot be rendered or something happens
  final PageErrorCallback? onPageError;

  /// Used with preventLinkNavigation=true. It's helpful to customize link navigation
  final LinkHandlerCallback? onLinkHandler;

  /// Which gestures should be consumed by the pdf view.
  ///
  /// It is possible for other gesture recognizers to be competing with the pdf view on pointer
  /// events, e.g if the pdf view is inside a [ListView] the [ListView] will want to handle
  /// vertical drags. The pdf view will claim gestures that are recognized by any of the
  /// recognizers on this list.
  ///
  /// When this set is empty or null, the pdf view will only handle pointer events for gestures that
  /// were not claimed by any other gesture recognizer.
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  /// The initial URL to load.
  final String? filePath;

  /// The binary data of a PDF document
  final Uint8List? pdfData;

  /// Indicates whether or not the user can swipe to change pages in the PDF document. If set to true, swiping is enabled.
  final bool enableSwipe;

  /// Indicates whether or not the user can swipe horizontally to change pages in the PDF document. If set to true, horizontal swiping is enabled.
  final bool swipeHorizontal;

  /// Represents the password for a password-protected PDF document. It can be nullable
  final String? password;

  /// Indicates whether or not the PDF viewer is in night mode. If set to true, the viewer is in night mode
  final bool nightMode;

  /// Indicates whether or not the PDF viewer automatically adds spacing between pages. If set to true, spacing is added.
  final bool autoSpacing;

  /// Indicates whether or not the user can "fling" pages in the PDF document. If set to true, page flinging is enabled.
  final bool pageFling;

  /// Indicates whether or not the viewer snaps to a page after the user has scrolled to it. If set to true, snapping is enabled.
  final bool pageSnap;

  /// Represents the default page to display when the PDF document is loaded.
  final int defaultPage;

  /// FitPolicy that determines how the PDF pages are fit to the screen. The FitPolicy enum can take on the following values:
  /// - FitPolicy.WIDTH: The PDF pages are scaled to fit the width of the screen.
  /// - FitPolicy.HEIGHT: The PDF pages are scaled to fit the height of the screen.
  /// - FitPolicy.BOTH: The PDF pages are scaled to fit both the width and height of the screen.
  final FitPolicy fitPolicy;

  /// fitEachPage
  @Deprecated("will be removed next version")
  final bool fitEachPage;

  /// Indicates whether or not clicking on links in the PDF document will open the link in a new page. If set to true, link navigation is prevented.
  final bool preventLinkNavigation;

  /// Use to change the background color. ex : "#FF0000" => red
  final Color? backgroundColor;
  
  /// Enable drawing overlay
  final bool enableDrawing;
  
  /// Whether drawing is currently active
  final bool drawingEnabled;
  
  /// Callback when user draws
  final DrawingCallback? onDrawing;
  
  /// Callback when drawing ends
  final DrawingEndCallback? onDrawingEnd;
  
  /// Color for drawing strokes
  final Color? drawingColor;
  
  /// Width of drawing strokes
  final double drawingStrokeWidth;
}

class _PDFViewState extends State<PDFView> {
  final Completer<PDFViewController> _controller =
      Completer<PDFViewController>();
  
  // Drawing state - stored in PDF document coordinates
  List<List<Offset>> _drawingPaths = [];
  List<Offset> _currentPath = [];
  
  // PDF view state for coordinate transformation
  double _pdfZoom = 1.0;
  double _pdfOffsetX = 0.0;
  double _pdfOffsetY = 0.0;
  double _pageWidth = 0.0;
  double _pageHeight = 0.0;
  Size _widgetSize = Size.zero;

  @override
  Widget build(BuildContext context) {
    Widget pdfWidget;
    
    // Wrap with LayoutBuilder to get widget size
    return LayoutBuilder(
      builder: (context, constraints) {
        _widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      pdfWidget = PlatformViewLink(
        viewType: 'plugins.endigo.io/pdfview',
        surfaceFactory: (
          BuildContext context,
          PlatformViewController controller,
        ) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: widget.enableDrawing && widget.drawingEnabled 
                ? const <Factory<OneSequenceGestureRecognizer>>{}
                : widget.gestureRecognizers ?? const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (PlatformViewCreationParams params) {
          return PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: 'plugins.endigo.io/pdfview',
            layoutDirection: TextDirection.rtl,
            creationParams: _CreationParams.fromWidget(widget).toMap(),
            creationParamsCodec: const StandardMessageCodec(),
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..addOnPlatformViewCreatedListener((int id) {
              _onPlatformViewCreated(id);
            })
            ..create();
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      pdfWidget = UiKitView(
        viewType: 'plugins.endigo.io/pdfview',
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: widget.enableDrawing && widget.drawingEnabled 
            ? const <Factory<OneSequenceGestureRecognizer>>{}
            : widget.gestureRecognizers,
        creationParams: _CreationParams.fromWidget(widget).toMap(),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      pdfWidget = Text(
          '$defaultTargetPlatform is not yet supported by the pdfview_flutter plugin');
    }
    
        // Wrap with drawing overlay if enabled
        if (widget.enableDrawing) {
          pdfWidget = Stack(
            children: [
              pdfWidget,
              if (widget.drawingEnabled)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PDFDrawingPainter(
                      paths: _drawingPaths,
                      currentPath: _currentPath,
                      color: widget.drawingColor ?? Colors.blue,
                      strokeWidth: widget.drawingStrokeWidth,
                      widgetSize: _widgetSize,
                      pdfZoom: _pdfZoom,
                      pdfOffsetX: _pdfOffsetX,
                      pdfOffsetY: _pdfOffsetY,
                      pageWidth: _pageWidth,
                      pageHeight: _pageHeight,
                    ),
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        
        return pdfWidget;
      },
    );
  }
  
  void _onPanStart(DragStartDetails details) {
    final pdfCoord = _widgetToPdfCoordinates(details.localPosition);
    setState(() {
      _currentPath = [pdfCoord];
    });
  }
  
  void _onPanUpdate(DragUpdateDetails details) {
    final pdfCoord = _widgetToPdfCoordinates(details.localPosition);
    setState(() {
      _currentPath.add(pdfCoord);
    });
    widget.onDrawing?.call(_currentPath);
  }
  
  void _onPanEnd(DragEndDetails details) {
    setState(() {
      if (_currentPath.isNotEmpty) {
        _drawingPaths.add(List.from(_currentPath));
        _currentPath.clear();
      }
    });
    widget.onDrawingEnd?.call();
  }
  
  // Convert widget coordinates to PDF document coordinates
  Offset _widgetToPdfCoordinates(Offset widgetPos) {
    if (_pdfZoom == 0 || _pageWidth == 0 || _pageHeight == 0) {
      // Fallback to normalized coordinates if PDF state not available
      return Offset(widgetPos.dx / _widgetSize.width, widgetPos.dy / _widgetSize.height);
    }
    
    // Transform widget coordinates to PDF document coordinates
    // Account for zoom and pan offset
    double pdfX = (widgetPos.dx + _pdfOffsetX) / _pdfZoom;
    double pdfY = (widgetPos.dy + _pdfOffsetY) / _pdfZoom;
    
    // Normalize to page size (0.0 to 1.0)
    double normalizedX = pdfX / _pageWidth;
    double normalizedY = pdfY / _pageHeight;
    
    return Offset(normalizedX, normalizedY);
  }
  
  // Convert PDF document coordinates to current widget coordinates
  Offset _pdfToWidgetCoordinates(Offset pdfPos) {
    if (_pdfZoom == 0 || _pageWidth == 0 || _pageHeight == 0) {
      // Fallback to simple scaling if PDF state not available
      return Offset(pdfPos.dx * _widgetSize.width, pdfPos.dy * _widgetSize.height);
    }
    
    // Convert from normalized coordinates to actual page coordinates
    double pageX = pdfPos.dx * _pageWidth;
    double pageY = pdfPos.dy * _pageHeight;
    
    // Apply current zoom and pan offset to get widget coordinates
    double widgetX = (pageX * _pdfZoom) - _pdfOffsetX;
    double widgetY = (pageY * _pdfZoom) - _pdfOffsetY;
    
    return Offset(widgetX, widgetY);
  }
  
  // Update PDF view state from native platform
  void _updatePdfViewState(Map<String, dynamic> viewState) {
    setState(() {
      _pdfZoom = (viewState['zoom'] ?? 1.0).toDouble();
      _pdfOffsetX = (viewState['offsetX'] ?? 0.0).toDouble();
      _pdfOffsetY = (viewState['offsetY'] ?? 0.0).toDouble();
      _pageWidth = (viewState['pageWidth'] ?? 0.0).toDouble();
      _pageHeight = (viewState['pageHeight'] ?? 0.0).toDouble();
    });
  }
  
  
  // Methods to manage drawing data
  void clearDrawings() {
    setState(() {
      _drawingPaths.clear();
      _currentPath.clear();
    });
  }
  
  List<List<Map<String, double>>> getDrawingData() {
    return _drawingPaths.map((path) => 
      path.map((offset) => {'x': offset.dx, 'y': offset.dy}).toList()
    ).toList();
  }
  
  void setDrawingData(List<List<Map<String, double>>> drawingData) {
    setState(() {
      _drawingPaths = drawingData.map((path) => 
        path.map((point) => Offset(point['x']!, point['y']!)).toList()
      ).toList();
    });
  }

  void _onPlatformViewCreated(int id) {
    final PDFViewController controller = PDFViewController._(id, widget, this);
    _controller.complete(controller);
    if (widget.onViewCreated != null) {
      widget.onViewCreated!(controller);
    }
    
    // Request initial PDF view state if drawing is enabled
    if (widget.enableDrawing) {
      Future.delayed(const Duration(milliseconds: 500), () {
        controller.requestViewState();
      });
    }
  }

  @override
  void didUpdateWidget(PDFView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.future.then(
        (PDFViewController controller) => controller._updateWidget(widget));
  }

  @override
  void dispose() {
    _controller.future
        .then((PDFViewController controller) => controller.dispose());
    super.dispose();
  }
}

class _CreationParams {
  _CreationParams({
    this.filePath,
    this.pdfData,
    this.settings,
  });

  static _CreationParams fromWidget(PDFView widget) {
    return _CreationParams(
      filePath: widget.filePath,
      pdfData: widget.pdfData,
      settings: _PDFViewSettings.fromWidget(widget),
    );
  }

  final String? filePath;
  final Uint8List? pdfData;

  final _PDFViewSettings? settings;

  Map<String, dynamic> toMap() {
    Map<String, dynamic> params = {
      'filePath': filePath,
      'pdfData': pdfData,
    };

    params.addAll(settings!.toMap());

    return params;
  }
}

class _PDFViewSettings {
  _PDFViewSettings({
    this.enableSwipe,
    this.swipeHorizontal,
    this.password,
    this.nightMode,
    this.autoSpacing,
    this.pageFling,
    this.pageSnap,
    this.defaultPage,
    this.fitPolicy,
    this.preventLinkNavigation,
    this.backgroundColor,
  });

  static _PDFViewSettings fromWidget(PDFView widget) {
    return _PDFViewSettings(
      enableSwipe: widget.enableSwipe,
      swipeHorizontal: widget.swipeHorizontal,
      password: widget.password,
      nightMode: widget.nightMode,
      autoSpacing: widget.autoSpacing,
      pageFling: widget.pageFling,
      pageSnap: widget.pageSnap,
      defaultPage: widget.defaultPage,
      fitPolicy: widget.fitPolicy,
      preventLinkNavigation: widget.preventLinkNavigation,
      backgroundColor: widget.backgroundColor,
    );
  }

  final bool? enableSwipe;
  final bool? swipeHorizontal;
  final String? password;
  final bool? nightMode;
  final bool? autoSpacing;
  final bool? pageFling;
  final bool? pageSnap;
  final int? defaultPage;
  final FitPolicy? fitPolicy;
  final bool? preventLinkNavigation;

  final Color? backgroundColor;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enableSwipe': enableSwipe,
      'swipeHorizontal': swipeHorizontal,
      'password': password,
      'nightMode': nightMode,
      'autoSpacing': autoSpacing,
      'pageFling': pageFling,
      'pageSnap': pageSnap,
      'defaultPage': defaultPage,
      'fitPolicy': fitPolicy.toString(),
      'preventLinkNavigation': preventLinkNavigation,
      'backgroundColor': backgroundColor?.value,
    };
  }

  Map<String, dynamic> updatesMap(_PDFViewSettings newSettings) {
    final Map<String, dynamic> updates = <String, dynamic>{};
    if (enableSwipe != newSettings.enableSwipe) {
      updates['enableSwipe'] = newSettings.enableSwipe;
    }
    if (pageFling != newSettings.pageFling) {
      updates['pageFling'] = newSettings.pageFling;
    }
    if (pageSnap != newSettings.pageSnap) {
      updates['pageSnap'] = newSettings.pageSnap;
    }
    if (preventLinkNavigation != newSettings.preventLinkNavigation) {
      updates['preventLinkNavigation'] = newSettings.preventLinkNavigation;
    }
    return updates;
  }
}

class PDFViewController {
  PDFViewController._(
    int id,
    PDFView widget,
    _PDFViewState state,
  )   : _channel = MethodChannel('plugins.endigo.io/pdfview_$id'),
        _widget = widget,
        _state = state {
    _settings = _PDFViewSettings.fromWidget(widget);
    _channel.setMethodCallHandler(_onMethodCall);
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _widget = null;
  }

  MethodChannel _channel;

  late _PDFViewSettings _settings;

  PDFView? _widget;
  _PDFViewState? _state;

  Future<bool?> _onMethodCall(MethodCall call) async {
    final widget = _widget;
    if (widget == null) return null;

    switch (call.method) {
      case 'onRender':
        widget.onRender?.call(call.arguments['pages']);
        return null;
      case 'onViewStateChanged':
        // Handle PDF view state changes (zoom, pan, scroll)
        _state?._updatePdfViewState(call.arguments as Map<String, dynamic>);
        return null;
      case 'onPageChanged':
        widget.onPageChanged?.call(
          call.arguments['page'],
          call.arguments['total'],
        );
        return null;
      case 'onError':
        widget.onError?.call(call.arguments['error']);
        return null;
      case 'onPageError':
        widget.onPageError
            ?.call(call.arguments['page'], call.arguments['error']);
        return null;
      case 'onLinkHandler':
        widget.onLinkHandler?.call(call.arguments);
        return null;
    }
    throw MissingPluginException(
        '${call.method} was invoked but has no handler');
  }

  Future<int?> getPageCount() async {
    final int? pageCount = await _channel.invokeMethod('pageCount');
    return pageCount;
  }

  Future<int?> getCurrentPage() async {
    final int? currentPage = await _channel.invokeMethod('currentPage');
    return currentPage;
  }

  Future<bool?> setPage(int page) async {
    final bool? isSet =
        await _channel.invokeMethod('setPage', <String, dynamic>{
      'page': page,
    });
    return isSet;
  }

  Future<void> _updateWidget(PDFView widget) async {
    _widget = widget;
    await _updateSettings(_PDFViewSettings.fromWidget(widget));
  }

  Future<void> _updateSettings(_PDFViewSettings setting) async {
    final Map<String, dynamic> updateMap = _settings.updatesMap(setting);
    if (updateMap.isEmpty) {
      return null;
    }
    _settings = setting;
    return _channel.invokeMethod('updateSettings', updateMap);
  }
  
  // Drawing methods
  void clearDrawings() {
    _state?.clearDrawings();
  }
  
  List<List<Map<String, double>>> getDrawingData() {
    return _state?.getDrawingData() ?? [];
  }
  
  void setDrawingData(List<List<Map<String, double>>> drawingData) {
    _state?.setDrawingData(drawingData);
  }
  
  // Request current PDF view state
  Future<void> requestViewState() async {
    try {
      final viewState = await _channel.invokeMethod('getViewState');
      if (viewState != null) {
        _state?._updatePdfViewState(viewState as Map<String, dynamic>);
      }
    } catch (e) {
      // Ignore if not implemented on native side
    }
  }
  
}

/// Custom painter for drawing on PDF
class _PDFDrawingPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Offset> currentPath;
  final Color color;
  final double strokeWidth;
  final Size widgetSize;
  final double pdfZoom;
  final double pdfOffsetX;
  final double pdfOffsetY;
  final double pageWidth;
  final double pageHeight;

  _PDFDrawingPainter({
    required this.paths,
    required this.currentPath,
    required this.color,
    required this.strokeWidth,
    required this.widgetSize,
    required this.pdfZoom,
    required this.pdfOffsetX,
    required this.pdfOffsetY,
    required this.pageWidth,
    required this.pageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Helper function to convert PDF document coordinates to current widget coordinates
    Offset pdfToWidget(Offset pdfPos) {
      if (pdfZoom == 0 || pageWidth == 0 || pageHeight == 0 || widgetSize.isEmpty) {
        // Fallback to simple scaling if PDF state not available
        return Offset(pdfPos.dx * widgetSize.width, pdfPos.dy * widgetSize.height);
      }
      
      // Convert from normalized coordinates to actual page coordinates
      double pageX = pdfPos.dx * pageWidth;
      double pageY = pdfPos.dy * pageHeight;
      
      // Apply current zoom and pan offset to get widget coordinates
      double widgetX = (pageX * pdfZoom) - pdfOffsetX;
      double widgetY = (pageY * pdfZoom) - pdfOffsetY;
      
      return Offset(widgetX, widgetY);
    }

    // Draw completed paths (stored in PDF document coordinates, transform to current widget coordinates)
    for (final path in paths) {
      if (path.length > 1) {
        final drawPath = Path();
        final firstPoint = pdfToWidget(path.first);
        drawPath.moveTo(firstPoint.dx, firstPoint.dy);
        for (int i = 1; i < path.length; i++) {
          final point = pdfToWidget(path[i]);
          drawPath.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(drawPath, paint);
      }
    }

    // Draw current path being drawn (stored in PDF document coordinates, transform to current widget coordinates)
    if (currentPath.length > 1) {
      final drawPath = Path();
      final firstPoint = pdfToWidget(currentPath.first);
      drawPath.moveTo(firstPoint.dx, firstPoint.dy);
      for (int i = 1; i < currentPath.length; i++) {
        final point = pdfToWidget(currentPath[i]);
        drawPath.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(drawPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PDFDrawingPainter oldDelegate) {
    return paths != oldDelegate.paths || 
           currentPath != oldDelegate.currentPath ||
           color != oldDelegate.color ||
           strokeWidth != oldDelegate.strokeWidth ||
           widgetSize != oldDelegate.widgetSize ||
           pdfZoom != oldDelegate.pdfZoom ||
           pdfOffsetX != oldDelegate.pdfOffsetX ||
           pdfOffsetY != oldDelegate.pdfOffsetY ||
           pageWidth != oldDelegate.pageWidth ||
           pageHeight != oldDelegate.pageHeight;
  }
}
