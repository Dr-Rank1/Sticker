import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AboutLicensesScreen extends StatelessWidget {
  const AboutLicensesScreen({super.key});

  static final projectSourceUri = Uri.parse(
    'https://github.com/Dr-Rank1/Sticker',
  );
  static final ffmpegSourceUri = Uri.parse('https://ffmpeg.org/download.html');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutAndLicenses)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            l10n.appTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              side: BorderSide(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.ffmpegLicenseTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.ffmpegLicenseNotice),
                  const SizedBox(height: 10),
                  Text(l10n.sourceCodeOffer),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        key: const Key('view-project-source'),
                        onPressed: () => _openLink(context, projectSourceUri),
                        icon: const Icon(Icons.code_rounded),
                        label: Text(l10n.viewProjectSource),
                      ),
                      OutlinedButton.icon(
                        key: const Key('view-ffmpeg-source'),
                        onPressed: () => _openLink(context, ffmpegSourceUri),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(l10n.viewFfmpegSource),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.thirdPartyLicenses,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.thirdPartyLicensesDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('open-third-party-licenses'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      LicensePage(applicationName: context.l10n.appTitle),
                ),
              );
            },
            icon: const Icon(Icons.description_outlined),
            label: Text(l10n.thirdPartyLicenses),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.couldNotOpenSourceLink)),
    );
  }
}
