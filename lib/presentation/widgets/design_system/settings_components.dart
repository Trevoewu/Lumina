import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/service_settings_controllers.dart';
import 'app_surface.dart';

/// Corner radius shared by every settings card, matching the Lumina spec.
const double kSettingsCardRadius = 20;

/// A white (surface) rounded card with the soft drop shadow the settings spec
/// uses for every grouped block.
class SettingsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SettingsCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(kSettingsCardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

/// A settings card holding a vertical run of rows separated by hairlines that
/// span the full card width.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Uppercase, letter-spaced label used above a [SettingsGroup], matching the
/// Lumina settings visual language (distinct from the app-wide
/// [AppSectionHeader], which several other screens rely on).
class SettingsSectionLabel extends StatelessWidget {
  final String title;

  const SettingsSectionLabel({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // The spec insets section labels 6px past the page gutter and leaves
      // 26px above / 12px below before the card starts.
      padding: const EdgeInsets.fromLTRB(6, 26, 6, 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.3,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A three-way pill toggle, used for choices like theme (system/light/dark)
/// that read best as a single segmented control rather than a list.
class SegmentedChoiceRow<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelBuilder;
  final AppIconData Function(T) iconBuilder;

  const SegmentedChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelBuilder,
    required this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(
              child: _SegmentButton(
                selected: options[i] == selected,
                label: labelBuilder(options[i]),
                icon: iconBuilder(options[i]),
                onTap: () => onSelected(options[i]),
                scheme: scheme,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final bool selected;
  final String label;
  final AppIconData icon;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _SegmentButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? scheme.onSurface
          : scheme.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  icon,
                  size: 15,
                  color: selected ? scheme.surface : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: selected ? scheme.surface : scheme.onSurfaceVariant,
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

/// The pill toggle the settings spec uses for every inline multiple-choice
/// control: dark fill when selected, muted fill otherwise.
class SettingsChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool expand;

  const SettingsChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = Material(
      color: selected
          ? scheme.onSurface
          : scheme.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: expand ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: selected ? scheme.surface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
    return expand ? Expanded(child: chip) : chip;
  }
}

/// The inset-ring radio the spec uses on selectable cards and voice rows.
class SettingsRadio extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final double size;

  const SettingsRadio({
    super.key,
    required this.selected,
    this.enabled = true,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = !enabled
        ? scheme.onSurface.withValues(alpha: 0.09)
        : selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.18);
    // The filled state is drawn as a thick inner ring, matching the spec's
    // `inset 0 0 0 7px` treatment rather than a dot-in-circle.
    final thickness = selected && enabled ? size * 0.32 : 2.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: thickness),
      ),
    );
  }
}

/// Small rounded pill used to surface a status word (e.g. "Ready", "Local")
/// next to a [SettingValueRow], tinted when it represents a positive state.
class SettingBadge extends StatelessWidget {
  final String label;
  final bool tinted;

  const SettingBadge({super.key, required this.label, this.tinted = false});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: tinted
              ? scheme.primary.withValues(alpha: 0.18)
              : scheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontFamily: 'monospace',
            color: tinted ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class SetupProgressHeader extends StatelessWidget {
  final String title;
  final List<String> steps;
  final int currentStep;

  const SetupProgressHeader({
    super.key,
    required this.title,
    required this.steps,
    required this.currentStep,
  }) : assert(currentStep >= 0),
       assert(currentStep < steps.length);

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      padding: EdgeInsets.all(design.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: design.spaceMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index <= currentStep
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                        ),
                        alignment: Alignment.center,
                        child: index < currentStep
                            ? AppIcon(
                                AppIcons.tick02,
                                size: 17,
                                color: scheme.onPrimary,
                              )
                            : Text(
                                '${index + 1}',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: index == currentStep
                                          ? scheme.onPrimary
                                          : scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                      ),
                      SizedBox(height: design.spaceXs),
                      Text(
                        steps[index],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: index == currentStep
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 13),
                      child: Divider(
                        height: 2,
                        thickness: 2,
                        color: index < currentStep
                            ? scheme.primary
                            : scheme.outlineVariant,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class SetupActionCard extends StatelessWidget {
  final AppIconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;
  final Key? actionKey;

  const SetupActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
    this.actionKey,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      padding: EdgeInsets.all(design.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(design.radiusSmall),
              ),
              child: Padding(
                padding: EdgeInsets.all(design.spaceSm),
                child: AppIcon(icon, color: scheme.onPrimaryContainer),
              ),
            ),
          ),
          SizedBox(height: design.spaceMd),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: design.spaceSm),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: design.spaceLg),
          FilledButton.icon(
            key: actionKey,
            onPressed: onPressed,
            icon: const AppIcon(AppIcons.arrowRight02),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class SetupNavigationBar extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String previousLabel;
  final String nextLabel;
  final bool busy;

  const SetupNavigationBar({
    super.key,
    this.onPrevious,
    this.onNext,
    this.previousLabel = 'Previous',
    this.nextLabel = 'Next',
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('setup-previous'),
            onPressed: busy ? null : onPrevious,
            icon: const AppIcon(AppIcons.arrowLeft02),
            label: Text(previousLabel),
          ),
        ),
        SizedBox(width: design.spaceMd),
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('setup-next'),
            onPressed: busy ? null : onNext,
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const AppIcon(AppIcons.arrowRight02),
            label: Text(nextLabel),
          ),
        ),
      ],
    );
  }
}

