import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mach_alert/widgets/fault_image_attachment_picker.dart';

Uint8List createTestImageBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'
    'CAQAAAC1HAwCAAAAC0lEQVR42mP8/x8A'
    'AusB9Y9ZcNAAAAAASUVORK5CYII=',
  );
}

void main() {
  testWidgets('shows image attachment UI', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FaultImageAttachmentPicker())),
    );


    expect(find.text('Camera or Gallery'), findsOneWidget);
  });

  testWidgets('opens Camera and Gallery options', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FaultImageAttachmentPicker())),
    );

    await tester.tap(find.byKey(const ValueKey('fault-image-picker')));

    await tester.pumpAndSettle();

    expect(find.text('Camera'), findsOneWidget);

    expect(find.text('Gallery'), findsOneWidget);
  });

  testWidgets('selected gallery image displays preview', (tester) async {
    XFile? selectedImage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FaultImageAttachmentPicker(
            pickImage: (source) async {
              expect(source, ImageSource.gallery);

              return XFile.fromData(
                createTestImageBytes(),
                name: 'fault-photo.png',
                mimeType: 'image/png',
              );
            },
            onImageChanged: (image) {
              selectedImage = image;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('fault-image-picker')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Gallery'));

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fault-image-preview')), findsOneWidget);

    expect(find.text('fault-photo.png'), findsOneWidget);

    expect(selectedImage, isNotNull);
  });

  testWidgets('user can remove selected image', (tester) async {
    XFile? selectedImage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FaultImageAttachmentPicker(
            pickImage: (_) async {
              return XFile.fromData(
                createTestImageBytes(),
                name: 'fault-photo.png',
                mimeType: 'image/png',
              );
            },
            onImageChanged: (image) {
              selectedImage = image;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('fault-image-picker')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Gallery'));

    await tester.pumpAndSettle();

    expect(selectedImage, isNotNull);

    await tester.tap(find.byTooltip('Remove photo'));

    await tester.pump();

    expect(selectedImage, isNull);

    expect(find.text('Add a fault photo'), findsOneWidget);
  });
}
