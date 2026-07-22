import 'package:flutter/material.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/service_settings_controllers.dart';
import 'app_surface.dart';

class SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: design.toolbarHeight,
                endIndent: design.spaceLg,
                color: scheme.outlineVariant.withValues(alpha: 0.22),
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

class SettingValueRow extends StatelessWidget {
  final Key? rowKey;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingValueRow({
    super.key,
    this.rowKey,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: rowKey,
      minTileHeight:
          context.appDesign.toolbarHeight + context.appDesign.spaceMd,
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ??
          (value == null
              ? (onTap == null ? null : const Icon(Icons.chevron_right))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.38,
                      ),
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: valueColor ?? scheme.onSurfaceVariant,
                          fontWeight: valueColor == null
                              ? null
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (onTap != null) ...[
                      SizedBox(width: context.appDesign.spaceXs),
                      const Icon(Icons.chevron_right),
                    ],
                  ],
                )),
      onTap: onTap,
    );
  }
}

class ReadinessBadge extends StatelessWidget {
  final ServiceReadiness readiness;

  const ReadinessBadge({super.key, required this.readiness});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color, icon) = switch (readiness) {
      ServiceReadiness.loading => (
        'Checking',
        scheme.onSurfaceVariant,
        Icons.sync,
      ),
      ServiceReadiness.setupRequired => (
        'Setup required',
        scheme.tertiary,
        Icons.settings_outlined,
      ),
      ServiceReadiness.ready => (
        'Ready',
        scheme.primary,
        Icons.check_circle_outline,
      ),
      ServiceReadiness.error => (
        'Needs attention',
        scheme.error,
        Icons.error_outline,
      ),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class ServiceStatusCard extends StatelessWidget {
  final Key? cardKey;
  final IconData icon;
  final String title;
  final String provider;
  final String selection;
  final ServiceReadiness readiness;
  final VoidCallback onTap;

  const ServiceStatusCard({
    super.key,
    this.cardKey,
    required this.icon,
    required this.title,
    required this.provider,
    required this.selection,
    required this.readiness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      key: cardKey,
      onTap: onTap,
      padding: EdgeInsets.all(design.spaceLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: 0.14),
            foregroundColor: scheme.primary,
            child: Icon(icon),
          ),
          SizedBox(width: design.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: design.spaceXs),
                Text(
                  provider,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  selection,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: design.spaceSm),
                ReadinessBadge(readiness: readiness),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class ProviderOptionTile extends StatelessWidget {
  final ProviderOptionViewData provider;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const ProviderOptionTile({
    super.key,
    required this.provider,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('provider-${provider.id}'),
    leading: Icon(
      provider.active ? Icons.radio_button_checked : Icons.radio_button_off,
    ),
    title: Text(provider.name),
    subtitle: Text(
      provider.subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: onEdit == null
        ? (provider.active ? const Icon(Icons.check) : null)
        : IconButton(
            tooltip: 'Edit provider',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
    onTap: onTap,
  );
}

class SettingsFeedbackBanner extends StatelessWidget {
  final String message;
  final bool error;

  const SettingsFeedbackBanner({
    super.key,
    required this.message,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      color: (error ? scheme.error : scheme.primary).withValues(alpha: 0.12),
      padding: EdgeInsets.all(context.appDesign.spaceMd),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.info_outline),
          SizedBox(width: context.appDesign.spaceSm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class SettingsEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const SettingsEmptyState({
    super.key,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(context.appDesign.spaceXxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.appDesign.toolbarHeight),
          SizedBox(height: context.appDesign.spaceMd),
          Text(message, textAlign: TextAlign.center),
          SizedBox(height: context.appDesign.spaceLg),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}

class SettingsErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const SettingsErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => SettingsEmptyState(
    icon: Icons.error_outline,
    message: '$error',
    actionLabel: 'Retry',
    onAction: onRetry,
  );
}
