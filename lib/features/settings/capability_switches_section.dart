import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../capabilities/capability_providers.dart';
import '../../capabilities/sources/source_manager.dart';
import '../../core/capabilities/source_capability.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/feedback/app_feedback.dart';
import '../../ui/components/settings/settings_section.dart';

/// Settings → 基础能力: the App-wide switches of the capability providers
/// (source kinds, FFmpeg, speech recognition). The AI follows them.
class CapabilitySwitchesSection extends StatefulWidget {
  const CapabilitySwitchesSection({super.key, required this.sources});
  final SourceManager sources;

  @override
  State<CapabilitySwitchesSection> createState() =>
      _CapabilitySwitchesSectionState();
}

class _CapabilitySwitchesSectionState extends State<CapabilitySwitchesSection> {
  @override
  void initState() {
    super.initState();
    widget.sources.switches.addListener(_changed);
  }

  @override
  void dispose() {
    widget.sources.switches.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle(CapabilityProvider provider, bool on) async {
    final l = AppLocalizations.of(context);
    final switches = widget.sources.switches;
    if (!on) {
      final impact = provider.impact(widget.sources);
      if (impact.playing + impact.running > 0) {
        final accepted = await showShadDialog<bool>(
          context: context,
          builder: (context) => ShadDialog(
            title: Text(l.plgDisableConfirmTitle(provider.name)),
            actions: [
              ShadButton.ghost(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              ShadButton(
                key: const ValueKey('capability-disable-confirm'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.disable),
              ),
            ],
            child: Text(
              [
                l.plgImpactIntro,
                if (impact.playing > 0) l.plgImpactPlaying(impact.playing),
                if (impact.running > 0) l.plgImpactRunning(impact.running),
              ].join('\n'),
            ),
          ),
        );
        if (accepted != true) return;
      }
    }
    try {
      switches.set(provider.id, on);
    } on PluginException catch (e) {
      switches.reload();
      if (mounted) showAppToast(context, e.message, kind: FeedbackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final switches = widget.sources.switches;
    return SettingsSection(
      key: const ValueKey('capabilities'),
      title: l.settingsCapabilities,
      footer: l.capabilitySwitchesFooter,
      children: [
        for (final provider in CapabilityProvider.all)
          SettingsRow(
            key: ValueKey('capability-${provider.id}'),
            title: provider.name,
            description: [
              provider.summary,
              for (final dep in provider.dependencies)
                if (!switches.enabled(dep.id)) l.capabilityNeeds(dep.name),
            ].join(' · '),
            control: ShadSwitch(
              key: ValueKey('capability-switch-${provider.id}'),
              value: switches.isOn(provider.id),
              onChanged: (on) => _toggle(provider, on),
            ),
          ),
      ],
    );
  }
}

/// The capability switches on their own page (opened from the AI plugins).
class CapabilitySwitchesPage extends StatelessWidget {
  const CapabilitySwitchesPage({super.key, required this.sources});
  final SourceManager sources;

  @override
  Widget build(BuildContext context) => AppPage(
    pageContext: const PageContextData(pageType: 'settings_detail'),
    title: Text(AppLocalizations.of(context).settingsCapabilities),
    body: SettingsHeaderScope(
      hidden: true,
      child: SettingsListView(
        children: [CapabilitySwitchesSection(sources: sources)],
      ),
    ),
  );
}
