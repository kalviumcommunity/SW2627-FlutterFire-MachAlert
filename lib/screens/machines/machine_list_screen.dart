import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/machine_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/machine_provider.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_routes.dart';
import '../../widgets/machine_list_tile.dart';
import '../../widgets/app_state_view.dart';

class MachineListScreen extends StatefulWidget {
  final List<MachineModel> machines;
  final bool canManage;

  const MachineListScreen({
    super.key,
    this.machines = const [],
    this.canManage = false,
  });

  @override
  State<MachineListScreen> createState() => _MachineListScreenState();
}

class _MachineListScreenState extends State<MachineListScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final provider = context.read<MachineProvider>();
        if (!provider.hasActiveSubscription && provider.machines.isEmpty) {
          provider.subscribeToMachines();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _resolveCanManage(BuildContext context) {
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final role = appState.user?.role.trim().toLowerCase();
      return role == AppConstants.roleManager;
    } catch (_) {
      return false;
    }
  }

  List<MachineModel> _getFilteredStaticMachines() {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.machines;
    }

    return widget.machines.where((machine) {
      return machine.id.toLowerCase().contains(query) ||
          machine.name.toLowerCase().contains(query) ||
          machine.productionLine.toLowerCase().contains(query) ||
          machine.status.toLowerCase().contains(query);
    }).toList();
  }

  void _showFilterMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Advanced filtering will be added in a later task.'),
      ),
    );
  }

  void _openMachine(MachineModel machine, bool canManage) {
    try {
      context.read<MachineProvider>().selectMachine(machine);
    } catch (_) {}

    Navigator.of(context)
        .push<void>(AppRoutes.machineDetails(machine, canManage: canManage));
  }

  void _openAddMachine(bool canManage) {
    if (!canManage || !_resolveCanManage(context)) return;
    Navigator.of(context).push<void>(AppRoutes.addMachine());
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _resolveCanManage(context);

    MachineProvider? machineProvider;
    try {
      machineProvider = context.watch<MachineProvider>();
    } catch (_) {}

    final bool useStaticList =
        widget.machines.isNotEmpty || machineProvider == null;

    final List<MachineModel> machines = useStaticList
        ? _getFilteredStaticMachines()
        : machineProvider.filteredMachines;

    final bool isLoading =
        !useStaticList &&
        machineProvider.isLoading &&
        machineProvider.machines.isEmpty;

    final bool hasError =
        !useStaticList &&
        machineProvider.hasError &&
        machineProvider.machines.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Machines',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openAddMachine(canManage),
              icon: const Icon(Icons.add),
              label: const Text('Add Machine'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                        if (!useStaticList) {
                          machineProvider?.setSearchQuery(value);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Search machines...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  IconButton.filledTonal(
                    tooltip: 'Filter machines',
                    onPressed: _showFilterMessage,
                    icon: const Icon(Icons.filter_alt_outlined),
                  ),
                ],
              ),
            ),

            Expanded(
              child: isLoading
                  ? const AppStateView.loading(
                      title: 'Loading machines...',
                      message: 'Fetching the latest machine information.',
                    )
                  : hasError
                  ? _buildErrorState(
                      machineProvider.errorMessage,
                      machineProvider.fetchMachines,
                    )
                  : machines.isEmpty
                  ? _buildEmptyState(canManage)
                  : RefreshIndicator(
                      onRefresh: () async {
                        if (machineProvider != null) {
                          try {
                            await machineProvider.fetchMachines();
                          } catch (_) {}
                        }
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: machines.length,
                        itemBuilder: (context, index) {
                          final machine = machines[index];

                          return MachineListTile(
                            machine: machine,
                            onTap: () {
                              _openMachine(machine, canManage);
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    String? errorMessage,
    Future<void> Function() onRetry,
  ) {
    return AppStateView.error(
      title: 'Unable to load machines',
      message: errorMessage ?? 'Machine information could not be loaded. Check your connection and try again.',
      actionLabel: 'Retry',
      onAction: () {
        onRetry();
      },
    );
  }

  Widget _buildEmptyState(bool canManage) {
    final isSearching = _searchQuery.trim().isNotEmpty;

    return AppStateView.empty(
      icon: isSearching
          ? Icons.search_off
          : Icons.precision_manufacturing_outlined,
      title: isSearching ? 'No machines found' : 'No machines available',
      message: isSearching
          ? 'Try another machine name, ID, production line, or status.'
          : canManage
          ? 'There are no machines yet. Use Add Machine to create the first machine.'
          : 'Machines will appear here once they are added.',
    );
  }
}
