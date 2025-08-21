import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'helper/safe_value_notifier.dart';
import 'paint_contents/eraser.dart';
import 'paint_contents/paint_content.dart';
import 'paint_contents/simple_line.dart';
import 'paint_extension/ex_paint.dart';

/// 绘制参数
class DrawConfig {
  DrawConfig({
    required this.contentType,
    this.angle = 0,
    this.fingerCount = 0,
    this.size,
    this.blendMode = BlendMode.srcOver,
    this.color = Colors.red,
    this.colorFilter,
    this.filterQuality = FilterQuality.high,
    this.imageFilter,
    this.invertColors = false,
    this.isAntiAlias = false,
    this.maskFilter,
    this.shader,
    this.strokeCap = StrokeCap.round,
    this.strokeJoin = StrokeJoin.round,
    this.strokeWidth = 4,
    this.style = PaintingStyle.stroke,
  });

  DrawConfig.def({
    required this.contentType,
    this.angle = 0,
    this.fingerCount = 0,
    this.size,
    this.blendMode = BlendMode.srcOver,
    this.color = Colors.red,
    this.colorFilter,
    this.filterQuality = FilterQuality.high,
    this.imageFilter,
    this.invertColors = false,
    this.isAntiAlias = false,
    this.maskFilter,
    this.shader,
    this.strokeCap = StrokeCap.round,
    this.strokeJoin = StrokeJoin.round,
    this.strokeWidth = 4,
    this.style = PaintingStyle.stroke,
  });

  /// 旋转的角度（0:0,1:90,2:180,3:270）
  final int angle;

  final Type contentType;

  final int fingerCount;

  final Size? size;

  /// Paint相关
  final BlendMode blendMode;
  final Color color;
  final ColorFilter? colorFilter;
  final FilterQuality filterQuality;
  final ui.ImageFilter? imageFilter;
  final bool invertColors;
  final bool isAntiAlias;
  final MaskFilter? maskFilter;
  final Shader? shader;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
  final double strokeWidth;
  final PaintingStyle style;

  /// 生成paint
  Paint get paint => Paint()
    ..blendMode = blendMode
    ..color = color
    ..colorFilter = colorFilter
    ..filterQuality = filterQuality
    ..imageFilter = imageFilter
    ..invertColors = invertColors
    ..isAntiAlias = isAntiAlias
    ..maskFilter = maskFilter
    ..shader = shader
    ..strokeCap = strokeCap
    ..strokeJoin = strokeJoin
    ..strokeWidth = strokeWidth
    ..style = style;

  DrawConfig copyWith({
    Type? contentType,
    BlendMode? blendMode,
    Color? color,
    ColorFilter? colorFilter,
    FilterQuality? filterQuality,
    ui.ImageFilter? imageFilter,
    bool? invertColors,
    bool? isAntiAlias,
    MaskFilter? maskFilter,
    Shader? shader,
    StrokeCap? strokeCap,
    StrokeJoin? strokeJoin,
    double? strokeWidth,
    PaintingStyle? style,
    int? angle,
    int? fingerCount,
    Size? size,
  }) {
    return DrawConfig(
      contentType: contentType ?? this.contentType,
      angle: angle ?? this.angle,
      blendMode: blendMode ?? this.blendMode,
      color: color ?? this.color,
      colorFilter: colorFilter ?? this.colorFilter,
      filterQuality: filterQuality ?? this.filterQuality,
      imageFilter: imageFilter ?? this.imageFilter,
      invertColors: invertColors ?? this.invertColors,
      isAntiAlias: isAntiAlias ?? this.isAntiAlias,
      maskFilter: maskFilter ?? this.maskFilter,
      shader: shader ?? this.shader,
      strokeCap: strokeCap ?? this.strokeCap,
      strokeJoin: strokeJoin ?? this.strokeJoin,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      style: style ?? this.style,
      fingerCount: fingerCount ?? this.fingerCount,
      size: size ?? this.size,
    );
  }
}

