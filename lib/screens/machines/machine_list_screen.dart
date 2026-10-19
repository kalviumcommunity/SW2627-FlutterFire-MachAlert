import 'package:flutter/material.dart';

import '../../models/machine_model.dart';
import '../../widgets/machine_list_tile.dart';
import '../../utils/app_routes.dart';

class MachineListScreen extends StatefulWidget {
  final List<MachineModel> machines;

  const MachineListScreen({super.key, this.machines = const []});

  @override
  State<MachineListScreen> createState() => _MachineListScreenState();
}

class _MachineListScreenState extends State<MachineListScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MachineModel> get _filteredMachines {
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

  void _openMachine(MachineModel machine) {
    Navigator.of(context).push<void>(AppRoutes.machineDetails(machine));
  }

  @override
  Widget build(BuildContext context) {
    final machines = _filteredMachines;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Machines',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
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
              child: machines.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: machines.length,
                      itemBuilder: (context, index) {
                        final machine = machines[index];

                        return MachineListTile(
                          machine: machine,
                          onTap: () => _openMachine(machine),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off
                  : Icons.precision_manufacturing_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),

            const SizedBox(height: 16),

            Text(
              isSearching ? 'No machines found' : 'No machines available',
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 8),

            Text(
              isSearching
                  ? 'Try another machine name, ID, or status.'
                  : 'Machines will appear here once they are added.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
