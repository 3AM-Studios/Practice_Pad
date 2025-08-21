import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

/// 绘制对象
abstract class PaintContent {
  PaintContent();

  PaintContent.paint(this.paint);

  /// 画笔
  late Paint paint;

  /// 复制实例，避免对象传递
  PaintContent copy();

  /// 绘制核心方法
  /// * [deeper] 当前是否为底层绘制
  /// * 出于性能考虑
  /// * 绘制过程为表层绘制，绘制完成抬起手指时会进行底层绘制
  void draw(Canvas canvas, Size size, bool deeper) {
    print('🎨 PAINT_CONTENT: draw called - type: $runtimeType, deeper: $deeper, size: $size');
  }

  /// 正在绘制
  void drawing(Offset nowPoint) {
    print('🎨 PAINT_CONTENT: drawing called - type: $runtimeType, point: $nowPoint');
  }

  /// 开始绘制
  void startDraw(Offset startPoint) {
    print('🎨 PAINT_CONTENT: startDraw called - type: $runtimeType, point: $startPoint');
  }

  /// toJson
  Map<String, dynamic> toContentJson();

  /// contentType for web
  String get contentType => runtimeType.toString();

  /// toJson
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': contentType,
      ...toContentJson(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}
