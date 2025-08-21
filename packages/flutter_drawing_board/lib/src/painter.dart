import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../paint_contents.dart';
import 'drawing_controller.dart';
import 'helper/ex_value_builder.dart';
import 'paint_contents/paint_content.dart';

/// 绘图板
class Painter extends StatelessWidget {
  const Painter({
    super.key,
    required this.drawingController,
    this.clipBehavior = Clip.antiAlias,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
  });

  /// 绘制控制器
  final DrawingController drawingController;

  /// 开始拖动
  final Function(PointerDownEvent pde)? onPointerDown;

  /// 正在拖动
  final Function(PointerMoveEvent pme)? onPointerMove;

  /// 结束拖动
  final Function(PointerUpEvent pue)? onPointerUp;

  /// 边缘裁剪方式
  final Clip clipBehavior;

  /// 手指落下
  void _onPointerDown(PointerDownEvent pde) {
    print('🎨 PAINTER: _onPointerDown at ${pde.localPosition}');
    if (!drawingController.couldStartDraw) {
      print('🎨 PAINTER: _onPointerDown skipped - could not start draw');
      return;
    }

    print('🎨 PAINTER: _onPointerDown calling startDraw');
    drawingController.startDraw(pde.localPosition);
    onPointerDown?.call(pde);
  }

  /// 手指移动
  void _onPointerMove(PointerMoveEvent pme) {
    print('🎨 PAINTER: _onPointerMove at ${pme.localPosition}');
    if (!drawingController.couldDrawing) {
      print('🎨 PAINTER: _onPointerMove - could not draw');
      if (drawingController.hasPaintingContent) {
        print('🎨 PAINTER: _onPointerMove - ending draw due to invalid state');
        drawingController.endDraw();
      }

      return;
    }

    if (!drawingController.hasPaintingContent) {
      print('🎨 PAINTER: _onPointerMove - no painting content');
      return;
    }

    print('🎨 PAINTER: _onPointerMove calling drawing');
    drawingController.drawing(pme.localPosition);
    onPointerMove?.call(pme);
  }

  /// 手指抬起
  void _onPointerUp(PointerUpEvent pue) {
    print('🎨 PAINTER: _onPointerUp at ${pue.localPosition}');
    if (!drawingController.couldDrawing ||
        !drawingController.hasPaintingContent) {
      print('🎨 PAINTER: _onPointerUp skipped - could not draw or no painting content');
      return;
    }

    if (drawingController.startPoint == pue.localPosition) {
      print('🎨 PAINTER: _onPointerUp - single point draw');
      drawingController.drawing(pue.localPosition);
    }

    print('🎨 PAINTER: _onPointerUp calling endDraw');
    drawingController.endDraw();
    onPointerUp?.call(pue);
  }

  void _onPointerCancel(PointerCancelEvent pce) {
    print('🎨 PAINTER: _onPointerCancel');
    if (!drawingController.couldDrawing) {
      print('🎨 PAINTER: _onPointerCancel skipped - could not draw');
      return;
    }

    print('🎨 PAINTER: _onPointerCancel calling endDraw');
    drawingController.endDraw();
  }

  /// GestureDetector 占位
  void _onPanDown(DragDownDetails ddd) {}

  void _onPanUpdate(DragUpdateDetails dud) {}

