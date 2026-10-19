import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/machine_model.dart';
import '../services/machine_service.dart';

/// State management provider for industrial machine inventory.
///
/// Handles real-time stream subscription from Firestore via [MachineService],
/// client-side filtering (by production line, operational status, and search query),
/// selected machine inspection state, and status transitions.
class MachineProvider extends ChangeNotifier {
  final MachineService _machineService;
  StreamSubscription<List<MachineModel>>? _machinesSubscription;

  List<MachineModel> _machines = [];
  MachineModel? _selectedMachine;

  bool _isLoading = false;
  String? _errorMessage;

  String? _selectedLine;
  String? _selectedStatus;
  String _searchQuery = '';

  String? _subscribedLine;
  String? _subscribedStatus;

  bool _isDisposed = false;

  /// Creates a [MachineProvider].
  ///
  /// Optionally accepts [machineService] for dependency injection.
  /// If [machineStream] is provided, subscribes directly to it (useful for testing).
  /// If [autoSubscribe] is true, immediately subscribes to the service stream.
  MachineProvider({
    MachineService? machineService,
    Stream<List<MachineModel>>? machineStream,
    bool autoSubscribe = false,
  }) : _machineService = machineService ?? MachineService() {
    if (machineStream != null) {
      subscribeToMachineStream(machineStream);
    } else if (autoSubscribe) {
      subscribeToMachines();
    }
  }

  /// Underlying machine service.
  MachineService get machineService => _machineService;

  /// Complete list of machines in the factory inventory.
  List<MachineModel> get machines => List.unmodifiable(_machines);

