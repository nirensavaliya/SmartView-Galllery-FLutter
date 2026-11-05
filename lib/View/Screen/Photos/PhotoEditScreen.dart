import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/View/Constant/InnerChrome.dart';
import 'package:gallery_photos/View/Widget/ChromeDialog.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class PhotoEditResult {
  final Uint8List bytes;
  final bool replaceOriginal;

  PhotoEditResult({
    required this.bytes,
    required this.replaceOriginal,
  });
}

class PhotoEditScreen extends StatelessWidget {
  final File file;

  const PhotoEditScreen({
    super.key,
    required this.file,
  });

  Future<PhotoEditResult?> _showSaveDialog(
      BuildContext context,
      Uint8List bytes,
      ) async {
    return showDialog<PhotoEditResult?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final RxBool dontAskAgain = false.obs;

        return Builder(
          builder: (context) {
            return ChromeDialog(
              title: 'Save file?',
              message:
                  'If you choose to replace the original, the original will be moved to Recently Deleted and kept there for 30 days.',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Obx(
                        () => Checkbox(
                          value: dontAskAgain.value,
                          activeColor: InnerChrome.accent,
                          side: BorderSide(color: InnerChrome.faint, width: 1.4),
                          onChanged: (value) {
                            dontAskAgain.value = value ?? false;
                          },
                        ),
                      ),
                      Expanded(
                        child: Text("Don't ask again", style: ChromeText.row),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ChromeButton.ok(
                    label: 'Save file',
                    onPressed: () {
                      Navigator.pop(
                        context,
                        PhotoEditResult(
                          bytes: bytes,
                          replaceOriginal: false,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  ChromeButton.danger(
                    label: 'Replace file',
                    onPressed: () {
                      Navigator.pop(
                        context,
                        PhotoEditResult(
                          bytes: bytes,
                          replaceOriginal: true,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  ChromeButton.cancel(
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      file,
      configs: ProImageEditorConfigs(
        i18n: I18n(
          doneLoadingMsg: '',
        ),
        dialogConfigs: DialogConfigs(
          widgets: DialogWidgets(
            loadingDialog: (message, configs) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
      ),
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (Uint8List bytes) async {
          final result = await _showSaveDialog(
            context,
            bytes,
          );

          if (result == null) {
            return;
          }

          Navigator.pop(
            context,
            result,
          );
        },
      ),
    );
  }
}