/// 绘制控制器
class DrawingController extends ChangeNotifier {
  DrawingController({DrawConfig? config, PaintContent? content, String? uniqueId, GlobalKey? globalKey}) {
    _history = <PaintContent>[];
    _currentIndex = 0;
    realPainter = RePaintNotifier();
    painter = RePaintNotifier();
    drawConfig = SafeValueNotifier<DrawConfig>(
        config ?? DrawConfig.def(contentType: SimpleLine));
    setPaintContent(content ?? SimpleLine());
    // Use provided stable GlobalKey or create a new one
    painterKey = globalKey ?? GlobalKey(debugLabel: uniqueId ?? 'drawing_board_${DateTime.now().millisecondsSinceEpoch}');
    
    print('🎨 DRAW_CONTROLLER: constructor - controller hash: $hashCode');
    print('🎨 DRAW_CONTROLLER: constructor - painterKey: ${painterKey.toString()}');
    print('🎨 DRAW_CONTROLLER: constructor - uniqueId: $uniqueId');
    print('🎨 DRAW_CONTROLLER: constructor - globalKey provided: ${globalKey != null}');
  }

  /// 绘制开始点
  Offset? _startPoint;

  /// 画板数据Key
  late GlobalKey painterKey;

  /// 控制器
  late SafeValueNotifier<DrawConfig> drawConfig;

  /// 最后一次绘制的内容
  late PaintContent _paintContent;

  /// 当前绘制内容
  PaintContent? currentContent;

  /// 橡皮擦内容
  PaintContent? eraserContent;

  ui.Image? cachedImage;

  /// 底层绘制内容(绘制记录)
  late List<PaintContent> _history;

  /// 当前controller是否存在
  bool _mounted = true;

  /// 获取绘制图层/历史
  List<PaintContent> get getHistory => _history;

  /// 步骤指针
  late int _currentIndex;

  /// 表层画布刷新控制
  RePaintNotifier? painter;

  /// 底层画布刷新控制
  RePaintNotifier? realPainter;

  /// 是否绘制了有效内容
  bool _isDrawingValidContent = false;

  /// 获取当前步骤索引
  int get currentIndex => _currentIndex;

  /// 获取当前颜色
  Color get getColor => drawConfig.value.color;

  /// 能否开始绘制
  bool get couldStartDraw => drawConfig.value.fingerCount == 0;

  /// 能否进行绘制
  bool get couldDrawing => drawConfig.value.fingerCount == 1;

  /// 是否有正在绘制的内容
  bool get hasPaintingContent =>
      currentContent != null || eraserContent != null;

  /// 开始绘制点
  Offset? get startPoint => _startPoint;

  /// 设置画板大小
  void setBoardSize(Size? size) {
    print('🎨 DRAW_CONTROLLER: setBoardSize called with $size');
    print('🎨 DRAW_CONTROLLER: setBoardSize - controller hash: $hashCode');
    print('🎨 DRAW_CONTROLLER: setBoardSize - old size: ${drawConfig.value.size}');
    drawConfig.value = drawConfig.value.copyWith(size: size);
    print('🎨 DRAW_CONTROLLER: setBoardSize - new size: ${drawConfig.value.size}');
  }

  /// 手指落下
  void addFingerCount(Offset offset) {
    drawConfig.value = drawConfig.value
        .copyWith(fingerCount: drawConfig.value.fingerCount + 1);
  }

  /// 手指抬起
  void reduceFingerCount(Offset offset) {
    if (drawConfig.value.fingerCount <= 0) {
      return;
    }

    drawConfig.value = drawConfig.value
        .copyWith(fingerCount: drawConfig.value.fingerCount - 1);
  }

  /// 设置绘制样式
  void setStyle({
    BlendMode? blendMode,
    Color? color,
    ColorFilter? colorFilter,
    FilterQuality? filterQuality,
    ui.ImageFilter? imageFilter,
    bool? invertColors,
    bool? isAntiAlias,
    MaskFilter? maskFilter,
    Shader? shader,
    StrokeCap? strokeCap,
    StrokeJoin? strokeJoin,
    double? strokeMiterLimit,
    double? strokeWidth,
    PaintingStyle? style,
  }) {
    drawConfig.value = drawConfig.value.copyWith(
      blendMode: blendMode,
      color: color,
      colorFilter: colorFilter,
      filterQuality: filterQuality,
      imageFilter: imageFilter,
      invertColors: invertColors,
      isAntiAlias: isAntiAlias,
      maskFilter: maskFilter,
      shader: shader,
      strokeCap: strokeCap,
      strokeJoin: strokeJoin,
      strokeWidth: strokeWidth,
      style: style,
    );
  }

  /// 设置绘制内容
  void setPaintContent(PaintContent content) {
    content.paint = drawConfig.value.paint;
    _paintContent = content;
    drawConfig.value =
        drawConfig.value.copyWith(contentType: content.runtimeType);
  }

