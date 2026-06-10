import '../utils/platform_detector.dart';

abstract interface class PlatformCapabilities {
  bool get supportsMenuBar;
  bool get supportsDragDrop;
  bool get supportsDynamicColor;
  bool get supportsWindowControls;
  bool get supportsTextSelection;
  bool get supportsKeyboardShortcuts;
  bool get supportsPredictiveBack;
  bool get hasArbitraryFileSelection;
  bool get supportsBackgroundDownloads;
  bool get supportsSystemNotifications;
  bool get hasNativeMenuBar;
  bool get supportsFileAssociations;
  bool get canOpenFileExternally;
  bool get needsStoragePermission;
}

class LivePlatformCapabilities implements PlatformCapabilities {
  const LivePlatformCapabilities();

  @override
  bool get supportsMenuBar => PlatformDetector.isMacOS || PlatformDetector.isDesktop;
  @override
  bool get supportsDragDrop => PlatformDetector.isDesktop;
  @override
  bool get supportsDynamicColor => PlatformDetector.isAndroid;
  @override
  bool get supportsWindowControls => PlatformDetector.isDesktop;
  @override
  bool get supportsTextSelection => PlatformDetector.isDesktop;
  @override
  bool get supportsKeyboardShortcuts => PlatformDetector.isDesktop;
  @override
  bool get supportsPredictiveBack => PlatformDetector.isAndroid;
  @override
  bool get hasArbitraryFileSelection => PlatformDetector.isDesktop;
  @override
  bool get supportsBackgroundDownloads => PlatformDetector.isDesktop;
  @override
  bool get supportsSystemNotifications => PlatformDetector.isDesktop;
  @override
  bool get hasNativeMenuBar => PlatformDetector.isMacOS;
  @override
  bool get supportsFileAssociations => PlatformDetector.isDesktop;
  @override
  bool get canOpenFileExternally => true;
  @override
  bool get needsStoragePermission => !PlatformDetector.isDesktop;
}

class TestPlatformCapabilities implements PlatformCapabilities {
  final bool _menuBar;
  final bool _dragDrop;
  final bool _dynamicColor;
  final bool _windowControls;
  final bool _textSelection;
  final bool _keyboardShortcuts;
  final bool _predictiveBack;
  final bool _arbitraryFileSelection;
  final bool _backgroundDownloads;
  final bool _systemNotifications;
  final bool _nativeMenuBar;
  final bool _fileAssociations;
  final bool _openFileExternally;
  final bool _storagePermission;

  const TestPlatformCapabilities({
    bool menuBar = false,
    bool dragDrop = false,
    bool dynamicColor = false,
    bool windowControls = false,
    bool textSelection = false,
    bool keyboardShortcuts = false,
    bool predictiveBack = false,
    bool arbitraryFileSelection = false,
    bool backgroundDownloads = false,
    bool systemNotifications = false,
    bool nativeMenuBar = false,
    bool fileAssociations = false,
    bool openFileExternally = true,
    bool storagePermission = true,
  }) : _menuBar = menuBar,
       _dragDrop = dragDrop,
       _dynamicColor = dynamicColor,
       _windowControls = windowControls,
       _textSelection = textSelection,
       _keyboardShortcuts = keyboardShortcuts,
       _predictiveBack = predictiveBack,
       _arbitraryFileSelection = arbitraryFileSelection,
       _backgroundDownloads = backgroundDownloads,
       _systemNotifications = systemNotifications,
       _nativeMenuBar = nativeMenuBar,
       _fileAssociations = fileAssociations,
       _openFileExternally = openFileExternally,
       _storagePermission = storagePermission;

  @override
  bool get supportsMenuBar => _menuBar;
  @override
  bool get supportsDragDrop => _dragDrop;
  @override
  bool get supportsDynamicColor => _dynamicColor;
  @override
  bool get supportsWindowControls => _windowControls;
  @override
  bool get supportsTextSelection => _textSelection;
  @override
  bool get supportsKeyboardShortcuts => _keyboardShortcuts;
  @override
  bool get supportsPredictiveBack => _predictiveBack;
  @override
  bool get hasArbitraryFileSelection => _arbitraryFileSelection;
  @override
  bool get supportsBackgroundDownloads => _backgroundDownloads;
  @override
  bool get supportsSystemNotifications => _systemNotifications;
  @override
  bool get hasNativeMenuBar => _nativeMenuBar;
  @override
  bool get supportsFileAssociations => _fileAssociations;
  @override
  bool get canOpenFileExternally => _openFileExternally;
  @override
  bool get needsStoragePermission => _storagePermission;
}
