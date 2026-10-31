import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/maintenance_update_model.dart';
import '../../services/maintenance_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/fault_image_attachment_picker.dart';

typedef MaintenanceStatusUpdateCallback = Future<void> Function(
  String status,
  String notes,
);

class MaintenanceDetailsScreen extends StatefulWidget {
  final String maintenanceId;
  final String title;
  final String machineName;
  final String technician;
  final String priority;
  final String status;
  final String dueDate;

  /// Optional callback for Day 18/Member 3 backend integration.
  final MaintenanceStatusUpdateCallback? onStatusUpdate;

  /// Optional [MaintenanceService] instance for Firestore operations.
  final MaintenanceService? maintenanceService;

  /// Optional [StorageService] instance for photo proof uploads.
  final StorageService? storageService;

  /// Optional image picker callback for testing photo attachment.
  final FaultImagePickCallback? pickImage;

  /// Optional initial update history for offline display or tests.
  final List<MaintenanceUpdateModel>? initialHistory;

  const MaintenanceDetailsScreen({
    super.key,
    required this.maintenanceId,
    required this.title,
    required this.machineName,
    required this.technician,
    required this.priority,
    required this.status,
    required this.dueDate,
    this.onStatusUpdate,
    this.maintenanceService,
    this.storageService,
    this.pickImage,
    this.initialHistory,
  });

  @override
  State<MaintenanceDetailsScreen> createState() =>
      _MaintenanceDetailsScreenState();
}

class _MaintenanceDetailsScreenState extends State<MaintenanceDetailsScreen> {
  late String _currentStatus;
  bool _isUpdating = false;

