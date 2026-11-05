import 'package:flutter/material.dart';
import 'package:gallery_photos/View/Screen/For%20You/PeopleScreen.dart';
import 'package:get/get.dart';

import 'controller/FaceGroupController.dart';

class FacePeopleCard extends StatelessWidget {
  final FaceGroupController controller;

  const FacePeopleCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final List<FacePerson> people = controller.visiblePeople;

      if (people.isEmpty && !controller.isScanning.value) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'People',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(width: 5),

                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface,
                  ),

                  const Spacer(),

                  GestureDetector(
                    onTap: () {
                      Get.to(() => PeopleScreen(controller: controller));
                    },
                    child: Text(
                      'View all',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 122,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: people.length,
                itemBuilder: (context, index) {
                  final person = people[index];

                  return _PersonCircle(person: person, controller: controller);
                },
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PersonCircle extends StatelessWidget {
  final FacePerson person;
  final FaceGroupController controller;

  const _PersonCircle({required this.person, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.to(
          () => PeopleScreen(controller: controller, selectedPerson: person),
        );
      },
      child: SizedBox(
        width: 92,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: FutureBuilder(
                    future: controller.getCover(person),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          color: Colors.grey.withOpacity(.15),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final bytes = snapshot.data;

                      if (bytes == null) {
                        return Container(
                          color: Colors.grey.withOpacity(.15),
                          child: const Icon(
                            Icons.person,
                            size: 38,
                            color: Colors.grey,
                          ),
                        );
                      }

                      return Image.memory(bytes, fit: BoxFit.cover);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                person.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
