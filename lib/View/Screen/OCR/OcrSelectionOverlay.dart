import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/OCR/Controller/OcrController.dart';
import 'package:get/get.dart';

class OcrSelectionOverlay extends StatefulWidget {
  final OcrController controller;

  const OcrSelectionOverlay({super.key, required this.controller});

  @override
  State<OcrSelectionOverlay> createState() => _OcrSelectionOverlayState();
}

class _OcrSelectionOverlayState extends State<OcrSelectionOverlay> {
  final Set<int> selectedIndexes = {};

  int? startIndex;
  int? endIndex;

  bool isSelecting = false;

  bool draggingStartHandle = false;
  bool draggingEndHandle = false;

  Offset? startHandleDragPosition;
  Offset? endHandleDragPosition;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (widget.controller.words.isEmpty) {
        return const SizedBox.shrink();
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final Rect imageRect = _calculateImageRect(
            constraints.biggest,
            widget.controller.imageWidth,
            widget.controller.imageHeight,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,

                  onLongPressStart: (details) {
                    if (draggingStartHandle || draggingEndHandle) {
                      return;
                    }
                    final int? index = _findWordAtPosition(
                      details.localPosition,
                      imageRect,
                    );
                    if (index == null) {
                      return;
                    }
                    setState(() {
                      isSelecting = true;

                      startIndex = index;
                      endIndex = index;

                      selectedIndexes.clear();
                      selectedIndexes.add(index);
                    });

                    _updateSelectedText();
                  },

                  onLongPressMoveUpdate: (details) {
                    if (!isSelecting || startIndex == null) {
                      return;
                    }

                    final int? index = _findNearestWord(
                      details.localPosition,
                      imageRect,
                    );

                    if (index == null) {
                      return;
                    }

                    setState(() {
                      endIndex = index;

                      _selectRange(startIndex!, index);
                    });

                    _updateSelectedText();
                  },

                  onLongPressEnd: (_) {
                    setState(() {
                      isSelecting = false;
                    });

                    _updateSelectedText();
                  },
                  child: CustomPaint(
                    painter: _OcrSelectionPainter(
                      words: widget.controller.words,
                      selectedIndexes: selectedIndexes,
                      imageWidth: widget.controller.imageWidth,
                      imageHeight: widget.controller.imageHeight,
                      imageRect: imageRect,
                      startIndex: startIndex,
                      endIndex: endIndex,
                    ),
                  ),
                ),
              ),

              if (startIndex != null && selectedIndexes.isNotEmpty)
                _buildStartHandle(imageRect),

              if (endIndex != null && selectedIndexes.isNotEmpty)
                _buildEndHandle(imageRect),
              if (selectedIndexes.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 90,
                  child: SafeArea(
                    top: false,
                    child: _SelectionToolbar(
                      selectedText: widget.controller.selectedText.value,
                      onCopy: () async {
                        await widget.controller.copySelectedText();

                        if (!mounted) return;

                        _clearSelection();
                      },
                      onClear: _clearSelection,
                    ),
                  ),
                ),

