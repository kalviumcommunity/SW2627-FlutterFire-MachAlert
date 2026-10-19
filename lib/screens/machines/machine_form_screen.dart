import 'package:flutter/material.dart';

import '../../models/machine_model.dart';
import '../../utils/app_constants.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

typedef MachineSaveCallback = Future<void> Function(MachineModel machine);

class MachineFormScreen extends StatefulWidget {
  final MachineModel? machine;
  final MachineSaveCallback? onSave;

  const MachineFormScreen({super.key, this.machine, this.onSave});

  bool get isEditing => machine != null;

  @override
  State<MachineFormScreen> createState() => _MachineFormScreenState();
}

class _MachineFormScreenState extends State<MachineFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _lineController;
  late final TextEditingController _modelController;
  late final TextEditingController _healthController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _vibrationController;

  late String _status;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final machine = widget.machine;

    _idController = TextEditingController(text: machine?.id ?? '');

    _nameController = TextEditingController(text: machine?.name ?? '');

    _lineController = TextEditingController(
      text: machine?.productionLine ?? '',
    );

    _modelController = TextEditingController(text: machine?.modelNumber ?? '');

    _healthController = TextEditingController(
      text: machine == null ? '100' : machine.healthScore.toString(),
    );

    _temperatureController = TextEditingController(
      text: machine?.temperature?.toString() ?? '',
    );

    _vibrationController = TextEditingController(
      text: machine?.vibration?.toString() ?? '',
    );

    _status = machine?.status.isNotEmpty == true
        ? machine!.status
        : AppConstants.machineStatusOperational;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _lineController.dispose();
    _modelController.dispose();
    _healthController.dispose();
    _temperatureController.dispose();
    _vibrationController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    if (widget.onSave == null) {
      setState(() {
        _errorMessage =
            'Machine saving will be connected during CRUD integration.';
      });

      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final existing = widget.machine;

    final machine = MachineModel(
      id: _idController.text.trim(),
      name: _nameController.text.trim(),
      productionLine: _lineController.text.trim(),
      modelNumber: _modelController.text.trim().isEmpty
          ? null
          : _modelController.text.trim(),
      status: _status,
      healthScore: double.tryParse(_healthController.text.trim()) ?? 100,
      temperature: _optionalDouble(_temperatureController.text),
      vibration: _optionalDouble(_vibrationController.text),
      lastInspection: existing?.lastInspection,
      createdAt: existing?.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      await widget.onSave!(machine);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(machine);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  double? _optionalDouble(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return double.tryParse(trimmed);
  }

  String? _requiredValidator(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }

    return null;
  }

  String? _numberValidator(String? value, {bool required = false}) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return required ? 'This field is required' : null;
    }

    if (double.tryParse(text) == null) {
      return 'Enter a valid number';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Edit Machine' : 'Add Machine';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.precision_manufacturing,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),

                const SizedBox(height: 16),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.isEditing
                      ? 'Update machine information'
                      : 'Register a new production machine',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                AppTextField(
                  label: 'Machine ID',
                  controller: _idController,
                  validator: (value) => _requiredValidator(value, 'Machine ID'),
                ),

                if (widget.isEditing) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Machine ID should not be changed after creation.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],

                const SizedBox(height: 16),

                AppTextField(
                  label: 'Machine Name',
                  controller: _nameController,
                  validator: (value) =>
                      _requiredValidator(value, 'Machine name'),
                ),

                const SizedBox(height: 16),

                AppTextField(
                  label: 'Production Line',
                  controller: _lineController,
                  validator: (value) =>
                      _requiredValidator(value, 'Production line'),
                ),

                const SizedBox(height: 16),

                AppTextField(
                  label: 'Model Number',
                  controller: _modelController,
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: AppConstants.machineStatuses
                      .map(
                        (status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _status = value;
                            });
                          }
                        },
                ),

                const SizedBox(height: 16),

                AppTextField(
                  label: 'Health Score',
                  controller: _healthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => _numberValidator(value, required: true),
                ),

                const SizedBox(height: 16),

                AppTextField(
                  label: 'Temperature (°C)',
                  controller: _temperatureController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _numberValidator,
                ),

                const SizedBox(height: 16),

                AppTextField(
                  label: 'Vibration',
                  controller: _vibrationController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _numberValidator,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                AppButton(
                  text: widget.isEditing ? 'Save Changes' : 'Add Machine',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
