import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/fault_model.dart';
import '../../models/machine_model.dart';
import '../../services/fault_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/fault_image_attachment_picker.dart';
import '../../widgets/main_bottom_navigation.dart';

class FaultReportingScreen extends StatefulWidget {
  final List<MachineModel> machines;
  final MachineModel? initialMachine;
  final FaultService? faultService;
  final StorageService? storageService;
  final FaultImagePickCallback? pickImage;

  const FaultReportingScreen({
    super.key,
    this.machines = const [],
    this.initialMachine,
    this.faultService,
    this.storageService,
    this.pickImage,
  });

  @override
  State<FaultReportingScreen> createState() => _FaultReportingScreenState();
}

class _FaultReportingScreenState extends State<FaultReportingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _descriptionController = TextEditingController();

  String? _selectedMachineId;
  String? _selectedFaultType;
  String? _selectedSeverity;

  XFile? _selectedImage;

  bool _isSubmitting = false;
  bool _showSeverityError = false;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialMachine;

    if (initial != null) {
      _selectedMachineId = initial.id;
    } else if (widget.machines.isNotEmpty) {
      _selectedMachineId = widget.machines.first.id;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();

    super.dispose();
  }

  List<MachineModel> get _availableMachines {
    final machines = [...widget.machines];

    final initial = widget.initialMachine;

    if (initial != null &&
        !machines.any((machine) => machine.id == initial.id)) {
      machines.insert(0, initial);
    }

    return machines;
  }

  MachineModel? get _selectedMachine {
    if (_selectedMachineId == null) {
      return null;
    }

    for (final machine in _availableMachines) {
      if (machine.id == _selectedMachineId) {
        return machine;
      }
    }

    return null;
  }

  FaultService get _effectiveFaultService {
    if (widget.faultService != null) {
      return widget.faultService!;
    }

    try {
      return Provider.of<FaultService>(context, listen: false);
    } catch (_) {
      return FaultService();
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

  String _determineContentType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }

    return 'image/jpeg';
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final formValid = _formKey.currentState?.validate() ?? false;

    final hasMachine =
        _selectedMachineId != null && _selectedMachineId!.trim().isNotEmpty;

    final hasFaultType =
        _selectedFaultType != null && _selectedFaultType!.trim().isNotEmpty;

    final hasSeverity =
        _selectedSeverity != null && _selectedSeverity!.trim().isNotEmpty;

    final description = _descriptionController.text.trim();

    final hasDescription = description.length >= 10;

    setState(() {
      _showSeverityError = !hasSeverity;
    });

    if (!hasMachine) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a machine first.')),
      );
    }

    if (!formValid ||
        !hasMachine ||
        !hasFaultType ||
        !hasSeverity ||
        !hasDescription) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? imageUrl;

      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();

        if (!mounted) {
          return;
        }

        final rawName = _selectedImage!.name.trim();

        final rawPath = _selectedImage!.path.trim();

        final pathName = rawPath.isNotEmpty
            ? rawPath.split(RegExp(r'[/\\]')).last.trim()
            : '';

        final candidate = rawName.isNotEmpty ? rawName : pathName;

        final fileName = candidate.isNotEmpty ? candidate : 'fault_image.jpg';

        imageUrl = await _effectiveStorageService.uploadFaultImage(
          bytes: bytes,
          fileName: fileName,
          contentType: _determineContentType(fileName),
        );

        if (!mounted) {
          return;
        }
      }

      final fault = FaultModel(
        id: '',
        machineId: _selectedMachineId!.trim(),
        machineName: _selectedMachine?.name,
        type: _selectedFaultType!.trim(),
        severity: _selectedSeverity!.trim(),
        description: description,
        reportedBy: '',
        status: AppConstants.faultStatusOpen,
        imageUrl: imageUrl,
      );

      final docId = await _effectiveFaultService.addFault(fault);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fault report submitted successfully.')),
      );

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(docId);
      }
    } on StorageServiceException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } on FaultServiceException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to submit fault report. Please try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Event')),
      bottomNavigationBar: const MainBottomNavigation(currentIndex: 2),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),

                const SizedBox(height: 18),

                _SectionCard(child: _buildMachineSelector()),

                const SizedBox(height: 12),

                _SectionCard(child: _buildFaultTypeSection()),

                const SizedBox(height: 12),

                _SectionCard(child: _buildSeveritySection()),

                const SizedBox(height: 12),

                _SectionCard(child: _buildDateTimeSection()),

                const SizedBox(height: 12),

                _SectionCard(child: _buildDescriptionSection()),

                const SizedBox(height: 12),

                _SectionCard(child: _buildPhotoSection()),

                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Fault Report',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.report_problem_outlined,
              color: AppTheme.green,
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Machine Fault',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Log the issue immediately so maintenance can respond quickly.',
                  style: TextStyle(
                    color: Color(0xFFC7D6E1),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineSelector() {
    final machines = _availableMachines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Machine'),

        const SizedBox(height: 9),

        if (machines.isEmpty)
          const Row(
            children: [
              Icon(Icons.precision_manufacturing_outlined),
              SizedBox(width: 10),
              Expanded(child: Text('No machines are available.')),
            ],
          )
        else
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedMachineId,
            decoration: const InputDecoration(
              hintText: 'Select machine',
              prefixIcon: Icon(Icons.precision_manufacturing_outlined),
            ),
            items: machines
                .map(
                  (machine) => DropdownMenuItem<String>(
                    value: machine.id,
                    child: Text(
                      '${machine.id} - ${machine.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    setState(() {
                      _selectedMachineId = value;
                    });
                  },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please select a machine.';
              }

              return null;
            },
          ),

        if (_selectedMachine != null) ...[
          const SizedBox(height: 10),
          _SelectedMachineCard(machine: _selectedMachine!),
        ],
      ],
    );
  }

  Widget _buildFaultTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Fault Type'),

        const SizedBox(height: 9),

        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedFaultType,
          decoration: const InputDecoration(
            hintText: 'Select fault category',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: AppConstants.faultTypes
              .map(
                (type) => DropdownMenuItem<String>(
                  value: type,
                  child: Text(
                    type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _isSubmitting
              ? null
              : (value) {
                  setState(() {
                    _selectedFaultType = value;
                  });
                },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please select a fault type.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSeveritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Severity'),

        const SizedBox(height: 3),

        const Text(
          'How serious is this machine issue?',
          style: TextStyle(color: Color(0xFF7C8C99), fontSize: 11),
        ),

        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.severities.map((severity) {
            final selected = _selectedSeverity == severity;

            final color = _severityColor(severity);

            return ChoiceChip(
              selected: selected,
              label: Text(severity),
              avatar: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              side: BorderSide(
                color: selected ? color : const Color(0xFFDCE5EC),
              ),
              selectedColor: color.withValues(alpha: 0.12),
              onSelected: _isSubmitting
                  ? null
                  : (isSelected) {
                      setState(() {
                        _selectedSeverity = isSelected ? severity : null;

                        _showSeverityError = false;
                      });
                    },
            );
          }).toList(),
        ),

        if (_showSeverityError) ...[
          const SizedBox(height: 8),
          Text(
            'Please select a severity.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateTimeSection() {
    final now = DateTime.now();

    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';

    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Date & Time'),

        const SizedBox(height: 9),

        Row(
          children: [
            Expanded(
              child: _InfoBox(icon: Icons.calendar_today_outlined, label: date),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _InfoBox(icon: Icons.access_time, label: time),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Fault Description'),

        const SizedBox(height: 3),

        const Text(
          'Describe what happened or what you observed.',
          style: TextStyle(color: Color(0xFF7C8C99), fontSize: 11),
        ),

        const SizedBox(height: 9),

        TextFormField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 6,
          enabled: !_isSubmitting,
          decoration: const InputDecoration(
            hintText: 'Example: Motor overheating with unusual vibration...',
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please describe the fault.';
            }

            if (value.trim().length < 10) {
              return 'Please provide at least 10 characters.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Add Photo'),

        const SizedBox(height: 3),

        const Text(
          'Optional • Attach a photo of the machine issue',
          style: TextStyle(color: Color(0xFF7C8C99), fontSize: 11),
        ),

        const SizedBox(height: 10),

        FaultImageAttachmentPicker(
          enabled: !_isSubmitting,
          pickImage: widget.pickImage,
          onImageChanged: (image) {
            setState(() {
              _selectedImage = image;
            });
          },
        ),

        if (_selectedImage != null) ...[
          const SizedBox(height: 8),

          const Row(
            children: [
              Icon(Icons.check_circle, size: 17, color: AppTheme.green),
              SizedBox(width: 6),
              Text(
                'Photo ready to upload',
                style: TextStyle(
                  color: AppTheme.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.navy,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case AppConstants.severityLow:
        return AppTheme.green;

      case AppConstants.severityMedium:
        return AppTheme.warning;

      case AppConstants.severityHigh:
        return Colors.deepOrange;

      case AppConstants.severityCritical:
        return AppTheme.danger;

      default:
        return Colors.grey;
    }
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(15), child: child),
    );
  }
}

class _SelectedMachineCard extends StatelessWidget {
  final MachineModel machine;

  const _SelectedMachineCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.precision_manufacturing,
            color: AppTheme.navy,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  machine.name,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  machine.id,
                  style: const TextStyle(
                    color: Color(0xFF7A8B98),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (machine.productionLine.isNotEmpty)
                  Text(
                    machine.productionLine,
                    style: const TextStyle(
                      color: Color(0xFF7A8B98),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            machine.status,
            style: const TextStyle(
              color: AppTheme.green,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBox({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FA),
        border: Border.all(color: const Color(0xFFDCE5EC)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.navy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.navy, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
