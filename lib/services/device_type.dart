import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// An enumeration of possible device types.
/// Using an enum provides type-safety and makes the code more readable.
enum DeviceType {
  phone,
  tablet,
  macOS,
  windows,
  linux,
  web, // Added for web support
  unknown,
}

DeviceType? deviceType;

/// An asynchronous function that returns the type of the current device.
///
/// This function uses Flutter's `defaultTargetPlatform` to efficiently
/// and reliably check for the current platform.
Future<DeviceType> getDeviceType() async {
  // Use `kIsWeb` for web platforms.
  if (kIsWeb) {
    return DeviceType.web;
  }

  // Use a switch statement for cleaner platform-specific logic.
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // Note: Differentiating Android phones from tablets purely with
      // `device_info_plus` is not reliable. A better approach involves
      // checking the screen size via `MediaQuery`. For simplicity here,
      // we'll classify all Android devices as phones.
      return DeviceType.phone;

    case TargetPlatform.iOS:
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      // The `model` check is a common way to identify iPads.
      if (iosInfo.model.toLowerCase().contains('ipad')) {
        return DeviceType.tablet;
      } else {
        return DeviceType.phone;
      }

    case TargetPlatform.macOS:
      return DeviceType.macOS;

    case TargetPlatform.windows:
      return DeviceType.windows;

    case TargetPlatform.linux:
      return DeviceType.linux;

    default:
      // Fallback for other platforms like Fuchsia.
      return DeviceType.unknown;
  }
}