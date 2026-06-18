import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../theme.dart';

/// A dialog that allows users to pick a custom color using preselected palettes or a color wheel.
class CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const CustomColorPickerDialog({super.key, required this.initialColor});

  @override
  State<CustomColorPickerDialog> createState() =>
      _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<CustomColorPickerDialog> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155), width: 1.5),
      ),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom Background',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Flex Color Picker Container
            Flexible(
              child: SingleChildScrollView(
                child: ColorPicker(
                  color: _currentColor,
                  onColorChanged: (Color color) {
                    setState(() {
                      _currentColor = color;
                    });
                  },
                  width: 36,
                  height: 36,
                  borderRadius: 18,
                  spacing: 6,
                  runSpacing: 6,
                  wheelDiameter: 180,
                  heading: const Text(
                    'Select background color',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  subheading: const Text(
                    'Select color shade',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  wheelSubheading: const Text(
                    'Custom color shade',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  showColorCode: true,
                  colorCodeHasColor: true,
                  colorCodeTextStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  pickerTypeLabels: const <ColorPickerType, String>{
                    ColorPickerType.both: 'Presets',
                    ColorPickerType.wheel: 'Wheel',
                  },
                  pickersEnabled: const <ColorPickerType, bool>{
                    ColorPickerType.both: true,
                    ColorPickerType.wheel: true,
                    ColorPickerType.primary: false,
                    ColorPickerType.accent: false,
                    ColorPickerType.bw: false,
                    ColorPickerType.custom: false,
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _currentColor),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
