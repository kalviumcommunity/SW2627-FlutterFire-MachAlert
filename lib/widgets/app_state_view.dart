import 'package:flutter/material.dart';

enum AppStateViewType { loading, empty, error, info }

class AppStateView extends StatelessWidget {
  final AppStateViewType type;
  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppStateView({
    super.key,
    required this.type,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  const AppStateView.loading({
    super.key,
    this.title = 'Loading...',
    this.message,
  }) : type = AppStateViewType.loading,
       icon = null,
       actionLabel = null,
       onAction = null;

  const AppStateView.empty({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  }) : type = AppStateViewType.empty;

  const AppStateView.error({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel = 'Retry',
    this.onAction,
  }) : type = AppStateViewType.error;

  const AppStateView.info({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  }) : type = AppStateViewType.info;

  @override
  Widget build(BuildContext context) {
    if (type == AppStateViewType.loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (message != null && message!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      );
    }

    final resolvedIcon = icon ?? _defaultIcon();
    final resolvedColor = _stateColor(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: resolvedColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(resolvedIcon, size: 38, color: resolvedColor),
            ),

            const SizedBox(height: 18),

            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(
                  type == AppStateViewType.error
                      ? Icons.refresh
                      : Icons.arrow_forward,
                ),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _defaultIcon() {
    switch (type) {
      case AppStateViewType.empty:
        return Icons.inbox_outlined;

      case AppStateViewType.error:
        return Icons.error_outline;

      case AppStateViewType.info:
        return Icons.info_outline;

      case AppStateViewType.loading:
        return Icons.hourglass_empty;
    }
  }

  Color _stateColor(BuildContext context) {
    switch (type) {
      case AppStateViewType.error:
        return Theme.of(context).colorScheme.error;

      case AppStateViewType.empty:
        return Theme.of(context).colorScheme.primary;

      case AppStateViewType.info:
        return Theme.of(context).colorScheme.secondary;

      case AppStateViewType.loading:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
