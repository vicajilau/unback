import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

import 'core/image_processor.dart';
import 'ui/theme.dart';
import 'ui/widgets/drag_overlay.dart';
import 'ui/widgets/upload_prompt.dart';
import 'ui/widgets/preview_area.dart';
import 'ui/widgets/controls_panel.dart';

void main() {
  runApp(const BackgroundRemoverApp());
}

class BackgroundRemoverApp extends StatelessWidget {
  const BackgroundRemoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Remover',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Image properties
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;
  img.Image? _decodedImg;

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
  bool _isDragging = false;

  int _processCounter = 0;

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
    try {
      setState(() {
        _isProcessing = true;
        _processedBytes = null;
        _fileName = file.name;
        _isEyedropperActive = false;
      });

      final bytes = await file.readAsBytes();
      setState(() {
        _originalBytes = bytes;
      });

      // Decode the image in a background thread to get size and pixels
      final decoded = await compute(
        (Uint8List data) => img.decodeImage(data),
        bytes,
      );
      if (decoded == null) {
        throw Exception('Could not decode image files');
      }

      // Auto-pick the top-left pixel color as the initial key color
      final firstPixel = decoded.getPixel(0, 0);
      final initialColor = Color.fromARGB(
        255,
        firstPixel.r.toInt(),
        firstPixel.g.toInt(),
        firstPixel.b.toInt(),
      );

      setState(() {
        _decodedImg = decoded;
        _imageWidth = decoded.width.toDouble();
        _imageHeight = decoded.height.toDouble();
        _selectedColor = initialColor;
      });

      _processImage();
    } catch (e) {
      _showSnackBar('Error loading image: ${e.toString()}', isError: true);
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Runs the background removal algorithm in a background isolate.
  Future<void> _processImage() async {
    if (_originalBytes == null) return;

    final currentId = ++_processCounter;
    setState(() {
      _isProcessing = true;
    });

    try {
      final processed = await compute(ImageProcessor.removeBackground, {
        'bytes': _originalBytes!,
        'r': (_selectedColor.r * 255).round().clamp(0, 255),
        'g': (_selectedColor.g * 255).round().clamp(0, 255),
        'b': (_selectedColor.b * 255).round().clamp(0, 255),
        'threshold': _threshold,
        'smoothness': _smoothness,
      });

      if (currentId == _processCounter) {
        setState(() {
          _processedBytes = processed;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (currentId == _processCounter) {
        setState(() {
          _isProcessing = false;
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

      final pixel = _decodedImg!.getPixel(px, py);

      setState(() {
        _selectedColor = Color.fromARGB(
          255,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
        );
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
      final firstPixel = _decodedImg!.getPixel(0, 0);
      initialColor = Color.fromARGB(
        255,
        firstPixel.r.toInt(),
        firstPixel.g.toInt(),
        firstPixel.b.toInt(),
      );
    }

    setState(() {
      if (initialColor != null) {
        _selectedColor = initialColor;
      }
      _threshold = 30.0;
      _smoothness = 20.0;
      _viewMode = 'split';
      _previewBackground = 'transparent';
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
              child: _originalBytes == null
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
                            isEyedropperActive: _isEyedropperActive,
                            isProcessing: _isProcessing,
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
                            isEyedropperActive: _isEyedropperActive,
                            isProcessing: _isProcessing,
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
