import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/machine_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/machine_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_routes.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/machine_list_tile.dart';
import '../../widgets/main_bottom_navigation.dart';

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
      if (!mounted) {
        return;
      }

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
      final role = Provider.of<AppStateProvider>(
        context,
        listen: false,
      ).user?.role.trim().toLowerCase();

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
        content: Text('Search by machine ID, name, line, or status.'),
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
    if (!canManage || !_resolveCanManage(context)) {
      return;
    }

    Navigator.of(context).push<void>(AppRoutes.addMachine());
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _resolveCanManage(context);

    MachineProvider? provider;

    try {
      provider = context.watch<MachineProvider>();
    } catch (_) {}

    final useStaticList = widget.machines.isNotEmpty || provider == null;

    final machines = useStaticList
        ? _getFilteredStaticMachines()
        : provider.filteredMachines;

    final isLoading =
        !useStaticList && provider.isLoading && provider.machines.isEmpty;

    final hasError =
        !useStaticList && provider.hasError && provider.machines.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Machines')),
      bottomNavigationBar: const MainBottomNavigation(currentIndex: 1),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.green,
              foregroundColor: Colors.white,
              onPressed: () {
                _openAddMachine(canManage);
              },
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
                          provider?.setSearchQuery(value);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Search machines...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();

                                  setState(() {
                                    _searchQuery = '';
                                  });

                                  if (!useStaticList) {
                                    provider?.setSearchQuery('');
                                  }
                                },
                                icon: const Icon(Icons.close),
                              )
                            : null,
                      ),
                    ),
                  ),

                  const SizedBox(width: 9),

                  SizedBox(
                    width: 48,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: AppTheme.navy,
                      ),
                      onPressed: _showFilterMessage,
                      child: const Icon(Icons.filter_alt_outlined),
                    ),
                  ),
                ],
              ),
            ),

            if (!isLoading && !hasError && machines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 0, 17, 9),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${machines.length} ${machines.length == 1 ? 'machine' : 'machines'}',
                    style: const TextStyle(
                      color: Color(0xFF8494A2),
                      fontSize: 11,
                    ),
                  ),
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
                      provider.errorMessage,
                      provider.fetchMachines,
                    )
                  : machines.isEmpty
                  ? _buildEmptyState(canManage)
                  : RefreshIndicator(
                      onRefresh: () async {
                        if (provider != null) {
                          try {
                            await provider.fetchMachines();
                          } catch (_) {}
                        }
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
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

  Widget _buildErrorState(String? message, Future<void> Function() onRetry) {
    return AppStateView.error(
      title: 'Unable to load machines',
      message: message ?? 'Machine information could not be loaded. Check your connection and try again.',
      actionLabel: 'Retry',
      onAction: () {
        onRetry();
      },
    );
  }

  Widget _buildEmptyState(bool canManage) {
    final searching = _searchQuery.trim().isNotEmpty;

    return AppStateView.empty(
      icon: searching
          ? Icons.search_off
          : Icons.precision_manufacturing_outlined,
      title: searching ? 'No machines found' : 'No machines available',
      message: searching
          ? 'Try another machine name, ID, production line, or status.'
          : canManage
          ? 'There are no machines yet. Use Add Machine to create the first machine.'
          : 'Machines will appear here once they are added.',
    );
  }
}
