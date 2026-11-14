import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/icons/app_icons.dart';
import '../../ui/tokens/app_spacing.dart';

/// Internal inspection route: /design-system. Not a primary destination.
class ComponentGalleryPage extends StatelessWidget {
  const ComponentGalleryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppPage(
      pageContext: const PageContextData(pageType: 'component_gallery'),
      title: Text(l.appearance),
      body: ListView(
        padding: AppSpacing.page(context),
        children: [
          SettingsSection(
            title: l.appearance,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ShadButton(onPressed: () {}, child: Text(l.save)),
                  ShadButton.outline(onPressed: () {}, child: Text(l.cancel)),
                  ShadButton.ghost(onPressed: () {}, child: Text(l.manage)),
                  ShadButton.destructive(
                    onPressed: () {},
                    child: Text(l.delete),
                  ),
                  ShadButton(enabled: false, child: Text(l.loading)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l.optionalName),
              const SizedBox(height: AppSpacing.sm),
              ShadInput(placeholder: Text(l.optionalName)),
              const SizedBox(height: AppSpacing.lg),
              ShadInput(enabled: false, placeholder: Text(l.disabled)),
            ],
          ),
          SettingsSection(
            title: l.sources,
            children: [
              ShadSwitch(
                value: true,
                label: Text(l.sources),
                onChanged: (_) {},
              ),
              const SizedBox(height: AppSpacing.lg),
              ShadCheckbox(
                value: false,
                label: Text(l.favorite),
                onChanged: (_) {},
              ),
              const SizedBox(height: AppSpacing.lg),
              const ShadProgress(value: 0.6),
              const SizedBox(height: AppSpacing.lg),
              ShadAlert(
                icon: const Icon(AppIcons.info),
                title: Text(l.chooseScanScope),
                description: Text(l.scopeDescription),
              ),
              const SizedBox(height: AppSpacing.lg),
              ShadAlert.destructive(
                icon: const Icon(AppIcons.error),
                title: Text(l.connectionFailed),
                description: Text(l.connectionFormFailed),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
