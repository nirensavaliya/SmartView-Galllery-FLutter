import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/Language/Controller/LanguageController.dart';
import 'package:get/get.dart';
import 'package:gallery_photos/View/Constant/App_Colors.dart';

class AppLanguageScreen extends StatelessWidget {
  AppLanguageScreen({super.key});

  final LanguageController controller =
  Get.find<LanguageController>();

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1C1C1C)
          : const Color(0xFFF7F7F7),

      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF1C1C1C)
            : const Color(0xFFF7F7F7),
        elevation: 0,

        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: 22,
          ),
        ),

        title: Text(
          'app_language'.tr,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),

        actions: [
          TextButton(
            onPressed: () async {
              await controller.applyLanguage();

              Get.back();
            },
            child: Text(
              'apply'.tr,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),

      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          18,
          16,
          18,
          20,
        ),
        itemCount: controller.languages.length,
        itemBuilder: (context, index) {
          final language =
          controller.languages[index];

          return Obx(
                () {
              final String code =
              language['code']!;

              final bool isSelected =
                  controller.selectedLanguage.value ==
                      code;

              return _buildLanguageItem(
                context,
                language,
                isSelected,
                isDark,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLanguageItem(
      BuildContext context,
      Map<String, String> language,
      bool isSelected,
      bool isDark,
      ) {
    final String code = language['code']!;

    return GestureDetector(
      onTap: () {
        controller.selectLanguage(code);
      },
      child: AnimatedContainer(
        duration:
        const Duration(milliseconds: 180),

        margin: const EdgeInsets.only(
          bottom: 16,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF25272E)
              : Colors.white,

          borderRadius:
          BorderRadius.circular(18),

          border: Border.all(
            color: isSelected
                ? Colors.blue
                : Colors.transparent,
            width: 2,
          ),
        ),

        child: Row(
          children: [

            Container(
              width: 58,
              height: 58,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _avatarColor(code),
              ),

              alignment: Alignment.center,

              child: Text(
                language['letter'] ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize:
                  (language['letter'] ?? '')
                      .length >
                      1
                      ? 18
                      : 27,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(width: 18),

Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _languageName(code),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : Colors.black,
                        fontSize: 19,
                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),

                    TextSpan(
                      text:
                      '  (${language['nativeName']})',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : Colors.black45,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

Container(
              width: 34,
              height: 34,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                border: Border.all(
                  color: isSelected
                      ? Colors.blue
                      : AppColors.border(Colors.grey.shade600),
                  width: 3,
                ),
              ),

              child: isSelected
                  ? Center(
                child: Container(
                  width: 18,
                  height: 18,

                  decoration:
                  const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                ),
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _languageName(String code) {
    switch (code) {
      case 'default':
        return 'default'.tr;

      case 'es':
        return 'spanish'.tr;

      case 'fil':
        return 'philippians'.tr;

      case 'pt':
        return 'portuguese'.tr;

      case 'hi':
        return 'hindi'.tr;

      case 'en':
      default:
        return 'english'.tr;
    }
  }
  Color _avatarColor(String code) {
    switch (code) {
      case 'es':
        return const Color(0xFF686F55);

      case 'fil':
        return const Color(0xFF7B6765);

      case 'pt':
        return const Color(0xFF65717D);

      case 'hi':
        return const Color(0xFF776A67);

      case 'en':
      default:
        return const Color(0xFF6E625F);
    }
  }
}