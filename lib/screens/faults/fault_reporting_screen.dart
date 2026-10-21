import 'package:flutter/material.dart';

import '../../models/machine_model.dart';

class FaultReportingScreen extends StatefulWidget {
  final List<MachineModel> machines;
  final MachineModel? initialMachine;

  const FaultReportingScreen({
    super.key,
    this.machines = const [],
    this.initialMachine,
  });

  @override
  State<FaultReportingScreen> createState() =>
      _FaultReportingScreenState();
}

class _FaultReportingScreenState extends State<FaultReportingScreen> {
  final _notesController = TextEditingController();

  String? _selectedMachineId;
  bool _isSubmitting = false;

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
    _notesController.dispose();
    super.dispose();
  }

  MachineModel? get _selectedMachine {
    if (_selectedMachineId == null) {
      return null;
    }

    for (final machine in widget.machines) {
      if (machine.id == _selectedMachineId) {
        return machine;
      }
    }

    if (widget.initialMachine?.id == _selectedMachineId) {
      return widget.initialMachine;
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

  Future<void> _submitPlaceholder() async {
    if (_selectedMachineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a machine first.'),
        ),
      );

      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 250),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Fault submission will be connected during the next integration tasks.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report Fault',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),

              const SizedBox(height: 24),

              _buildMachineSelector(),

              const SizedBox(height: 20),

              _buildFaultTypePreview(),

              const SizedBox(height: 20),

              _buildDateTimeSection(),

              const SizedBox(height: 20),

              _buildNotesSection(),

              const SizedBox(height: 20),

              _buildPhotoSection(),

              const SizedBox(height: 28),

              FilledButton.icon(
                onPressed:
                    _isSubmitting ? null : _submitPlaceholder,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _isSubmitting
                      ? 'Submitting...'
                      : 'Submit Fault Report',
                ),
              ),
            ],
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
            color: Theme.of(
              context,
            ).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.report_problem_outlined,
            color: Theme.of(
              context,
            ).colorScheme.onErrorContainer,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Machine Fault',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 4),

              Text(
                'Log a machine issue immediately so it can be reviewed.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMachineSelector() {
    final availableMachines = [
      ...widget.machines,
    ];

    if (widget.initialMachine != null &&
        !availableMachines.any(
          (machine) =>
              machine.id == widget.initialMachine!.id,
        )) {
      availableMachines.insert(
        0,
        widget.initialMachine!,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Machine',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 8),

        if (availableMachines.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.precision_manufacturing_outlined,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No machines are available.',
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedMachineId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(
                Icons.precision_manufacturing_outlined,
              ),
            ),
            items: availableMachines
                .map(
                  (machine) =>
                      DropdownMenuItem<String>(
                    value: machine.id,
                    child: Text(
                      '${machine.id} - ${machine.name}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedMachineId = value;
              });
            },
          ),

        if (_selectedMachine != null) ...[
          const SizedBox(height: 10),
          _SelectedMachineCard(
            machine: _selectedMachine!,
          ),
        ],
      ],
    );
  }

  Widget _buildFaultTypePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Type',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.onErrorContainer,
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'Breakdown / Fault',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Icon(
                Icons.check_circle_outline,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Fault category and severity selection will be added in the Day 12 form task.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
        Text(
          'Date & Time',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _InfoBox(
                icon: Icons.calendar_today_outlined,
                label: date,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _InfoBox(
                icon: Icons.access_time,
                label: time,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: _notesController,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText:
                'Describe what happened or what you observed...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Photos',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 4),

        Text(
          'Optional',
          style: Theme.of(context).textTheme.bodySmall,
        ),

        const SizedBox(height: 8),

        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showPhotoPlaceholder,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 28,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 32,
                ),
                SizedBox(height: 8),
                Text(
                  'Tap to add photos',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedMachineCard extends StatelessWidget {
  final MachineModel machine;

  const _SelectedMachineCard({
    required this.machine,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.precision_manufacturing,
        ),
        title: Text(
          machine.name,
        ),
        subtitle: Text(
          machine.productionLine,
        ),
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

  const _InfoBox({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label),
          ),
        ],
      ),
    );
  }
}