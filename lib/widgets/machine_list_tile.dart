import 'package:flutter/material.dart';

import '../models/machine_model.dart';

class MachineListTile extends StatelessWidget {
  final MachineModel machine;
  final VoidCallback? onTap;

  const MachineListTile({super.key, required this.machine, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(machine.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.precision_manufacturing,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.id,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      machine.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    if (machine.productionLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        machine.productionLine,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusStyle.color,
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 6),

                      Text(
                        statusStyle.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _MachineStatusStyle _statusStyle(String status) {
    final normalized = status.trim().toLowerCase();

    if (normalized == 'operational' || normalized == 'running') {
      return const _MachineStatusStyle(label: 'Running', color: Colors.green);
    }

    if (normalized.contains('maintenance') || normalized == 'warning') {
      return const _MachineStatusStyle(
        label: 'Under Maintenance',
        color: Colors.orange,
      );
    }

    if (normalized == 'critical' || normalized == 'breakdown') {
      return const _MachineStatusStyle(label: 'Breakdown', color: Colors.red);
    }

    return const _MachineStatusStyle(label: 'Unknown', color: Colors.grey);
  }
}

class _MachineStatusStyle {
  final String label;
  final Color color;

  const _MachineStatusStyle({required this.label, required this.color});
}
