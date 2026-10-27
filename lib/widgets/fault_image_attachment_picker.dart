import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

typedef FaultImagePickCallback = Future<XFile?> Function(ImageSource source);

class FaultImageAttachmentPicker extends StatefulWidget {
  final bool enabled;
  final FaultImagePickCallback? pickImage;
  final ValueChanged<XFile?>? onImageChanged;

  const FaultImageAttachmentPicker({
    super.key,
    this.enabled = true,
    this.pickImage,
    this.onImageChanged,
  });

  @override
  State<FaultImageAttachmentPicker> createState() =>
      _FaultImageAttachmentPickerState();
}

class _FaultImageAttachmentPickerState
    extends State<FaultImageAttachmentPicker> {
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  Uint8List? _imageBytes;

  bool _isPicking = false;

  Future<void> _showImageSourcePicker() async {
    if (!widget.enabled || _isPicking) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add Fault Photo',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 6),

                Text(
                  'Choose where you want to get the image from.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 20),

                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Camera'),
                  subtitle: const Text('Take a new photo'),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop(ImageSource.camera);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  subtitle: const Text('Choose an existing photo'),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isPicking = true;
    });

    try {
      final image = widget.pickImage != null
          ? await widget.pickImage!(source)
          : await _picker.pickImage(
              source: source,
              imageQuality: 80,
              maxWidth: 1600,
              requestFullMetadata: false,
            );

      if (image == null || !mounted) {
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
      });

      widget.onImageChanged?.call(image);
    } on PlatformException catch (_) {
      if (!mounted) {
        return;
      }

      _showError(
        'Unable to access the camera or gallery. Please check app permissions.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('Unable to select that image. Please try another photo.');
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
    });

    widget.onImageChanged?.call(null);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedImage != null && _imageBytes != null) {
      return _buildPreview(context);
    }

    return InkWell(
      key: const ValueKey('fault-image-picker'),
      borderRadius: BorderRadius.circular(14),
      onTap: widget.enabled ? _showImageSourcePicker : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: _isPicking
            ? const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading image...'),
                ],
              )
            : const Column(
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 36),
                  SizedBox(height: 10),
                  Text(
                    'Add a fault photo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text('Camera or Gallery'),
                ],
              ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                _imageBytes!,
                key: const ValueKey('fault-image-preview'),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Remove photo',
                  onPressed: widget.enabled ? _removeImage : null,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            const Icon(Icons.image_outlined, size: 18),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                _selectedImage!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            TextButton.icon(
              onPressed: widget.enabled ? _showImageSourcePicker : null,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Change'),
            ),
          ],
        ),
      ],
    );
  }
}