  /// Filtered machine list applying active production line, status, and search query filters.
  List<MachineModel> get filteredMachines {
    var result = _machines;

    if (_selectedLine != null && _selectedLine!.trim().isNotEmpty) {
      final line = _selectedLine!.trim().toLowerCase();
      result = result
          .where((m) => m.productionLine.trim().toLowerCase() == line)
          .toList();
    }

    if (_selectedStatus != null && _selectedStatus!.trim().isNotEmpty) {
      final status = _selectedStatus!.trim().toLowerCase();
      result = result
          .where((m) => m.status.trim().toLowerCase() == status)
          .toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((m) {
        return m.id.toLowerCase().contains(query) ||
            m.name.toLowerCase().contains(query) ||
            m.productionLine.toLowerCase().contains(query) ||
            m.status.toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  /// The currently selected machine for details view.
  MachineModel? get selectedMachine => _selectedMachine;

  /// Whether a data fetching operation or initial stream load is in progress.
  bool get isLoading => _isLoading;

  /// Last error message encountered during fetching or stream updates.
  String? get errorMessage => _errorMessage;

  /// Whether an error state is currently present.
  bool get hasError => _errorMessage != null;

  /// Whether the machine inventory is empty and not loading.
  bool get isEmpty => !_isLoading && _errorMessage == null && _machines.isEmpty;

  /// Active production line filter.
  String? get selectedLine => _selectedLine;

  /// Active operational status filter.
  String? get selectedStatus => _selectedStatus;

  /// Active text search query.
  String get searchQuery => _searchQuery;

  /// Whether an active Firestore real-time stream subscription is open.
  bool get hasActiveSubscription => _machinesSubscription != null;

  /// Whether this provider has been disposed.
  bool get isDisposed => _isDisposed;

  /// Subscribes to the real-time machine stream from [MachineService].
  ///
  /// Cancels any existing subscription before creating a new one.
  /// Prevents redundant subscriptions if filters have not changed.
  void subscribeToMachines({String? productionLine, String? status}) {
    if (_isDisposed) return;

    if (_machinesSubscription != null &&
        _subscribedLine == productionLine &&
        _subscribedStatus == status) {
      return;
    }

    _machinesSubscription?.cancel();
    _subscribedLine = productionLine;
    _subscribedStatus = status;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _machinesSubscription = _machineService
        .streamMachines(productionLine: productionLine, status: status)
        .listen(
          (machinesList) {
            if (_isDisposed) return;
            _machines = List.from(machinesList);
            _isLoading = false;
            _errorMessage = null;

            if (_selectedMachine != null) {
              final match = _machines.cast<MachineModel?>().firstWhere(
                (m) => m?.id == _selectedMachine!.id,
                orElse: () => null,
              );
              if (match != null) {
                _selectedMachine = match;
              }
            }

            notifyListeners();
          },
          onError: (Object error) {
            if (_isDisposed) return;
            _isLoading = false;
            _errorMessage = error is MachineServiceException
                ? error.message
                : error.toString();
            notifyListeners();
          },
        );
  }

  /// Subscribes directly to a supplied stream of machine lists.
  void subscribeToMachineStream(Stream<List<MachineModel>> stream) {
    if (_isDisposed) return;

    _machinesSubscription?.cancel();
    _subscribedLine = null;
    _subscribedStatus = null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _machinesSubscription = stream.listen(
      (machinesList) {
        if (_isDisposed) return;
        _machines = List.from(machinesList);
        _isLoading = false;
        _errorMessage = null;

        if (_selectedMachine != null) {
          final match = _machines.cast<MachineModel?>().firstWhere(
            (m) => m?.id == _selectedMachine!.id,
            orElse: () => null,
          );
          if (match != null) {
            _selectedMachine = match;
          }
        }

        notifyListeners();
      },
      onError: (Object error) {
        if (_isDisposed) return;
        _isLoading = false;
        _errorMessage = error is MachineServiceException
            ? error.message
            : error.toString();
        notifyListeners();
      },
    );
  }

  /// Manually fetches machines from Firestore using a one-shot query.
  Future<void> fetchMachines({String? productionLine, String? status}) async {
    if (_isDisposed) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _machineService.getMachines(
        productionLine: productionLine,
        status: status,
      );
      if (_isDisposed) return;

      _machines = List.from(list);
      _isLoading = false;
      _errorMessage = null;

      if (_selectedMachine != null) {
        final match = _machines.cast<MachineModel?>().firstWhere(
          (m) => m?.id == _selectedMachine!.id,
          orElse: () => null,
        );
        if (match != null) {
          _selectedMachine = match;
        }
      }

      notifyListeners();
    } catch (error) {
      if (_isDisposed) return;
      _isLoading = false;
      _errorMessage = error is MachineServiceException
          ? error.message
          : error.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Selects a machine for detailed inspection.
  void selectMachine(MachineModel? machine) {
    if (_selectedMachine == machine) return;
    _selectedMachine = machine;
    notifyListeners();
  }

  /// Selects a machine by its document identifier.
  void selectMachineById(String machineId) {
    final match = _machines.cast<MachineModel?>().firstWhere(
      (m) => m?.id == machineId,
      orElse: () => null,
    );
    if (match != null) {
      selectMachine(match);
    }
  }

  /// Clears the currently selected machine.
  void clearSelectedMachine() {
    if (_selectedMachine == null) return;
    _selectedMachine = null;
    notifyListeners();
  }

  /// Sets the active production line filter.
  void setProductionLineFilter(String? line) {
    if (_selectedLine == line) return;
    _selectedLine = line;
    notifyListeners();
  }

  /// Sets the active operational status filter.
  void setStatusFilter(String? status) {
    if (_selectedStatus == status) return;
    _selectedStatus = status;
    notifyListeners();
  }

  /// Sets the search query filter.
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// Clears all production line, status, and search query filters.
  void clearFilters() {
    if (_selectedLine == null &&
        _selectedStatus == null &&
        _searchQuery.isEmpty) {
      return;
    }
    _selectedLine = null;
    _selectedStatus = null;
    _searchQuery = '';
    notifyListeners();
  }

  /// Updates a machine's operational status and updates provider state.
  ///
  /// Reconciles both the machine list and the selected machine if matched.
  Future<void> updateMachineStatus(String machineId, String newStatus) async {
    _errorMessage = null;

    try {
      await _machineService.updateMachineStatus(machineId, newStatus);
      if (_isDisposed) return;

      final index = _machines.indexWhere((m) => m.id == machineId);
      if (index != -1) {
        _machines[index] = _machines[index].copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
      }

      if (_selectedMachine?.id == machineId) {
        _selectedMachine = _selectedMachine!.copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
      }

      notifyListeners();
    } catch (error) {
      if (!_isDisposed) {
        _errorMessage = error is MachineServiceException
            ? error.message
            : error.toString();
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Adds a new machine to the inventory through [MachineService] and reconciles provider state.
  Future<void> addMachine(MachineModel machine) async {
    _errorMessage = null;

    try {
      await _machineService.addMachine(machine);
      if (_isDisposed) return;

      final index = _machines.indexWhere((m) => m.id == machine.id);
      if (index != -1) {
        _machines[index] = machine;
      } else {
        _machines.add(machine);
      }
      notifyListeners();
    } catch (error) {
      if (!_isDisposed) {
        _errorMessage = error is MachineServiceException
            ? error.message
            : error.toString();
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Updates an existing machine's mutable fields using [MachineService.updateMachineModel]
  /// and reconciles provider state.
  Future<void> updateMachine(MachineModel machine) async {
    _errorMessage = null;

    try {
      await _machineService.updateMachineModel(machine);
      if (_isDisposed) return;

      final index = _machines.indexWhere((m) => m.id == machine.id);
      if (index != -1) {
        _machines[index] = machine;
      }

      if (_selectedMachine?.id == machine.id) {
        _selectedMachine = machine;
      }

      notifyListeners();
    } catch (error) {
      if (!_isDisposed) {
        _errorMessage = error is MachineServiceException
            ? error.message
            : error.toString();
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Deletes a machine document via [MachineService] and reconciles provider state.
  Future<void> deleteMachine(String machineId) async {
    _errorMessage = null;

    try {
      await _machineService.deleteMachine(machineId);
      if (_isDisposed) return;

      _machines.removeWhere((m) => m.id == machineId);

      if (_selectedMachine?.id == machineId) {
        _selectedMachine = null;
      }

      notifyListeners();
    } catch (error) {
      if (!_isDisposed) {
        _errorMessage = error is MachineServiceException
            ? error.message
            : error.toString();
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Finds a machine in memory by its identifier.
  MachineModel? getMachineById(String machineId) {
    for (final m in _machines) {
      if (m.id == machineId) {
        return m;
      }
    }
    return null;
  }

  /// Clears the current error message.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets the machines list directly in memory (useful for testing or seeding).
  void setMachines(List<MachineModel> machines) {
    _machines = List.from(machines);
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _machinesSubscription?.cancel();
    _machinesSubscription = null;
    super.dispose();
  }
}
