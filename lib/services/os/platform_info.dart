import 'dart:io';

abstract class PlatformInfo {
  bool get isAndroid;
  bool get isIOS;
}

/// Production implementation using dart:io Platform.
class SystemPlatformInfo implements PlatformInfo {
  const SystemPlatformInfo();

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;
}

/// Test-only fake implementation.
class FakePlatformInfo implements PlatformInfo {
  FakePlatformInfo({required this.isAndroid, required this.isIOS});

  @override
  final bool isAndroid;

  @override
  final bool isIOS;
}
