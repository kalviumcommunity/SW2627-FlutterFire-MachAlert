import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fault_model.dart';
import '../../services/fault_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/main_bottom_navigation.dart';

/// Screen displaying fault incidents reported specifically by the authenticated operator.
/// Strictly scoped to the authenticated Firebase UID (never client-supplied parameters).
class MyReportsScreen extends StatefulWidget {
  final FaultService? faultService;
  final StorageService? storageService;
  final UserService? userService;
  final FirebaseAuth? firebaseAuth;

  const MyReportsScreen({
    super.key,
    this.faultService,
    this.storageService,
    this.userService,
    this.firebaseAuth,
  });

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<FaultModel> _allMyFaults = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    AppConstants.faultStatusOpen,
    AppConstants.faultStatusInProgress,
    AppConstants.faultStatusResolved,
  ];

  FirebaseAuth get _effectiveAuth {
    if (widget.firebaseAuth != null) return widget.firebaseAuth!;
    try {
      return context.read<FirebaseAuth>();
    } catch (_) {}
    try {
      final faultService = context.read<FaultService>();
      return faultService.auth;
    } catch (_) {}
    return FirebaseAuth.instance;
  }

  FaultService get _effectiveFaultService {
    if (widget.faultService != null) return widget.faultService!;
    try {
      return context.read<FaultService>();
    } catch (_) {
      return FaultService();
    }
  }

  StorageService? get _effectiveStorageService {
    if (widget.storageService != null) return widget.storageService!;
    try {
      return context.read<StorageService>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchMyReports();
  }

  Future<void> _fetchMyReports({bool showLoading = true}) async {
    final user = _effectiveAuth.currentUser;
    if (user == null || user.uid.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User is not authenticated. Please log in.';
          _allMyFaults = [];
        });
      }
      return;
    }

    final currentUid = user.uid.trim();

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await _effectiveFaultService.getFaults(
        reportedBy: currentUid,
      );

      // Defensive client-side verification to guarantee no foreign operator records
      final verifiedMine = results.where((f) => f.reportedBy.trim() == currentUid).toList();

      if (!mounted) return;

      setState(() {
        _allMyFaults = verifiedMine;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      final message = e is FaultServiceException
          ? e.message
          : 'Unable to retrieve your reported faults. Please try again.';

      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
    }
  }

  List<FaultModel> get _filteredFaults {
    if (_selectedFilter == 'All') return _allMyFaults;
    final normalizedFilter = _selectedFilter.trim().toLowerCase();
    return _allMyFaults
        .where((f) => f.status.trim().toLowerCase() == normalizedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Reports'),
      ),
      bottomNavigationBar: const MainBottomNavigation(currentIndex: 2),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter.toLowerCase() == filter.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                key: ValueKey('filter-chip-$filter'),
                label: Text(filter),
                selected: isSelected,
                selectedColor: AppTheme.green.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.green,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.navy : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppTheme.green : const Color(0xFFE2E8F0),
                  ),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: AppStateView.loading(
          title: 'Loading Your Reports...',
          message: 'Retrieving faults reported by your account.',
        ),
      );
    }

    if (_errorMessage != null && _allMyFaults.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetchMyReports(showLoading: false),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: AppStateView.error(
                title: 'Unable to Load Reports',
                message: _errorMessage!,
                actionLabel: 'Retry',
                onAction: () => _fetchMyReports(showLoading: true),
              ),
            ),
          ),
        ),
      );
    }

    final displayList = _filteredFaults;

    if (displayList.isEmpty) {
      final isFiltered = _selectedFilter != 'All';
      return RefreshIndicator(
        onRefresh: () => _fetchMyReports(showLoading: false),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: AppStateView.empty(
                icon: Icons.assignment_outlined,
                title: isFiltered ? 'No ${_selectedFilter.toLowerCase()} reports' : 'No reports found',
                message: isFiltered
                    ? 'You have no faults currently marked as "$_selectedFilter".'
                    : 'You haven\'t submitted any machine fault reports yet.',
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchMyReports(showLoading: false),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          final fault = displayList[index];
          return _buildFaultCard(fault);
        },
      ),
    );
  }

  Widget _buildFaultCard(FaultModel fault) {
    final hasMachineName = fault.machineName != null && fault.machineName!.trim().isNotEmpty;
    final machineDisplayName = hasMachineName
        ? fault.machineName!.trim()
        : (fault.machineId.trim().isNotEmpty ? fault.machineId.trim() : 'Unknown Machine');

    final reporterDisplayName = fault.reportedByName?.trim().isNotEmpty == true
        ? fault.reportedByName!.trim()
        : 'You';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Machine Header + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        machineDisplayName,
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hasMachineName && fault.machineId.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Machine ID: ${fault.machineId.trim()}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(fault.status),
              ],
            ),

            const SizedBox(height: 10),

            // Chips: Type & Severity
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildTypeBadge(fault.type),
                _buildSeverityBadge(fault.severity),
              ],
            ),

            const SizedBox(height: 10),

            // Fault Description
            Text(
              fault.description.trim().isNotEmpty ? fault.description : 'No description provided',
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),

            // Footer: Timestamp, Reporter, and Attached Photo
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 13,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(fault.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'By $reporterDisplayName',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (fault.hasImage) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    key: ValueKey('view-photo-btn-${fault.id}'),
                    onTap: () => _showFaultImageDialog(context, fault),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 14,
                            color: AppTheme.blue,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Photo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFaultImageDialog(BuildContext context, FaultModel fault) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            fault.machineName?.trim().isNotEmpty == true
                ? fault.machineName!.trim()
                : (fault.machineId.trim().isNotEmpty ? fault.machineId.trim() : 'Fault Photo'),
          ),
          content: FutureBuilder<String?>(
            future: _effectiveFaultService.getFaultImageUrl(
              fault,
              storageService: _effectiveStorageService,
              callerRole: AppConstants.roleOperator,
              callerUid: _effectiveAuth.currentUser?.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final resolvedUrl = snapshot.data;
              if (resolvedUrl == null || resolvedUrl.trim().isEmpty) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: Text('No image available.')),
                );
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  resolvedUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          'Failed to load photo preview.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeBadge(String type) {
    final normalized = type.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        normalized.isNotEmpty ? normalized : 'Fault',
        style: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    final s = severity.trim().toLowerCase();
    final Color color;
    if (s == 'critical') {
      color = AppTheme.danger;
    } else if (s == 'high') {
      color = const Color(0xFFEA580C);
    } else if (s == 'medium') {
      color = AppTheme.warning;
    } else {
      color = AppTheme.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            severity.trim().isNotEmpty ? severity.trim() : 'Unknown',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.trim().toLowerCase();
    final Color bg;
    final Color text;
    final Color border;

    if (s == 'resolved' || s == 'completed') {
      bg = const Color(0xFFE8F6F3);
      text = const Color(0xFF2E7D6F);
      border = const Color(0xFFBBE5DD);
    } else if (s == 'in progress') {
      bg = const Color(0xFFFFF7ED);
      text = const Color(0xFFC2410C);
      border = const Color(0xFFFED7AA);
    } else {
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF1D4ED8);
      border = const Color(0xFFBFDBFE);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        status.trim().isNotEmpty ? status.trim() : AppConstants.faultStatusOpen,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Date unavailable';
    try {
      final local = dateTime.toLocal();
      final day = local.day.toString().padLeft(2, '0');
      final month = local.month.toString().padLeft(2, '0');
      final year = local.year;
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$day/$month/$year • $hour:$minute';
    } catch (_) {
      return 'Date unavailable';
    }
  }
}
