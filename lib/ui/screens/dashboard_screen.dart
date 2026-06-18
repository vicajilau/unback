// ignore_for_file: avoid_print
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

import '../../core/image_processor.dart';
import '../theme.dart';
import '../widgets/drag_overlay.dart';
import '../widgets/upload_prompt.dart';
import '../widgets/preview_area.dart';
import '../widgets/controls_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Image properties
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;
  DecodedImage? _decodedImg;

  String? _fileName;
  double _imageWidth = 0;
  double _imageHeight = 0;

  // Algorithm settings
  Color _selectedColor = Colors.white;
  double _threshold = 30.0;
  double _smoothness = 20.0;

  // UI state
  bool _isProcessing = false;
  bool _isEyedropperActive = false;
  String _viewMode = 'split'; // 'split', 'original', 'processed'
  String _previewBackground = 'transparent'; // 'transparent', 'white', 'black'
  Color _customPreviewColor = const Color(
    0xFF8B5CF6,
  ); // Default custom color (Purple)
  bool _isDragging = false;
  String _loadingStatus = '';

  int _processCounter = 0;

  // Public getters/setters for testing purposes
  bool get isProcessing => _isProcessing;
  double get threshold => _threshold;
  double get smoothness => _smoothness;
  set threshold(double val) => setState(() => _threshold = val);
  set smoothness(double val) => setState(() => _smoothness = val);

  /// Prompts the user to pick an image file.
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (result == null) return;

      await loadImage(result.xFile);
    } catch (e) {
      _showSnackBar('Error picking image: ${e.toString()}', isError: true);
    }
  }

  /// Loads and decodes the image file, then triggers processing.
  Future<void> loadImage(XFile file) async {
    final stopwatch = Stopwatch()..start();
    print('[ImageLoader] 🚀 Starting loadImage for: ${file.name}');
    try {
      setState(() {
        _isProcessing = true;
        _loadingStatus = 'Loading file...';
        _originalBytes = null;
        _processedBytes = null;
        _fileName = file.name;
        _isEyedropperActive = false;
      });

      print(
        '[ImageLoader] [${stopwatch.elapsedMilliseconds}ms] Reading bytes from file...',
      );
      final bytes = await file.readAsBytes();
      print(
        '[ImageLoader] [${stopwatch.elapsedMilliseconds}ms] readAsBytes() finished. Size: ${bytes.length} bytes.',
      );

      setState(() {
        _originalBytes = bytes;
        _loadingStatus = 'Decoding image...';
      });

      // Decode the image in a background thread to get size and pixels
      print(
        '[ImageLoader] [${stopwatch.elapsedMilliseconds}ms] Starting image decoding...',
      );
      final decodeStopwatch = Stopwatch()..start();
      final decoded = await ImageProcessor.decodeImage(bytes);
      print(
        '[ImageLoader] [${stopwatch.elapsedMilliseconds}ms] decodeImage completed in ${decodeStopwatch.elapsedMilliseconds} ms.',
      );

      // Auto-pick the top-left pixel color as the initial key color
      final initialColor = decoded.getPixelColor(0, 0);

      setState(() {
        _decodedImg = decoded;
        _imageWidth = decoded.width.toDouble();
        _imageHeight = decoded.height.toDouble();
        _selectedColor = initialColor;
        _loadingStatus = 'Processing image...';
      });

      print(
        '[ImageLoader] [${stopwatch.elapsedMilliseconds}ms] Proceeding to background removal...',
      );
      _processImage();
    } catch (e) {
      print('[ImageLoader] ❌ Error loading image: ${e.toString()}');
      _showSnackBar('Error loading image: ${e.toString()}', isError: true);
      setState(() {
        _isProcessing = false;
        _loadingStatus = '';
      });
    }
  }

  /// Runs the background removal algorithm in a background isolate.
  Future<void> _processImage() async {
    if (_originalBytes == null) return;

    final currentId = ++_processCounter;
    final stopwatch = Stopwatch()..start();
    print(
      '[ImageProcessor] 🚀 [_processCounter=$currentId] Starting background removal...',
    );

    setState(() {
      _isProcessing = true;
      _loadingStatus = 'Removing background...';
    });

    if (currentId != _processCounter) {
      print(
        '[ImageProcessor] 🛑 Aborting process run $currentId as a newer process run $_processCounter is active.',
      );
      return;
    }

    try {
      final processed = await ImageProcessor.removeBackground(
        bytes: _originalBytes!,
        color: _selectedColor,
        threshold: _threshold,
        smoothness: _smoothness,
      );

      if (currentId == _processCounter) {
        print(
          '[ImageProcessor] ✅ Background removal completed in ${stopwatch.elapsedMilliseconds} ms.',
        );
        setState(() {
          _processedBytes = processed;
          _isProcessing = false;
          _loadingStatus = '';
        });
      } else {
        print(
          '[ImageProcessor] 🛑 Ignoring output of run $currentId; newer run $_processCounter took priority.',
        );
      }
    } catch (e) {
      print(
        '[ImageProcessor] ❌ Error during background removal: ${e.toString()}',
      );
      if (currentId == _processCounter) {
        setState(() {
          _isProcessing = false;
          _loadingStatus = '';
        });
        _showSnackBar(
          'Error processing background removal: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  /// Translates tap coordinates from the preview widget space to the image pixel space
  /// to select the target color.
  void _pickColorAt(Offset localOffset, Size containerSize) {
    if (_decodedImg == null) return;

    final double iW = _imageWidth;
    final double iH = _imageHeight;
    final double iAspect = iW / iH;

    final double cW = containerSize.width;
    final double cH = containerSize.height;
    final double cAspect = cW / cH;

    double dW, dH;
    double xOffset, yOffset;

    if (iAspect > cAspect) {
      // Width constrained
      dW = cW;
      dH = cW / iAspect;
      xOffset = 0;
      yOffset = (cH - dH) / 2;
    } else {
      // Height constrained
      dH = cH;
      dW = cH * iAspect;
      xOffset = (cW - dW) / 2;
      yOffset = 0;
    }

    final double tx = localOffset.dx;
    final double ty = localOffset.dy;

    // Verify touch falls inside actual scaled image boundaries
    if (tx >= xOffset &&
        tx <= xOffset + dW &&
        ty >= yOffset &&
        ty <= yOffset + dH) {
      final double rx = (tx - xOffset) / dW;
      final double ry = (ty - yOffset) / dH;

      final int px = (rx * iW).clamp(0, iW - 1).toInt();
      final int py = (ry * iH).clamp(0, iH - 1).toInt();

      final pixelColor = _decodedImg!.getPixelColor(px, py);

      setState(() {
        _selectedColor = pixelColor;
        _isEyedropperActive = false;
      });

      _processImage();
      _showSnackBar('Color picked successfully!');
    }
  }

  /// Exports the transparent processed PNG image using the platform-specific saver.
  Future<void> _exportImage() async {
    if (_processedBytes == null || _fileName == null) return;

    setState(() {
      _isProcessing = true;
    });

    final outputName = '${_fileName!.split('.').first}_transparent.png';
    try {
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save Transparent Image',
        fileName: outputName,
        type: FileType.custom,
        allowedExtensions: ['png'],
        bytes: _processedBytes!,
      );
      if (savedPath != null) {
        _showSnackBar('Image saved successfully: $savedPath');
      }
    } catch (e) {
      _showSnackBar('Failed to save image: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void resetAll() {
    if (_originalBytes == null) return;

    Color? initialColor;
    if (_decodedImg != null) {
      initialColor = _decodedImg!.getPixelColor(0, 0);
    }

    setState(() {
      if (initialColor != null) {
        _selectedColor = initialColor;
      }
      _threshold = 30.0;
      _smoothness = 20.0;
      _viewMode = 'split';
      _previewBackground = 'transparent';
      _customPreviewColor = const Color(0xFF8B5CF6);
      _isEyedropperActive = false;
      _processedBytes = null;
    });

    _processImage();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? Colors.redAccent : AppTheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Remover'),
        actions: [
          if (_originalBytes != null)
            IconButton(
              tooltip: 'Reset adjustments',
              icon: const Icon(Icons.refresh),
              onPressed: resetAll,
            ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (detail) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (detail) {
          setState(() {
            _isDragging = false;
          });
        },
        onDragDone: (detail) async {
          setState(() {
            _isDragging = false;
          });
          if (detail.files.isNotEmpty) {
            final file = detail.files.first;
            final name = file.name.toLowerCase();
            final hasValidExtension =
                name.endsWith('.png') ||
                name.endsWith('.jpg') ||
                name.endsWith('.jpeg') ||
                name.endsWith('.webp');

            final mimeType = file.mimeType?.toLowerCase();
            final hasValidMimeType =
                mimeType != null &&
                (mimeType == 'image/png' ||
                    mimeType == 'image/jpeg' ||
                    mimeType == 'image/webp');

            if (hasValidExtension || hasValidMimeType) {
              await loadImage(file);
            } else {
              _showSnackBar(
                'Unsupported file format. Please drop PNG, JPG, JPEG, or WebP.',
                isError: true,
              );
            }
          }
        },
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.surfaceGradient,
              ),
              child: _isProcessing && _originalBytes == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _loadingStatus.isNotEmpty
                                ? _loadingStatus
                                : 'Loading and decoding image...',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _originalBytes == null
                  ? UploadPrompt(onPickImage: _pickImage)
                  : isDesktop
                  ? Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: PreviewArea(
                            originalBytes: _originalBytes!,
                            processedBytes: _processedBytes,
                            decodedImg: _decodedImg,
                            imageWidth: _imageWidth,
                            imageHeight: _imageHeight,
                            viewMode: _viewMode,
                            previewBackground: _previewBackground,
                            customPreviewColor: _customPreviewColor,
                            isEyedropperActive: _isEyedropperActive,
                            isProcessing: _isProcessing,
                            loadingStatus: _loadingStatus,
                            onPickColorAt: _pickColorAt,
                          ),
                        ),
                        Container(width: 1, color: const Color(0xFF334155)),
                        SizedBox(
                          width: 380,
                          child: ControlsPanel(
                            fileName: _fileName,
                            imageWidth: _imageWidth,
                            imageHeight: _imageHeight,
                            viewMode: _viewMode,
                            onViewModeChanged: (val) =>
                                setState(() => _viewMode = val),
                            selectedColor: _selectedColor,
                            isEyedropperActive: _isEyedropperActive,
                            onToggleEyedropper: () => setState(
                              () => _isEyedropperActive = !_isEyedropperActive,
                            ),
                            threshold: _threshold,
                            onThresholdChanged: (val) =>
                                setState(() => _threshold = val),
                            onThresholdChangeEnd: (_) => _processImage(),
                            smoothness: _smoothness,
                            onSmoothnessChanged: (val) =>
                                setState(() => _smoothness = val),
                            onSmoothnessChangeEnd: (_) => _processImage(),
                            previewBackground: _previewBackground,
                            onBackgroundChanged: (val) =>
                                setState(() => _previewBackground = val),
                            customPreviewColor: _customPreviewColor,
                            onCustomColorChanged: (color) =>
                                setState(() => _customPreviewColor = color),
                            processedBytes: _processedBytes,
                            onExport: _exportImage,
                            onPickImage: _pickImage,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          flex: 5,
                          child: PreviewArea(
                            originalBytes: _originalBytes!,
                            processedBytes: _processedBytes,
                            decodedImg: _decodedImg,
                            imageWidth: _imageWidth,
                            imageHeight: _imageHeight,
                            viewMode: _viewMode,
                            previewBackground: _previewBackground,
                            customPreviewColor: _customPreviewColor,
                            isEyedropperActive: _isEyedropperActive,
                            isProcessing: _isProcessing,
                            loadingStatus: _loadingStatus,
                            onPickColorAt: _pickColorAt,
                          ),
                        ),
                        Container(height: 1, color: const Color(0xFF334155)),
                        Expanded(
                          flex: 6,
                          child: ControlsPanel(
                            fileName: _fileName,
                            imageWidth: _imageWidth,
                            imageHeight: _imageHeight,
                            viewMode: _viewMode,
                            onViewModeChanged: (val) =>
                                setState(() => _viewMode = val),
                            selectedColor: _selectedColor,
                            isEyedropperActive: _isEyedropperActive,
                            onToggleEyedropper: () => setState(
                              () => _isEyedropperActive = !_isEyedropperActive,
                            ),
                            threshold: _threshold,
                            onThresholdChanged: (val) =>
                                setState(() => _threshold = val),
                            onThresholdChangeEnd: (_) => _processImage(),
                            smoothness: _smoothness,
                            onSmoothnessChanged: (val) =>
                                setState(() => _smoothness = val),
                            onSmoothnessChangeEnd: (_) => _processImage(),
                            previewBackground: _previewBackground,
                            onBackgroundChanged: (val) =>
                                setState(() => _previewBackground = val),
                            customPreviewColor: _customPreviewColor,
                            onCustomColorChanged: (color) =>
                                setState(() => _customPreviewColor = color),
                            processedBytes: _processedBytes,
                            onExport: _exportImage,
                            onPickImage: _pickImage,
                          ),
                        ),
                      ],
                    ),
            ),
            if (_isDragging) const DragOverlay(),
          ],
        ),
      ),
    );
  }
}