              Positioned(
                top: 60,
                right: 20,
                child: SafeArea(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }
  Widget _buildStartHandle(Rect imageRect) {
    final Offset position = _getHandlePosition(
      startIndex!,
      imageRect,
      isStart: true,
    );

    return Positioned(
      left: position.dx - 28,
      top: position.dy - 10,
      width: 56,
      height: 65,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onPanStart: (_) {
          setState(() {
            draggingStartHandle = true;

            startHandleDragPosition = position;
          });
        },

        onPanUpdate: (details) {
          if (!draggingStartHandle) {
            return;
          }

          if (startHandleDragPosition == null) {
            return;
          }

          startHandleDragPosition = startHandleDragPosition! + details.delta;

          final int? index = _findNearestWord(
            startHandleDragPosition!,
            imageRect,
          );

          if (index == null) {
            return;
          }

          setState(() {
            startIndex = index;

            _selectRange(startIndex!, endIndex ?? startIndex!);
          });

          _updateSelectedText();
        },

        onPanEnd: (_) {
          setState(() {
            draggingStartHandle = false;
            startHandleDragPosition = null;
          });

          _updateSelectedText();
        },

        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildEndHandle(Rect imageRect) {
    final Offset position = _getHandlePosition(
      endIndex!,
      imageRect,
      isStart: false,
    );

    return Positioned(
      left: position.dx - 28,
      top: position.dy - 10,
      width: 56,
      height: 65,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onPanStart: (_) {
          setState(() {
            draggingEndHandle = true;

            endHandleDragPosition = position;
          });
        },

        onPanUpdate: (details) {
          if (!draggingEndHandle) {
            return;
          }

          if (endHandleDragPosition == null) {
            return;
          }

          endHandleDragPosition = endHandleDragPosition! + details.delta;

          final int? index = _findNearestWord(
            endHandleDragPosition!,
            imageRect,
          );

          if (index == null) {
            return;
          }

          setState(() {
            endIndex = index;

            _selectRange(startIndex ?? endIndex!, endIndex!);
          });

          _updateSelectedText();
        },

        onPanEnd: (_) {
          setState(() {
            draggingEndHandle = false;
            endHandleDragPosition = null;
          });

          _updateSelectedText();
        },

        child: const SizedBox.expand(),
      ),
    );
  }

  // ===============================================================
  // HANDLE POSITION
  // ===============================================================

  Offset _getHandlePosition(
    int index,
    Rect imageRect, {
    required bool isStart,
  }) {
    if (index < 0 || index >= widget.controller.words.length) {
      return Offset.zero;
    }

    final Rect rect = _mapWordRect(
      widget.controller.words[index].boundingBox,
      imageRect,
    );

    return Offset(isStart ? rect.left : rect.right, rect.bottom + 5);
  }

  // ===============================================================
  // FIND WORD
  // ===============================================================

  int? _findWordAtPosition(Offset position, Rect imageRect) {
    for (int i = 0; i < widget.controller.words.length; i++) {
      final Rect rect = _mapWordRect(
        widget.controller.words[i].boundingBox,
        imageRect,
      );

      if (rect.inflate(10).contains(position)) {
        return i;
      }
    }

    return _findNearestWord(position, imageRect);
  }

  // ===============================================================
  // FIND NEAREST WORD
  // ===============================================================

  int? _findNearestWord(Offset position, Rect imageRect) {
    if (widget.controller.words.isEmpty) {
      return null;
    }

    double minimumDistance = double.infinity;
    int? nearestIndex;

    for (int i = 0; i < widget.controller.words.length; i++) {
      final Rect rect = _mapWordRect(
        widget.controller.words[i].boundingBox,
        imageRect,
      );

      // Directly touching a word
      if (rect.inflate(12).contains(position)) {
        return i;
      }

      final double dx = rect.center.dx - position.dx;

      final double dy = rect.center.dy - position.dy;

      final double distance = (dx * dx) + (dy * dy);

      if (distance < minimumDistance) {
        minimumDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  // ===============================================================
  // SELECT RANGE
  // ===============================================================

  void _selectRange(int first, int last) {
    selectedIndexes.clear();

    final int start = first < last ? first : last;

    final int end = first < last ? last : first;

    for (int i = start; i <= end; i++) {
      selectedIndexes.add(i);
    }
  }

  // ===============================================================
  // UPDATE TEXT
  // ===============================================================

  void _updateSelectedText() {
    final List<int> indexes = selectedIndexes.toList()..sort();

    final List<OcrWord> selectedWords = indexes
        .map((index) => widget.controller.words[index])
        .toList();

    widget.controller.setSelectedText(selectedWords);
  }

  // ===============================================================
  // CLEAR
  // ===============================================================

  void _clearSelection() {
    setState(() {
      selectedIndexes.clear();

      startIndex = null;
      endIndex = null;

      isSelecting = false;

      draggingStartHandle = false;
      draggingEndHandle = false;

      startHandleDragPosition = null;
      endHandleDragPosition = null;
    });

    widget.controller.selectedText.value = '';
  }

  // ===============================================================
  // IMAGE RECT
  // ===============================================================

  Rect _calculateImageRect(
    Size availableSize,
    double imageWidth,
    double imageHeight,
  ) {
    if (imageWidth <= 0 || imageHeight <= 0) {
      return Rect.zero;
    }

    final double imageAspect = imageWidth / imageHeight;

    final double containerAspect = availableSize.width / availableSize.height;

    double width;
    double height;

    if (imageAspect > containerAspect) {
      width = availableSize.width;
      height = width / imageAspect;
    } else {
      height = availableSize.height;
      width = height * imageAspect;
    }

    return Rect.fromLTWH(
      (availableSize.width - width) / 2,
      (availableSize.height - height) / 2,
      width,
      height,
    );
  }

  // ===============================================================
  // MAP OCR RECT
  // ===============================================================

  Rect _mapWordRect(Rect source, Rect imageRect) {
    final double scaleX = imageRect.width / widget.controller.imageWidth;

    final double scaleY = imageRect.height / widget.controller.imageHeight;

    return Rect.fromLTRB(
      imageRect.left + source.left * scaleX,
      imageRect.top + source.top * scaleY,
      imageRect.left + source.right * scaleX,
      imageRect.top + source.bottom * scaleY,
    );
  }
}

// ===================================================================
// PAINTER
// ===================================================================

class _OcrSelectionPainter extends CustomPainter {
  final List<OcrWord> words;

  final Set<int> selectedIndexes;

  final double imageWidth;
  final double imageHeight;

  final Rect imageRect;

  final int? startIndex;
  final int? endIndex;

  _OcrSelectionPainter({
    required this.words,
    required this.selectedIndexes,
    required this.imageWidth,
    required this.imageHeight,
    required this.imageRect,
    required this.startIndex,
    required this.endIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) {
      return;
    }

    final double scaleX = imageRect.width / imageWidth;

    final double scaleY = imageRect.height / imageHeight;

    final Paint highlightPaint = Paint()
      ..color = Colors.blue.withOpacity(0.40)
      ..style = PaintingStyle.fill;

    // ---------------------------------------------------------------
    // BLUE SELECTED TEXT
    // ---------------------------------------------------------------

    for (final int index in selectedIndexes) {
      if (index < 0 || index >= words.length) {
        continue;
      }

      final Rect source = words[index].boundingBox;

      final Rect rect = Rect.fromLTRB(
        imageRect.left + source.left * scaleX,
        imageRect.top + source.top * scaleY,
        imageRect.left + source.right * scaleX,
        imageRect.top + source.bottom * scaleY,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(1), const Radius.circular(3)),
        highlightPaint,
      );
    }

    // ---------------------------------------------------------------
    // START HANDLE
    // ---------------------------------------------------------------

    if (startIndex != null && selectedIndexes.isNotEmpty) {
      _drawHandle(
        canvas,
        _mapRect(words[startIndex!].boundingBox),
        isStart: true,
      );
    }

    // ---------------------------------------------------------------
    // END HANDLE
    // ---------------------------------------------------------------

    if (endIndex != null && selectedIndexes.isNotEmpty) {
      _drawHandle(
        canvas,
        _mapRect(words[endIndex!].boundingBox),
        isStart: false,
      );
    }
  }

  Rect _mapRect(Rect source) {
    final double scaleX = imageRect.width / imageWidth;

    final double scaleY = imageRect.height / imageHeight;

    return Rect.fromLTRB(
      imageRect.left + source.left * scaleX,
      imageRect.top + source.top * scaleY,
      imageRect.left + source.right * scaleX,
      imageRect.top + source.bottom * scaleY,
    );
  }

  void _drawHandle(Canvas canvas, Rect rect, {required bool isStart}) {
    final Paint paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final Offset position = Offset(
      isStart ? rect.left : rect.right,
      rect.bottom + 5,
    );

    // Circle
    canvas.drawCircle(position, 7, paint);

    // Small connector
    canvas.drawRect(
      Rect.fromLTWH(position.dx - 2, rect.bottom - 2, 4, 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OcrSelectionPainter oldDelegate) {
    return true;
  }
}

// ===================================================================
// TOOLBAR
// ===================================================================

class _SelectionToolbar extends StatelessWidget {
  final String selectedText;

  final VoidCallback onCopy;
  final VoidCallback onClear;

  const _SelectionToolbar({
    required this.selectedText,
    required this.onCopy,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    selectedText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),

              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, color: Colors.white),
                tooltip: 'Copy',
              ),

              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Clear',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
