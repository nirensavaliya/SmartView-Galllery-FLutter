import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DecoyVaultScreen extends StatelessWidget {
  const DecoyVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? Colors.black : Colors.white,

      appBar: AppBar(
        backgroundColor:
        isDark ? Colors.black : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,

        title: Text(
          'Private',
          style: TextStyle(
            color:
            isDark ? Colors.white : Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),

        actions: [
          IconButton(
            onPressed: () {
              Get.back();
            },
            icon: Icon(
              Icons.lock_outline,
              color:
              isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),

      body: Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 70,
              color: isDark
                  ? Colors.white38
                  : Colors.black26,
            ),

            const SizedBox(height: 16),

            Text(
              'No photos or videos',
              style: TextStyle(
                color: isDark
                    ? Colors.white60
                    : Colors.black54,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}