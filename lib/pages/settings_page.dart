import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final packageInfoAsync = ref.watch(packageInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: ListView(
        children: [
          // -----------------------------------------------------------------
          // Section 1 — Language
          // -----------------------------------------------------------------
          _SectionHeader(title: l10n.settingsLanguage),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButton<String?>(
              isExpanded: true,
              value: settings.localeCode,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.settingsLanguageSystem),
                ),
                DropdownMenuItem(
                  value: 'ko',
                  child: Text(l10n.settingsLanguageKorean),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(l10n.settingsLanguageEnglish),
                ),
              ],
              onChanged: (code) => notifier.setLocale(code),
            ),
          ),

          const Divider(),

          // -----------------------------------------------------------------
          // Section 2 — Sound / Haptic
          // -----------------------------------------------------------------
          _SectionHeader(title: l10n.settingsSoundHaptic),
          SwitchListTile(
            title: Text(l10n.settingsTts),
            value: settings.tts,
            onChanged: notifier.setTts,
          ),
          SwitchListTile(
            title: Text(l10n.settingsBeep),
            value: settings.beep,
            onChanged: notifier.setBeep,
          ),
          SwitchListTile(
            title: Text(l10n.settingsHaptic),
            value: settings.haptic,
            onChanged: notifier.setHaptic,
          ),

          const Divider(),

          // -----------------------------------------------------------------
          // Section 3 — Display Format
          // -----------------------------------------------------------------
          _SectionHeader(title: l10n.settingsDisplayFormat),
          RadioGroup<String>(
            groupValue: settings.displayFormat,
            onChanged: (v) {
              if (v != null) notifier.setDisplayFormat(v);
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  title: Text(l10n.settingsFormatMmss),
                  value: 'mmss',
                ),
                RadioListTile<String>(
                  title: Text(l10n.settingsFormatSeconds),
                  value: 'seconds',
                ),
              ],
            ),
          ),

          const Divider(),

          // -----------------------------------------------------------------
          // Section 4 — App Info
          // -----------------------------------------------------------------
          _SectionHeader(title: l10n.settingsAppInfo),
          ListTile(
            title: Text(l10n.settingsVersion),
            trailing: Text(
              packageInfoAsync.when(
                data: (info) => '${info.version}+${info.buildNumber}',
                loading: () => '…',
                error: (e, s) => '–',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: const Color(0xFFFF5252)),
      ),
    );
  }
}