  /// 添加一条绘制数据
  void addContent(PaintContent content) {
    _history.add(content);
    _currentIndex++;
    cachedImage = null;
    _refreshDeep();
  }

  /// 添加多条数据
  void addContents(List<PaintContent> contents) {
    print('🎨 DRAW_CONTROLLER: addContents called with ${contents.length} contents');
    for (int i = 0; i < contents.length; i++) {
      print('🎨 DRAW_CONTROLLER: addContents - content $i: ${contents[i].runtimeType}, toString: ${contents[i].toString()}');
    }
    
    _history.addAll(contents);
    _currentIndex = _history.length;
    cachedImage = null;
    
    print('🎨 DRAW_CONTROLLER: addContents - new currentIndex: $_currentIndex, history length: ${_history.length}');
    _refreshDeep();
  }

  /// * 旋转画布
  /// * 设置角度
  void turn() {
    drawConfig.value =
        drawConfig.value.copyWith(angle: (drawConfig.value.angle + 1) % 4);
  }

  /// 开始绘制
  void startDraw(Offset startPoint) {
    print('🎨 DRAW_CONTROLLER: startDraw called at $startPoint');
    if (_currentIndex == 0 && _paintContent is Eraser) {
      print('🎨 DRAW_CONTROLLER: startDraw skipped - eraser with no content');
      return;
    }

    _startPoint = startPoint;
    print('🎨 DRAW_CONTROLLER: startDraw proceeding with ${_paintContent.runtimeType}');
    if (_paintContent is Eraser) {
      eraserContent = _paintContent.copy();
      eraserContent?.paint = drawConfig.value.paint.copyWith();
      eraserContent?.startDraw(startPoint);
      print('🎨 DRAW_CONTROLLER: Created eraser content');
    } else {
      currentContent = _paintContent.copy();
      currentContent?.paint = drawConfig.value.paint;
      currentContent?.startDraw(startPoint);
      print('🎨 DRAW_CONTROLLER: Created drawing content: ${currentContent.runtimeType}');
    }
  }

  /// 取消绘制
  void cancelDraw() {
    _startPoint = null;
    currentContent = null;
    eraserContent = null;
  }

  /// 正在绘制
  void drawing(Offset nowPaint) {
    if (!hasPaintingContent) {
      print('🎨 DRAW_CONTROLLER: drawing skipped - no painting content');
      return;
    }

    _isDrawingValidContent = true;
    print('🎨 DRAW_CONTROLLER: drawing at $nowPaint');

    if (_paintContent is Eraser) {
      eraserContent?.drawing(nowPaint);
      _refresh();
      _refreshDeep();
      print('🎨 DRAW_CONTROLLER: eraser drawing updated');
    } else {
      currentContent?.drawing(nowPaint);
      _refresh();
      print('🎨 DRAW_CONTROLLER: drawing content updated');
    }
  }

  /// 结束绘制
  void endDraw() {
    print('🎨 DRAW_CONTROLLER: endDraw called');
    if (!hasPaintingContent) {
      print('🎨 DRAW_CONTROLLER: endDraw skipped - no painting content');
      return;
    }

    if (!_isDrawingValidContent) {
      print('🎨 DRAW_CONTROLLER: endDraw - invalid content, cleaning up');
      // 清理绘制内容
      _startPoint = null;
      currentContent = null;
      eraserContent = null;
      return;
    }

    _isDrawingValidContent = false;
    print('🎨 DRAW_CONTROLLER: endDraw - valid content, adding to history');

    _startPoint = null;
    final int hisLen = _history.length;

    if (hisLen > _currentIndex) {
      _history.removeRange(_currentIndex, hisLen);
    }

    if (eraserContent != null) {
      _history.add(eraserContent!);
      _currentIndex = _history.length;
      eraserContent = null;
      print('🎨 DRAW_CONTROLLER: Added eraser to history. New index: $_currentIndex');
    }

    if (currentContent != null) {
      _history.add(currentContent!);
      _currentIndex = _history.length;
      currentContent = null;
      print('🎨 DRAW_CONTROLLER: Added drawing to history. New index: $_currentIndex, total history: ${_history.length}');
    }

    _refresh();
    _refreshDeep();
    notifyListeners();
    print('🎨 DRAW_CONTROLLER: endDraw completed - refreshed and notified');
  }

