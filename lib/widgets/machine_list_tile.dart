import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../theme/app_theme.dart';

class MachineListTile extends StatelessWidget {
  final MachineModel machine;
  final VoidCallback? onTap;

  const MachineListTile({super.key, required this.machine, this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle(machine.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F7),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.precision_manufacturing,
                  color: AppTheme.navy,
                  size: 27,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.id,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      machine.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5F7282),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    if (machine.productionLine.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        machine.productionLine,
                        style: const TextStyle(
                          color: Color(0xFF94A1AD),
                          fontSize: 10,
                        ),
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
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: status.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status.label,
                        style: TextStyle(
                          color: status.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF95A3AF),
                    size: 19,
                  ),
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
      return const _MachineStatusStyle(label: 'Running', color: AppTheme.green);
    }

    if (normalized.contains('maintenance') || normalized == 'warning') {
      return const _MachineStatusStyle(
        label: 'Maintenance',
        color: AppTheme.warning,
      );
    }

    if (normalized == 'critical' || normalized == 'breakdown') {
      return const _MachineStatusStyle(
        label: 'Breakdown',
        color: AppTheme.danger,
      );
    }

    return const _MachineStatusStyle(
      label: 'Unknown',
      color: Color(0xFF8795A2),
    );
  }
}

class _MachineStatusStyle {
  final String label;
  final Color color;

  const _MachineStatusStyle({required this.label, required this.color});
}
