import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
        bool dontAskAgain = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                "Save file?",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "If you choose to replace the original, "
                        "the original will be moved to Recently Deleted "
                        "and kept there for 30 days.",
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Checkbox(
                        value: dontAskAgain,
                        onChanged: (value) {
                          setState(() {
                            dontAskAgain = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          "Don't ask again",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      PhotoEditResult(
                        bytes: bytes,
                        replaceOriginal: false,
                      ),
                    );
                  },
                  child: const Text("Save file"),
                ),

                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      PhotoEditResult(
                        bytes: bytes,
                        replaceOriginal: true,
                      ),
                    );
                  },
                  child: const Text("Replace file"),
                ),
              ],
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