  /// 撤销
  void undo() {
    cachedImage = null;
    if (_currentIndex > 0) {
      _currentIndex = _currentIndex - 1;
      _refreshDeep();
      notifyListeners();
    }
  }

  /// Check if undo is available.
  /// Returns true if possible.
  bool canUndo() {
    if (_currentIndex > 0) {
      return true;
    } else {
      return false;
    }
  }

  /// 重做
  void redo() {
    cachedImage = null;
    if (_currentIndex < _history.length) {
      _currentIndex = _currentIndex + 1;
      _refreshDeep();
      notifyListeners();
    }
  }

  /// Check if redo is available.
  /// Returns true if possible.
  bool canRedo() {
    if (_currentIndex < _history.length) {
      return true;
    } else {
      return false;
    }
  }

  /// 清理画布
  void clear() {
    print('🎨 DRAW_CONTROLLER: clear called - before: currentIndex=$_currentIndex, history length=${_history.length}');
    cachedImage = null;
    _history.clear();
    _currentIndex = 0;
    print('🎨 DRAW_CONTROLLER: clear completed - after: currentIndex=$_currentIndex, history length=${_history.length}');
    _refreshDeep();
  }

  /// 获取图片数据
  Future<ByteData?> getImageData() async {
    try {
      final RenderRepaintBoundary boundary = painterKey.currentContext!
          .findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(
          pixelRatio: View.of(painterKey.currentContext!).devicePixelRatio);
      return await image.toByteData(format: ui.ImageByteFormat.png);
    } catch (e) {
      debugPrint('获取图片数据出错:$e');
      return null;
    }
  }

  /// 获取表层图片数据
  Future<ByteData?> getSurfaceImageData() async {
    try {
      if (cachedImage != null) {
        return await cachedImage!.toByteData(format: ui.ImageByteFormat.png);
      }
      return null;
    } catch (e) {
      debugPrint('获取表层图片数据出错:$e');
      return null;
    }
  }

  /// 获取画板内容Json
  List<Map<String, dynamic>> getJsonList() {
    print('🎨 DRAW_CONTROLLER: getJsonList called');
    print('🎨 DRAW_CONTROLLER: getJsonList - controller hash: $hashCode');
    print('🎨 DRAW_CONTROLLER: getJsonList - history length: ${_history.length}');
    print('🎨 DRAW_CONTROLLER: getJsonList - currentIndex: $_currentIndex');
    
    final jsonList = _history.map((PaintContent e) => e.toJson()).toList();
    print('🎨 DRAW_CONTROLLER: getJsonList - returned ${jsonList.length} items');
    for (int i = 0; i < jsonList.length; i++) {
      print('🎨 DRAW_CONTROLLER: getJsonList - item $i: ${jsonList[i]}');
    }
    
    return jsonList;
  }

  /// 刷新表层画板
  void _refresh() {
    print('🎨 DRAW_CONTROLLER: _refresh called - controller hash: $hashCode');
    print('🎨 DRAW_CONTROLLER: _refresh - currentContent: ${currentContent?.runtimeType}');
    painter?._refresh();
  }

  /// 刷新底层画板
  void _refreshDeep() {
    print('🎨 DRAW_CONTROLLER: _refreshDeep called - controller hash: $hashCode');
    print('🎨 DRAW_CONTROLLER: _refreshDeep - currentIndex: $_currentIndex');
    print('🎨 DRAW_CONTROLLER: _refreshDeep - history length: ${_history.length}');
    realPainter?._refresh();
  }

  /// 销毁控制器
  @override
  void dispose() {
    print('🎨 DRAW_CONTROLLER: dispose called - controller hash: $hashCode');
    print('🎨 DRAW_CONTROLLER: dispose - mounted: $_mounted');
    if (!_mounted) {
      print('🎨 DRAW_CONTROLLER: dispose - already disposed, returning');
      return;
    }

    print('🎨 DRAW_CONTROLLER: dispose - disposing resources');
    drawConfig.dispose();
    realPainter?.dispose();
    painter?.dispose();

    _mounted = false;
    print('🎨 DRAW_CONTROLLER: dispose completed - controller hash: $hashCode');

    super.dispose();
  }
}

/// 画布刷新控制器
class RePaintNotifier extends ChangeNotifier {
  void _refresh() {
    print('🎨 REPAINT_NOTIFIER: _refresh called - notifying listeners');
    notifyListeners();
  }
}