class SetupStepTransition extends StatelessWidget {
  final int step;
  final bool forward;
  final Widget child;

  const SetupStepTransition({
    super.key,
    required this.step,
    required this.forward,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        final children = <Widget>[...previousChildren];
        if (currentChild != null) children.add(currentChild);
        return Stack(fit: StackFit.expand, children: children);
      },
      transitionBuilder: (transitionChild, animation) {
        final offset = forward ? const Offset(0.08, 0) : const Offset(-0.08, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: offset, end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: transitionChild,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(step), child: child),
    );
  }
}

class SettingValueRow extends StatelessWidget {
  final Key? rowKey;
  final AppIconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Color? valueColor;
  final String? badge;
  final bool badgeTinted;
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
    this.badge,
    this.badgeTinted = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: AppIcon(icon, size: 19, color: scheme.onSurface),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                SettingBadge(label: badge!, tinted: badgeTinted),
              ],
              if (value != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.32,
                  ),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: textTheme.bodyMedium?.copyWith(
                      color: valueColor ?? scheme.onSurfaceVariant,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 6),
                AppIcon(
                  AppIcons.arrowRight01,
                  size: 20,
                  color: scheme.onSurface.withValues(alpha: 0.28),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The destructive pill action the settings spec places at the bottom of the
/// page (red label on a muted fill rather than a filled red button).
class SettingsDangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const SettingsDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.error,
                  ),
                ),
        ),
      ),
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
        AppIcons.arrowDataTransferHorizontal,
      ),
      ServiceReadiness.setupRequired => (
        'Setup required',
        scheme.tertiary,
        AppIcons.settings02,
      ),
      ServiceReadiness.ready => (
        'Ready',
        scheme.primary,
        AppIcons.checkmarkCircle02,
      ),
      ServiceReadiness.error => (
        'Needs attention',
        scheme.error,
        AppIcons.alertCircle,
      ),
    };
    return Chip(
      avatar: AppIcon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class ServiceStatusCard extends StatelessWidget {
  final Key? cardKey;
  final AppIconData icon;
  final String title;
  final String provider;
  final String selection;
  final ServiceReadiness readiness;
  final VoidCallback? onTap;

  const ServiceStatusCard({
    super.key,
    this.cardKey,
    required this.icon,
    required this.title,
    required this.provider,
    required this.selection,
    required this.readiness,
    this.onTap,
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
            child: AppIcon(icon),
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
          if (onTap != null) const AppIcon(AppIcons.arrowRight01),
        ],
      ),
    );
  }
}

class ProviderOptionTile extends StatelessWidget {
  final ProviderOptionViewData provider;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final Widget? leading;

  const ProviderOptionTile({
    super.key,
    required this.provider,
    required this.onTap,
    this.onEdit,
    this.leading,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('provider-${provider.id}'),
    leading:
        leading ??
        AppIcon(provider.active ? AppIcons.radioButton : AppIcons.circle),
    title: Text(provider.name),
    subtitle: Text(
      provider.subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: onEdit == null
        ? (provider.active ? const AppIcon(AppIcons.tick02) : null)
        : IconButton(
            tooltip: 'Edit provider',
            onPressed: onEdit,
            icon: const AppIcon(AppIcons.pencilEdit02),
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
          AppIcon(error ? AppIcons.alertCircle : AppIcons.informationCircle),
          SizedBox(width: context.appDesign.spaceSm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class SettingsEmptyState extends StatelessWidget {
  final AppIconData icon;
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
          AppIcon(icon, size: context.appDesign.toolbarHeight),
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
    icon: AppIcons.alertCircle,
    message: '$error',
    actionLabel: 'Retry',
    onAction: onRetry,
  );
}
