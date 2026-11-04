import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fault_model.dart';
import '../../models/machine_model.dart';
import '../../models/maintenance_model.dart';
import '../../models/user_model.dart';
import '../../providers/machine_provider.dart';
import '../../services/fault_service.dart';
import '../../services/machine_service.dart';
import '../../services/maintenance_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_constants.dart';

/// Form screen for managers to assign and create new maintenance tasks.
class MaintenanceTaskFormScreen extends StatefulWidget {
  final MaintenanceService? maintenanceService;
  final UserService? userService;
  final MachineService? machineService;
  final FaultService? faultService;
  final List<MachineModel>? initialMachines;
  final List<UserModel>? initialTechnicians;
  final List<FaultModel>? initialFaults;

  const MaintenanceTaskFormScreen({
    super.key,
    this.maintenanceService,
    this.userService,
    this.machineService,
    this.faultService,
    this.initialMachines,
    this.initialTechnicians,
    this.initialFaults,
  });

  @override
  State<MaintenanceTaskFormScreen> createState() =>
      _MaintenanceTaskFormScreenState();
}

class _MaintenanceTaskFormScreenState extends State<MaintenanceTaskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _notesController = TextEditingController();

  List<MachineModel> _machines = [];
  List<UserModel> _technicians = [];
  List<FaultModel> _machineFaults = [];

  MachineModel? _selectedMachine;
  UserModel? _selectedTechnician;
  FaultModel? _selectedFault;
  String _selectedPriority = AppConstants.severityMedium;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLoadingFaults = false;
  String? _loadError;
  String? _faultLoadError;

  @override
  void initState() {
    super.initState();
    _loadPrerequisites();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  MaintenanceService _resolveMaintenanceService() {
    if (widget.maintenanceService != null) {
      return widget.maintenanceService!;
    }
    return context.read<MaintenanceService>();
  }

  UserService? _resolveUserService() {
    if (widget.userService != null) {
      return widget.userService!;
    }
    try {
      return context.read<UserService>();
    } catch (_) {
      return null;
    }
  }

  MachineService? _resolveMachineService() {
    if (widget.machineService != null) {
      return widget.machineService!;
    }
    try {
      return context.read<MachineService>();
    } catch (_) {
      return null;
    }
  }

  FaultService? _resolveFaultService() {
    if (widget.faultService != null) {
      return widget.faultService!;
    }
    try {
      return context.read<FaultService>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPrerequisites() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // 1. Resolve Machines
      if (widget.initialMachines != null) {
        _machines = List<MachineModel>.from(widget.initialMachines!);
      } else {
        MachineProvider? machineProvider;
        try {
          machineProvider = context.read<MachineProvider>();
        } catch (_) {}

        if (machineProvider != null && machineProvider.machines.isNotEmpty) {
          _machines = List<MachineModel>.from(machineProvider.machines);
        } else {
          final machineService = _resolveMachineService();
          if (machineService != null) {
            _machines = await machineService.getMachines();
          }
        }
      }

      // 2. Resolve Technicians
      if (widget.initialTechnicians != null) {
        _technicians = List<UserModel>.from(widget.initialTechnicians!);
      } else {
        final userService = _resolveUserService();
        if (userService != null) {
          _technicians = await userService.getUsersByRole(
            AppConstants.roleTechnician,
          );
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Failed to load machines or technicians.';
        });
      }
    }
  }

  Future<void> _fetchFaultsForMachine(String machineId) async {
    setState(() {
      _isLoadingFaults = true;
      _faultLoadError = null;
      _machineFaults = [];
      _selectedFault = null;
    });

    try {
      List<FaultModel> faults;
      if (widget.initialFaults != null) {
        faults = widget.initialFaults!
            .where((f) => f.machineId == machineId)
            .toList();
      } else {
        final faultService = _resolveFaultService();
        if (faultService != null) {
          faults = await faultService.getFaults(machineId: machineId);
        } else {
          faults = [];
        }
      }

      final eligibleFaults = faults.where((f) {
        final s = f.status.trim().toLowerCase();
        return s == AppConstants.faultStatusOpen.toLowerCase() ||
            s == AppConstants.faultStatusInProgress.toLowerCase() ||
            s == 'open' ||
            s == 'in progress';
      }).toList();

      if (mounted) {
        setState(() {
          _machineFaults = eligibleFaults;
          _isLoadingFaults = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFaults = false;
          _faultLoadError = 'Failed to load faults for selected machine.';
        });
      }
    }
  }

  Future<void> _submitTask() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMachine == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a machine')));
      return;
    }

    if (_selectedTechnician == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a technician')),
      );
      return;
    }

    // Validate linked fault belongs to the selected machine
    if (_selectedFault != null &&
        _selectedFault!.machineId.trim() != _selectedMachine!.id.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The selected fault does not belong to the selected machine.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final maintenanceService = _resolveMaintenanceService();

      final faultId =
          _selectedFault != null && _selectedFault!.id.trim().isNotEmpty
              ? _selectedFault!.id.trim()
              : null;
      final notes = _notesController.text.trim();

      final task = MaintenanceModel(
        id: '',
        machineId: _selectedMachine!.id,
        machineName: _selectedMachine!.name,
        faultId: faultId,
        technicianId: _selectedTechnician!.id,
        technicianName: _selectedTechnician!.name,
        priority: _selectedPriority,
        status: AppConstants.maintenanceStatusPending,
        notes: notes.isNotEmpty ? notes : null,
      );

      await maintenanceService.createMaintenanceTask(task);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maintenance task created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } on MaintenanceServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to create maintenance task. Please try again.',
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
      appBar: AppBar(title: const Text('Create Maintenance Task')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadPrerequisites,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Machine Dropdown
                      DropdownButtonFormField<MachineModel>(
                        key: const ValueKey('maintenance-machine-dropdown'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Machine *',
                          prefixIcon: Icon(
                            Icons.precision_manufacturing_outlined,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _selectedMachine,
                        items: _machines.map((machine) {
                          final label = machine.name.trim().isNotEmpty
                              ? '${machine.name} (${machine.id})'
                              : machine.id;
                          return DropdownMenuItem<MachineModel>(
                            value: machine,
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedMachine = value;
                                  _selectedFault = null;
                                  _machineFaults = [];
                                  _faultLoadError = null;
                                });
                                if (value != null) {
                                  _fetchFaultsForMachine(value.id);
                                }
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a machine';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // 2. Technician Dropdown (Readable names, never expose raw UIDs)
                      DropdownButtonFormField<UserModel>(
                        key: const ValueKey('maintenance-technician-dropdown'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Technician *',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _selectedTechnician,
                        items: _technicians.map((tech) {
                          final label = tech.name.trim().isNotEmpty
                              ? tech.name.trim()
                              : (tech.email.trim().isNotEmpty
                                  ? tech.email.trim()
                                  : 'Technician');
                          return DropdownMenuItem<UserModel>(
                            value: tech,
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedTechnician = value;
                                });
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a technician';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // 3. Priority Dropdown
                      DropdownButtonFormField<String>(
                        key: const ValueKey('maintenance-priority-dropdown'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Priority *',
                          prefixIcon: Icon(Icons.flag_outlined),
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _selectedPriority,
                        items:
                            [
                              AppConstants.severityCritical,
                              AppConstants.severityHigh,
                              AppConstants.severityMedium,
                              AppConstants.severityLow,
                            ].map((priority) {
                              return DropdownMenuItem<String>(
                                value: priority,
                                child: Text(priority),
                              );
                            }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedPriority = value;
                                  });
                                }
                              },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select a priority';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // 4. Optional Fault Selector Dropdown
                      DropdownButtonFormField<FaultModel?>(
                        key: const ValueKey('maintenance-fault-id-field'),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Linked Fault (Optional)',
                          hintText: _selectedMachine == null
                              ? 'Select a machine first'
                              : (_isLoadingFaults
                                  ? 'Loading active faults...'
                                  : (_machineFaults.isEmpty
                                      ? 'No active faults (Preventive only)'
                                      : 'Select active fault or None')),
                          prefixIcon: const Icon(Icons.link_outlined),
                          suffixIcon: _isLoadingFaults
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        initialValue: _selectedFault,
                        items: [
                          const DropdownMenuItem<FaultModel?>(
                            value: null,
                            child: Text(
                              'None (Preventive Maintenance)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedMachine != null)
                            ..._machineFaults.map((fault) {
                              final mName =
                                  fault.machineName?.trim().isNotEmpty == true
                                      ? fault.machineName!.trim()
                                      : (_selectedMachine?.name ?? '');
                              final display =
                                  '$mName - ${fault.faultType} (${fault.severity}, ${fault.status}): ${fault.description}';
                              return DropdownMenuItem<FaultModel?>(
                                value: fault,
                                child: Text(
                                  display,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                        ],
                        onChanged: (_isSubmitting || _selectedMachine == null)
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedFault = value;
                                });
                              },
                      ),

                      if (_faultLoadError != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _faultLoadError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (_selectedMachine != null)
                              TextButton(
                                onPressed: () => _fetchFaultsForMachine(
                                  _selectedMachine!.id,
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 5. Assignment Notes Field
                      TextFormField(
                        key: const ValueKey('maintenance-notes-field'),
                        controller: _notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Task Summary / Notes (Optional)',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 64),
                            child: Icon(Icons.notes_outlined),
                          ),
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_isSubmitting,
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      FilledButton.icon(
                        key: const ValueKey('maintenance-submit-task-button'),
                        onPressed: _isSubmitting ? null : _submitTask,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isSubmitting
                              ? 'Creating Task...'
                              : 'Assign Maintenance Task',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