  void _onPanEnd(DragEndDetails ded) {}

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: ExValueBuilder<DrawConfig>(
        valueListenable: drawingController.drawConfig,
        shouldRebuild: (DrawConfig p, DrawConfig n) =>
            p.fingerCount != n.fingerCount,
        builder: (_, DrawConfig config, Widget? child) {
          // 是否能拖动画布
          final bool isPanEnabled = config.fingerCount > 1;

          return GestureDetector(
            onPanDown: !isPanEnabled ? _onPanDown : null,
            onPanUpdate: !isPanEnabled ? _onPanUpdate : null,
            onPanEnd: !isPanEnabled ? _onPanEnd : null,
            child: child,
          );
        },
        child: ClipRect(
          clipBehavior: clipBehavior,
          child: RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              painter: _DeepPainter(controller: drawingController),
              child: RepaintBoundary(
                child: CustomPaint(
                  isComplex: true,
                  painter: _UpPainter(controller: drawingController),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 表层画板
class _UpPainter extends CustomPainter {
  _UpPainter({required this.controller}) : super(repaint: controller.painter);

  final DrawingController controller;

  @override
  void paint(Canvas canvas, Size size) {
    print('🎨 UP_PAINTER: paint called with size $size');
    if (!controller.hasPaintingContent) {
      print('🎨 UP_PAINTER: no painting content, skipping');
      return;
    }

    if (controller.eraserContent != null) {
      print('🎨 UP_PAINTER: drawing eraser content');
      canvas.saveLayer(Offset.zero & size, Paint());

      if (controller.cachedImage != null) {
        canvas.drawImage(controller.cachedImage!, Offset.zero, Paint());
        print('🎨 UP_PAINTER: drew cached image');
      }
      controller.eraserContent?.draw(canvas, size, false);

      canvas.restore();
    } else {
      print('🎨 UP_PAINTER: drawing current content: ${controller.currentContent.runtimeType}');
      controller.currentContent?.draw(canvas, size, false);
    }
    print('🎨 UP_PAINTER: paint completed');
  }

  @override
  bool shouldRepaint(covariant _UpPainter oldDelegate) {
    final shouldRepaint = oldDelegate.controller.currentContent != controller.currentContent;
    print('🎨 UP_PAINTER: shouldRepaint = $shouldRepaint');
    print('🎨 UP_PAINTER: old controller hash: ${oldDelegate.controller.hashCode}');
    print('🎨 UP_PAINTER: new controller hash: ${controller.hashCode}');
    print('🎨 UP_PAINTER: old currentContent: ${oldDelegate.controller.currentContent?.runtimeType}');
    print('🎨 UP_PAINTER: new currentContent: ${controller.currentContent?.runtimeType}');
    return shouldRepaint;
  }

}

/// 底层画板
class _DeepPainter extends CustomPainter {
  _DeepPainter({required this.controller})
      : super(repaint: controller.realPainter);
  final DrawingController controller;

  @override
  void paint(Canvas canvas, Size size) {
    print('🎨 DEEP_PAINTER: paint called with size $size');
    if (controller.eraserContent != null) {
      print('🎨 DEEP_PAINTER: skipping - eraser content active');
      return;
    }

    final List<PaintContent> contents = <PaintContent>[
      ...controller.getHistory,
      if (controller.eraserContent != null) controller.eraserContent!,
    ];

    print('🎨 DEEP_PAINTER: ${contents.length} contents to draw, currentIndex: ${controller.currentIndex}');
    if (contents.isEmpty) {
      print('🎨 DEEP_PAINTER: no contents, skipping');
      return;
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas tempCanvas = Canvas(
        recorder, Rect.fromPoints(Offset.zero, size.bottomRight(Offset.zero)));

    canvas.saveLayer(Offset.zero & size, Paint());

    for (int i = 0; i < controller.currentIndex; i++) {
      print('🎨 DEEP_PAINTER: drawing content $i: ${contents[i].runtimeType}');
      contents[i].draw(canvas, size, true);
      contents[i].draw(tempCanvas, size, true);
    }

    canvas.restore();
    print('🎨 DEEP_PAINTER: drew ${controller.currentIndex} contents');

    final ui.Picture picture = recorder.endRecording();
    
    // Prevent invalid image dimensions crash
    final int width = size.width.toInt();
    final int height = size.height.toInt();
    
    if (width > 0 && height > 0) {
      picture
          .toImage(width, height)
          .then((ui.Image value) {
        controller.cachedImage = value;
      });
    }
  }

  @override
  bool shouldRepaint(covariant _DeepPainter oldDelegate) {
    final indexChanged = oldDelegate.controller.currentIndex != controller.currentIndex;
    final historyChanged = oldDelegate.controller.getHistory.length != controller.getHistory.length;
    final shouldRepaint = indexChanged || historyChanged;
    print('🎨 DEEP_PAINTER: shouldRepaint = $shouldRepaint');
    print('🎨 DEEP_PAINTER: old controller hash: ${oldDelegate.controller.hashCode}');
    print('🎨 DEEP_PAINTER: new controller hash: ${controller.hashCode}');
    print('🎨 DEEP_PAINTER: old currentIndex: ${oldDelegate.controller.currentIndex}');
    print('🎨 DEEP_PAINTER: new currentIndex: ${controller.currentIndex}');
    print('🎨 DEEP_PAINTER: old history length: ${oldDelegate.controller.getHistory.length}');
    print('🎨 DEEP_PAINTER: new history length: ${controller.getHistory.length}');
    return shouldRepaint;
  }
}
