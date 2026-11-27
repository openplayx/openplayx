import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../capabilities/web_playback/web_playback_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/feedback/app_feedback.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/icons/app_icons.dart';

class WebPlaybackSettingsPage extends StatefulWidget {
  const WebPlaybackSettingsPage({super.key, required this.service});
  final WebPlaybackService service;
  @override
  State<WebPlaybackSettingsPage> createState() =>
      _WebPlaybackSettingsPageState();
}

class _WebPlaybackSettingsPageState extends State<WebPlaybackSettingsPage> {
  List<InternetAddress> _interfaces = [];
  InternetAddress? _selected;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  Future<void> _loadInterfaces() async {
    try {
      final values = await WebPlaybackService.interfaces();
      if (mounted) {
        setState(() {
          _interfaces = values;
          _selected = values.firstOrNull;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).webPlaybackFailed);
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) _error = AppLocalizations.of(context).webPlaybackFailed;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _clock(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final service = widget.service;
    return AppPage(
      pageContext: const PageContextData(pageType: 'web_playback_settings'),
      title: Text(l.webPlaybackTitle),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final scopes = service.catalog.scopes;
          return SettingsListView(
            children: [
              SettingsSection(
                title: l.webPlaybackTitle,
                footer: l.webPlaybackHttpNotice,
                children: [
                  SettingsRow(
                    title: l.webPlaybackEnabled,
                    description: service.running
                        ? l.webPlaybackDescription
                        : l.webPlaybackStopped,
                    control: ShadSwitch(
                      key: const ValueKey('web-playback-toggle'),
                      value: service.running,
                      onChanged:
                          _busy || (!service.running && _selected == null)
                          ? null
                          : (enabled) => _run(() async {
                              if (enabled) {
                                if (_selected == null) return;
                                await service.start(_selected!);
                              } else {
                                await service.stop();
                              }
                            }),
                    ),
                  ),
                  if (!service.running)
                    SettingsRow(
                      title: l.webPlaybackInterface,
                      stacked: true,
                      control: _interfaces.isEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.webPlaybackNoNetwork),
                                TextButton(
                                  onPressed: _busy ? null : _loadInterfaces,
                                  child: Text(l.retry),
                                ),
                              ],
                            )
                          : DropdownButton<String>(
                              isExpanded: true,
                              value: _selected?.address,
                              items: [
                                for (final ip in _interfaces)
                                  DropdownMenuItem(
                                    value: ip.address,
                                    child: Text(ip.address),
                                  ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (ip) => setState(
                                      () => _selected = _interfaces.firstWhere(
                                        (a) => a.address == ip,
                                      ),
                                    ),
                            ),
                    ),
                  if (service.address != null)
                    SettingsRow(
                      title: l.webPlaybackAddress,
                      stacked: true,
                      control: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(service.address!),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ShadButton.secondary(
                                onPressed: () => _run(() async {
                                  await Clipboard.setData(
                                    ClipboardData(text: service.address!),
                                  );
                                  if (context.mounted) {
                                    showAppToast(
                                      context,
                                      l.webPlaybackCopied,
                                      kind: FeedbackKind.success,
                                    );
                                  }
                                }),
                                child: Text(l.shadCopy),
                              ),
                              ShadButton(
                                onPressed: () => _run(() async {
                                  if (!await launchUrl(
                                    Uri.parse(service.address!),
                                    mode: LaunchMode.externalApplication,
                                  )) {
                                    throw StateError('launch_failed');
                                  }
                                }),
                                child: Text(l.webPlaybackPreview),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (_error != null)
                AppAlert.error(
                  title: l.webPlaybackFailed,
                  description: _error!,
                ),
              if (service.running)
                SettingsSection(
                  title: l.webPlaybackPairing,
                  footer: l.webPlaybackCodeHelp,
                  children: [
                    SettingsRow(
                      title: l.webPlaybackCode,
                      stacked: true,
                      control: service.pairingCode == null
                          ? Text(l.webPlaybackExpired)
                          : SelectableText(
                              '${service.pairingCode!.substring(0, 3)} ${service.pairingCode!.substring(3)}',
                              style: ShadTheme.of(context).textTheme.h2,
                            ),
                    ),
                    SettingsRow(
                      title: l.webPlaybackRefreshCode,
                      icon: AppIcons.refresh,
                      onTap: service.refreshPairingCode,
                    ),
                  ],
                ),
              SettingsSection(
                title: l.webPlaybackShare,
                footer: l.webPlaybackShareHelp,
                children: [
                  if (scopes.isEmpty) Text(l.webPlaybackNoScopes),
                  for (final scope in scopes)
                    SettingsRow(
                      title: scope.name,
                      control: ShadSwitch(
                        value: service.sharedScopes.contains(scope.id),
                        onChanged: _busy
                            ? null
                            : (value) => _run(() async {
                                final ids = service.sharedScopes.toSet();
                                if (value) {
                                  ids.add(scope.id);
                                } else {
                                  ids.remove(scope.id);
                                }
                                await service.setSharedScopes(ids);
                              }),
                      ),
                    ),
                ],
              ),
              SettingsSection(
                title: l.webPlaybackSessions,
                footer: l.webPlaybackKeepOpen,
                children: [
                  if (service.sessions.isEmpty) Text(l.webPlaybackNoSessions),
                  for (final session in service.sessions)
                    SettingsRow(
                      title: session.device,
                      description:
                          '${session.media.title}\n${l.webPlaybackDirect} · ${_clock(session.positionMs)} / ${_clock(session.durationMs)}',
                      control: ShadButton.outline(
                        onPressed: _busy
                            ? null
                            : () => _run(() => service.endSession(session.id)),
                        child: Text(l.webPlaybackEndSession),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
