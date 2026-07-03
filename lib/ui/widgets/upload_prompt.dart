import 'package:flutter/material.dart';
import 'package:background_remover/l10n/app_localizations.dart';
import '../theme.dart';

/// The initial screen content inviting the user to pick or drop an image.
class UploadPrompt extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback? onPasteImage;

  const UploadPrompt({
    super.key,
    required this.onPickImage,
    this.onPasteImage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onPickImage,
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
                      Text(
                        l10n.loadImageTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.loadImageSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: onPickImage,
                            icon: const Icon(Icons.file_upload),
                            label: Text(l10n.chooseFile),
                          ),
                          if (onPasteImage != null)
                            OutlinedButton.icon(
                              onPressed: onPasteImage,
                              icon: const Icon(Icons.content_paste),
                              label: Text(
                                AppLocalizations.of(context).localeName == 'es'
                                    ? 'Pegar imagen'
                                    : 'Paste image',
                              ),
                            ),
                        ],
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
}
