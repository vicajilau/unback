import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import 'core/image_processor.dart';
import 'ui/theme.dart';
import 'ui/widgets/checkerboard.dart';
import 'ui/widgets/split_slider.dart';

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

  int _processCounter = 0;
  final GlobalKey _previewKey = GlobalKey();

  /// Prompts the user to pick an image file.
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (result == null) return;

      final Uint8List bytes = await result.xFile.readAsBytes();

      setState(() {
        _isProcessing = true;
        _originalBytes = bytes;
        _processedBytes = null;
        _fileName = result.xFile.name;
        _isEyedropperActive = false;
      });

      // Decode the image in a background thread to get size and pixels
      final decoded = await compute(img.decodeImage, bytes);
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

  void _resetAll() {
    if (_originalBytes == null) return;

    // Reset back to first pixel color
    if (_decodedImg != null) {
      final firstPixel = _decodedImg!.getPixel(0, 0);
      setState(() {
        _selectedColor = Color.fromARGB(
          255,
          firstPixel.r.toInt(),
          firstPixel.g.toInt(),
          firstPixel.b.toInt(),
        );
      });
    }

    setState(() {
      _threshold = 30.0;
      _smoothness = 20.0;
      _viewMode = 'split';
      _previewBackground = 'transparent';
      _isEyedropperActive = false;
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
              onPressed: _resetAll,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: _originalBytes == null
            ? _buildUploadPrompt()
            : isDesktop
            ? Row(
                children: [
                  Expanded(flex: 3, child: _buildPreviewArea()),
                  Container(width: 1, color: const Color(0xFF334155)),
                  SizedBox(width: 380, child: _buildControlsPanel()),
                ],
              )
            : Column(
                children: [
                  Expanded(flex: 5, child: _buildPreviewArea()),
                  Container(height: 1, color: const Color(0xFF334155)),
                  Expanded(flex: 6, child: _buildControlsPanel()),
                ],
              ),
      ),
    );
  }

  /// Initial screen requesting the user to select an image file.
  Widget _buildUploadPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 320),
              decoration: BoxDecoration(
                color: AppTheme.surface.withAlpha(200),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primary.withAlpha(100),
                  width: 2,
                  style: BorderStyle.solid,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24.0,
                  horizontal: 24.0,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.image_search_rounded,
                          size: 48,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Load Image to Remove Background',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Supports PNG, JPG, JPEG, and WebP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.file_upload),
                        label: const Text('Choose File'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Top main image preview area showing processed/original comparison.
  Widget _buildPreviewArea() {
    final imageRatio = (_imageWidth > 0 && _imageHeight > 0)
        ? (_imageWidth / _imageHeight)
        : 1.0;

    return Stack(
      children: [
        // Checkerboard / Solid color backgrounds
        Positioned.fill(
          child: _previewBackground == 'transparent'
              ? const Checkerboard()
              : Container(
                  color: _previewBackground == 'white'
                      ? Colors.white
                      : Colors.black,
                ),
        ),

        // Image representation
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: LayoutBuilder(
              key: _previewKey,
              builder: (context, constraints) {
                final Size containerSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );

                final Widget originalImgWidget = Image.memory(
                  _originalBytes!,
                  fit: BoxFit.contain,
                );

                final Widget processedImgWidget = _processedBytes != null
                    ? Image.memory(_processedBytes!, fit: BoxFit.contain)
                    : const Center(child: CircularProgressIndicator());

                return MouseRegion(
                  cursor: _isEyedropperActive
                      ? SystemMouseCursors.precise
                      : MouseCursor.defer,
                  child: GestureDetector(
                    onTapUp: (details) {
                      if (_isEyedropperActive) {
                        _pickColorAt(details.localPosition, containerSize);
                      }
                    },
                    child: Builder(
                      builder: (context) {
                        if (_isEyedropperActive) {
                          // Always show original image during eyedropper selection
                          return Center(
                            child: AspectRatio(
                              aspectRatio: imageRatio,
                              child: Stack(
                                children: [
                                  Positioned.fill(child: originalImgWidget),
                                  // Eyedropper instruction overlay
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withAlpha(100),
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.colorize,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Tap anywhere to pick background color',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                    blurRadius: 4,
                                                    color: Colors.black,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // Normal View Modes
                        switch (_viewMode) {
                          case 'original':
                            return Center(
                              child: AspectRatio(
                                aspectRatio: imageRatio,
                                child: originalImgWidget,
                              ),
                            );
                          case 'processed':
                            return Center(
                              child: AspectRatio(
                                aspectRatio: imageRatio,
                                child: processedImgWidget,
                              ),
                            );
                          case 'split':
                          default:
                            return SplitSlider(
                              original: originalImgWidget,
                              processed: processedImgWidget,
                              aspectRatio: imageRatio,
                            );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Indicator when processing
        if (_isProcessing)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(200),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Processing...',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Controls panel (sidebar for desktop, bottom panel for mobile).
  Widget _buildControlsPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File Name & Details
          if (_fileName != null) ...[
            Text(
              _fileName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Resolution: ${_imageWidth.toInt()} x ${_imageHeight.toInt()}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // View Mode Toggle Tabs
          const Text(
            'VIEW MODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'split',
                label: Text('Compare'),
                icon: Icon(Icons.compare_arrows_rounded),
              ),
              ButtonSegment(
                value: 'processed',
                label: Text('Result'),
                icon: Icon(Icons.done_all_rounded),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (selection) {
              setState(() {
                _viewMode = selection.first;
              });
            },
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: 24),

          // Color Picker Section
          const Text(
            'COLOR TO REMOVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Color Display Box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.surfaceLight,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedColor.withAlpha(50),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RGB(${(_selectedColor.r * 255).round()}, ${(_selectedColor.g * 255).round()}, ${(_selectedColor.b * 255).round()})',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Target Background Color',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Eyedropper Button
                IconButton(
                  tooltip: 'Eyedropper tool',
                  icon: Icon(
                    Icons.colorize_rounded,
                    color: _isEyedropperActive
                        ? AppTheme.primary
                        : Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _isEyedropperActive = !_isEyedropperActive;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Parameters Sliders
          const Text(
            'ADJUSTMENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // Tolerance Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tolerance'),
              Text(
                _threshold.toInt().toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _threshold,
            min: 0.0,
            max: 200.0,
            onChanged: (value) {
              setState(() {
                _threshold = value;
              });
            },
            onChangeEnd: (_) => _processImage(),
          ),
          const SizedBox(height: 16),

          // Smoothness Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Smoothness'),
              Text(
                _smoothness.toInt().toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
          Slider(
            value: _smoothness,
            min: 0.0,
            max: 150.0,
            onChanged: (value) {
              setState(() {
                _smoothness = value;
              });
            },
            onChangeEnd: (_) => _processImage(),
          ),
          const SizedBox(height: 24),

          // Background Previews
          const Text(
            'BACKGROUND CHECK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildBackgroundOption(
                'transparent',
                Icons.grid_on_rounded,
                'Grid',
              ),
              const SizedBox(width: 8),
              _buildBackgroundOption('white', Icons.wb_sunny_rounded, 'Light'),
              const SizedBox(width: 8),
              _buildBackgroundOption('black', Icons.nightlight_round, 'Dark'),
            ],
          ),
          const SizedBox(height: 36),

          // Action Buttons
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: _processedBytes != null
                  ? AppTheme.primaryGradient
                  : null,
              color: _processedBytes == null ? AppTheme.surfaceLight : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: _processedBytes != null ? _exportImage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size.fromHeight(56),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded),
                  SizedBox(width: 10),
                  Text('Save Transparent PNG'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _pickImage,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open),
                SizedBox(width: 10),
                Text('Open Another Image'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOption(String value, IconData icon, String label) {
    final bool isSelected = _previewBackground == value;

    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? AppTheme.primary.withAlpha(30)
              : Colors.transparent,
          side: BorderSide(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          setState(() {
            _previewBackground = value;
          });
        },
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
