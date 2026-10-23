import 'package:flutter/material.dart';

import '../../models/fault_model.dart';
import '../../models/machine_model.dart';
import '../../services/fault_service.dart';
import '../../utils/app_constants.dart';

class FaultReportingScreen extends StatefulWidget {
  final List<MachineModel> machines;
  final MachineModel? initialMachine;
  final FaultService? faultService;

  const FaultReportingScreen({
    super.key,
    this.machines = const [],
    this.initialMachine,
    this.faultService,
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

  bool _isSubmitting = false;
  bool _showSeverityError = false;

  @override
  void initState() {
    super.initState();

    final initialMachine = widget.initialMachine;

    if (initialMachine != null) {
      _selectedMachineId = initialMachine.id;
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

    final initialMachine = widget.initialMachine;

    if (initialMachine != null &&
        !machines.any((machine) => machine.id == initialMachine.id)) {
      machines.insert(0, initialMachine);
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

  void _showPhotoPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Photo attachment will be implemented during the image upload task.',
        ),
      ),
    );
  }

  FaultService get _effectiveFaultService =>
      widget.faultService ?? FaultService();

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
    final trimmedDescription = _descriptionController.text.trim();
    final hasDescription = trimmedDescription.length >= 10;

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
      final fault = FaultModel(
        id: '',
        machineId: _selectedMachineId!.trim(),
        machineName: _selectedMachine?.name,
        type: _selectedFaultType!.trim(),
        severity: _selectedSeverity!.trim(),
        description: trimmedDescription,
        reportedBy: '',
        status: AppConstants.faultStatusOpen,
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
      appBar: AppBar(
        title: const Text(
          'Report Fault',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),

                const SizedBox(height: 24),

                _buildMachineSelector(),

                const SizedBox(height: 20),

                _buildFaultTypeSection(),

                const SizedBox(height: 20),

                _buildSeveritySection(),

                const SizedBox(height: 20),

                _buildDateTimeSection(),

                const SizedBox(height: 20),

                _buildDescriptionSection(),

                const SizedBox(height: 20),

                _buildPhotoSection(),

                const SizedBox(height: 28),

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
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.report_problem_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Machine Fault',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Log an issue immediately so maintenance can respond quickly.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMachineSelector() {
    final machines = _availableMachines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Machine'),

        const SizedBox(height: 8),

        if (machines.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.precision_manufacturing_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('No machines are available.')),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedMachineId,
            decoration: const InputDecoration(
              hintText: 'Select machine',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.precision_manufacturing_outlined),
            ),
            items: machines
                .map(
                  (machine) => DropdownMenuItem<String>(
                    value: machine.id,
                    child: Text('${machine.id} - ${machine.name}'),
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

        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          initialValue: _selectedFaultType,
          decoration: const InputDecoration(
            hintText: 'Select fault category',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: AppConstants.faultTypes
              .map(
                (type) =>
                    DropdownMenuItem<String>(value: type, child: Text(type)),
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

        const SizedBox(height: 4),

        Text(
          'How serious is this machine issue?',
          style: Theme.of(context).textTheme.bodySmall,
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
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              side: BorderSide(
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              selectedColor: color.withValues(alpha: 0.15),
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

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _InfoBox(icon: Icons.calendar_today_outlined, label: date),
            ),
            const SizedBox(width: 12),
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

        const SizedBox(height: 4),

        Text(
          'Describe what happened or what you observed.',
          style: Theme.of(context).textTheme.bodySmall,
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 6,
          enabled: !_isSubmitting,
          decoration: const InputDecoration(
            hintText: 'Example: Motor overheating with unusual vibration...',
            border: OutlineInputBorder(),
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
        _sectionTitle('Add Photos'),

        const SizedBox(height: 4),

        Text('Optional', style: Theme.of(context).textTheme.bodySmall),

        const SizedBox(height: 8),

        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isSubmitting ? null : _showPhotoPlaceholder,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.add_a_photo_outlined, size: 32),
                SizedBox(height: 8),
                Text('Tap to add photos'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case AppConstants.severityLow:
        return Colors.green;

      case AppConstants.severityMedium:
        return Colors.orange;

      case AppConstants.severityHigh:
        return Colors.deepOrange;

      case AppConstants.severityCritical:
        return Colors.red;

      default:
        return Colors.grey;
    }
  }
}

class _SelectedMachineCard extends StatelessWidget {
  final MachineModel machine;

  const _SelectedMachineCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.precision_manufacturing),
        title: Text(machine.name),
        subtitle: Text(machine.productionLine),
        trailing: Text(
          machine.status,
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
