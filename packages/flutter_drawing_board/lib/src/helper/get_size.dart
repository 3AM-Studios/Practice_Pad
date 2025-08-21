import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef OnWidgetSizeChange = void Function(Size? size);

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);
  Size? oldSize;
  final OnWidgetSizeChange? onChange;

  @override
  void performLayout() {
    super.performLayout();

    final Size? newSize = child?.size;
    if (oldSize == newSize) {
      return;
    }

    print('🎨 GET_SIZE: performLayout - size changed from $oldSize to $newSize');
    oldSize = newSize;

    // ignore: unnecessary_cast
    (WidgetsBinding.instance as WidgetsBinding)
        .addPostFrameCallback((_) {
          print('🎨 GET_SIZE: postFrameCallback - calling onChange with size $newSize');
          onChange?.call(newSize);
        });
  }
}

class GetSize extends SingleChildRenderObjectWidget {
  const GetSize({
    super.key,
    required this.onChange,
    required Widget super.child,
  });
  final OnWidgetSizeChange onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }
}