  MaintenanceService? get _resolvedMaintenanceService {
    if (widget.maintenanceService != null) {
      return widget.maintenanceService;
    }
    try {
      return Provider.of<MaintenanceService>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  StorageService get _effectiveStorageService {
    if (widget.storageService != null) {
      return widget.storageService!;
    }
    try {
      return Provider.of<StorageService>(context, listen: false);
    } catch (_) {
      return StorageService();
    }
  }

  static String _normalizeStatus(String status) {
    final lower = status.trim().toLowerCase();
    if (lower == 'resolved' || lower == 'completed') {
      return 'Completed';
    }
    if (lower == 'in progress') {
      return 'In Progress';
    }
    return 'Pending';
  }

  @override
  void initState() {
    super.initState();
    _currentStatus = _normalizeStatus(widget.status);
  }

  Future<void> _openStatusUpdateSheet() async {
    if (_isUpdating) {
      return;
    }

    final result = await showModalBottomSheet<_StatusUpdateResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return _StatusUpdateSheet(
          currentStatus: _currentStatus,
          pickImage: widget.pickImage,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    await _updateStatus(
      result.status,
      result.notes,
      proofImage: result.proofImage,
      proofImageBytes: result.proofImageBytes,
    );
  }

  Future<void> _updateStatus(
    String status,
    String notes, {
    XFile? proofImage,
    Uint8List? proofImageBytes,
  }) async {
    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      String? proofImageUrl;

      // Upload image to Firebase Storage if an image was picked and no URL was supplied
      if (proofImage != null && proofImageBytes != null) {
        final storage = _effectiveStorageService;
        final rawName = proofImage.name.trim();
        final rawPath = proofImage.path.trim();
        final pathName = rawPath.isNotEmpty
            ? rawPath.split(RegExp(r'[/\\]')).last.trim()
            : '';
        final candidateName = rawName.isNotEmpty ? rawName : pathName;
        final fileName = candidateName.isNotEmpty
            ? candidateName
            : 'maintenance_proof.jpg';
        final contentType = fileName.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';

        proofImageUrl = await storage.uploadImage(
          bytes: proofImageBytes,
          fileName: fileName,
          contentType: contentType,
          folder: 'maintenance_proofs',
        );
      }

      final service = _resolvedMaintenanceService;
      if (service != null) {
        await service.updateMaintenanceStatus(
          taskId: widget.maintenanceId,
          status: status,
          notes: notes.trim().isEmpty ? null : notes.trim(),
          proofImageUrl: proofImageUrl,
        );
      }

      if (widget.onStatusUpdate != null) {
        await widget.onStatusUpdate!(status, notes);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentStatus = _normalizeStatus(status);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maintenance status updated to $status.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String errorMessage;
      if (e is MaintenanceServiceException) {
        errorMessage = e.message;
      } else if (e is StorageServiceException) {
        errorMessage = e.message;
      } else {
        errorMessage = 'Unable to update maintenance status. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Maintenance Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),

              const SizedBox(height: 20),

              _buildInformationCard(),

              const SizedBox(height: 20),

              _buildDescriptionCard(),

              const SizedBox(height: 20),

              _buildTimelineCard(),

              const SizedBox(height: 20),

              _buildHistoryCard(),

              const SizedBox(height: 24),

              FilledButton.icon(
                key: const ValueKey('update-maintenance-status-button'),
                onPressed: _isUpdating ? null : _openStatusUpdateSheet,
                icon: _isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
                label: Text(
                  _isUpdating ? 'Updating...' : 'Update Maintenance Status',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.engineering_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 4),

                      Text(widget.maintenanceId),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(widget.priority),
                ),

                _MaintenanceStatusChip(status: _currentStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Information',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _DetailsRow(
              icon: Icons.precision_manufacturing_outlined,
              label: 'Machine',
              value: widget.machineName,
            ),

            const Divider(height: 24),

            _DetailsRow(
              icon: Icons.person_outline,
              label: 'Assigned To',
              value: widget.technician,
            ),

            const Divider(height: 24),

            _DetailsRow(
              icon: Icons.event_outlined,
              label: 'Due',
              value: widget.dueDate,
            ),

            const Divider(height: 24),

            _DetailsRow(
              icon: Icons.info_outline,
              label: 'Status',
              value: _currentStatus,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maintenance Notes',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'Inspect the reported machine issue, document findings, and complete the required maintenance checks.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            const _TimelineItem(
              icon: Icons.add_task,
              title: 'Maintenance task created',
              subtitle: 'Task added to maintenance queue',
            ),

            const SizedBox(height: 14),

            const _TimelineItem(
              icon: Icons.assignment_ind_outlined,
              title: 'Technician assigned',
              subtitle: 'Task assigned for maintenance',
            ),

            if (_currentStatus == 'In Progress' ||
                _currentStatus == 'Completed' ||
                _currentStatus == 'Resolved') ...[
              const SizedBox(height: 14),

              const _TimelineItem(
                icon: Icons.engineering_outlined,
                title: 'Maintenance started',
                subtitle: 'Technician started working on the task',
              ),
            ],

            if (_currentStatus == 'Completed' ||
                _currentStatus == 'Resolved') ...[
              const SizedBox(height: 14),

              const _TimelineItem(
                icon: Icons.check_circle_outline,
                title: 'Maintenance completed',
                subtitle: 'Maintenance work marked as completed',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      key: const ValueKey('maintenance-history-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Maintenance History',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHistoryContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    if (widget.initialHistory != null) {
      return _buildHistoryList(widget.initialHistory!);
    }

    final service = _resolvedMaintenanceService;
    if (service == null) {
      return const Text(
        'No maintenance update history available.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return StreamBuilder<List<MaintenanceUpdateModel>>(
      stream: service.streamMaintenanceUpdateHistory(widget.maintenanceId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load maintenance history.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final history = snapshot.data ?? const <MaintenanceUpdateModel>[];
        if (history.isEmpty) {
          return const Text(
            'No updates recorded yet.',
            style: TextStyle(color: Colors.grey),
          );
        }

        // Real-time status synchronization from the latest history entry
        if (history.isNotEmpty && !_isUpdating) {
          final latestStatus = _normalizeStatus(history.last.newStatus);
          if (_currentStatus != latestStatus) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isUpdating && _currentStatus != latestStatus) {
                setState(() {
                  _currentStatus = latestStatus;
                });
              }
            });
          }
        }

        return _buildHistoryList(history);
      },
    );
  }

  Widget _buildHistoryList(List<MaintenanceUpdateModel> history) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.length,
      separatorBuilder: (_, _) => const Divider(height: 16),
      itemBuilder: (context, index) {
        final update = history[index];
        return _MaintenanceHistoryItem(update: update);
      },
    );
  }
}

class _MaintenanceHistoryItem extends StatelessWidget {
  final MaintenanceUpdateModel update;

  const _MaintenanceHistoryItem({required this.update});

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Recent';
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final prev = update.previousStatus.isEmpty
        ? 'Pending'
        : update.previousStatus;
    final next = update.newStatus;

    return Container(
      key: ValueKey('history-entry-${update.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$prev → $next',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                _formatDateTime(update.updatedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Updated by: ${update.updatedBy}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Colors.grey[700]),
          ),
          if (update.hasNotes) ...[
            const SizedBox(height: 4),
            Text(update.notes!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (update.hasProofImage) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.photo_outlined, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  'Photo proof attached',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusUpdateSheet extends StatefulWidget {
  final String currentStatus;
  final FaultImagePickCallback? pickImage;

  const _StatusUpdateSheet({required this.currentStatus, this.pickImage});

  @override
  State<_StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends State<_StatusUpdateSheet> {
  static const List<String> _statuses = ['Pending', 'In Progress', 'Completed'];

  late String _selectedStatus;

  final TextEditingController _notesController = TextEditingController();

  XFile? _selectedProofImage;
  Uint8List? _proofImageBytes;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();

    _selectedStatus = widget.currentStatus;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourcePicker() async {
    if (_isPickingImage) return;

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
                  'Add Photo Proof',
                  style: Theme.of(bottomSheetContext).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose where you want to attach proof from.',
                  style: Theme.of(bottomSheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ListTile(
                  key: const ValueKey('pick-proof-camera'),
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Camera'),
                  subtitle: const Text('Take a new photo'),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop(ImageSource.camera);
                  },
                ),
                ListTile(
                  key: const ValueKey('pick-proof-gallery'),
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

    if (source == null || !mounted) return;

    await _pickProofImage(source);
  }

  Future<void> _pickProofImage(ImageSource source) async {
    setState(() {
      _isPickingImage = true;
    });

    try {
      final image = widget.pickImage != null
          ? await widget.pickImage!(source)
          : await ImagePicker().pickImage(
              source: source,
              imageQuality: 80,
              maxWidth: 1600,
              requestFullMetadata: false,
            );

      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedProofImage = image;
        _proofImageBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to select that image.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void _save() {
    Navigator.of(context).pop(
      _StatusUpdateResult(
        status: _selectedStatus,
        notes: _notesController.text.trim(),
        proofImage: _selectedProofImage,
        proofImageBytes: _proofImageBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + keyboardInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update Maintenance Status',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              'Select the current maintenance progress.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 20),

            Text(
              'Status',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statuses.map((status) {
                return ChoiceChip(
                  label: Text(status),
                  selected: _selectedStatus == status,
                  onSelected: (_) {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            TextField(
              key: const ValueKey('maintenance-update-notes'),
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Update Notes',
                hintText: 'Add maintenance notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            if (_selectedProofImage == null) ...[
              OutlinedButton.icon(
                key: const ValueKey('attach-maintenance-proof-button'),
                onPressed: _isPickingImage ? null : _showImageSourcePicker,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Attach Photo Proof (Optional)'),
              ),
            ] else ...[
              Container(
                key: const ValueKey('maintenance-proof-preview'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_proofImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          _proofImageBytes!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image, size: 40),
                        ),
                      )
                    else
                      const Icon(Icons.image, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Photo Proof Attached',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _selectedProofImage!.name.isNotEmpty
                                ? _selectedProofImage!.name
                                : 'proof.jpg',
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('remove-maintenance-proof-button'),
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _selectedProofImage = null;
                          _proofImageBytes = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            FilledButton.icon(
              key: const ValueKey('save-maintenance-status'),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Status'),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusUpdateResult {
  final String status;
  final String notes;
  final XFile? proofImage;
  final Uint8List? proofImageBytes;

  const _StatusUpdateResult({
    required this.status,
    required this.notes,
    this.proofImage,
    this.proofImageBytes,
  });
}

class _MaintenanceStatusChip extends StatelessWidget {
  final String status;

  const _MaintenanceStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Completed' || 'Resolved' => Colors.green,
      'In Progress' => Colors.blue,
      _ => Colors.orange,
    };

    return Chip(
      avatar: Icon(_statusIcon(status), size: 18, color: color),
      label: Text(status),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Completed':
      case 'Resolved':
        return Icons.check_circle_outline;

      case 'In Progress':
        return Icons.engineering_outlined;

      default:
        return Icons.schedule_outlined;
    }
  }
}

class _DetailsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailsRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),

              const SizedBox(height: 2),

              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 18, child: Icon(icon, size: 18)),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),

              const SizedBox(height: 3),

              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
