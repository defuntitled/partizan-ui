import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/art.dart';

/// A way to reach the team: what the row says and where a tap leads.
typedef Contact = ({String label, String value, Uri uri});

/// The contacts on the about screen, top to bottom; the block hides while it is empty.
const List<Contact> contacts = [];

/// About: the wordmark, the version, the contacts, the licenses; the rusty plate below.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.version});

  /// Shown instead of the installed version (tests).
  final String? version;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('О ПРИЛОЖЕНИИ')),
    body: LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(
            // The plate stands on the bottom edge, whatever is above it.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Logo(height: 56, color: PartizanColors.red),
                    const SizedBox(height: 4),
                    _Version(version),
                    if (contacts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('КОНТАКТЫ', style: oswald(18, weight: 500)),
                      const SizedBox(height: 8),
                      for (final c in contacts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(c.label),
                            subtitle: Text(c.value),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => launchUrl(
                              c.uri,
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    ListTile(
                      title: const Text('Лицензии'),
                      subtitle: const Text('Шрифты, карта, библиотеки'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'partizan',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                // The plate's last 49 of 1024 rows are sparse pebbles: cut them off so the
                // rubble meets the edge with no background under it.
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 1 - 49 / 1024,
                    child: Image.asset(
                      Art.plate,
                      key: const Key('about-plate'),
                      fit: BoxFit.fitWidth,
                      cacheWidth: 1200,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Version extends StatelessWidget {
  const _Version(this.fixed);

  final String? fixed;

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: fixed == null
        ? PackageInfo.fromPlatform().then(
            (i) => '${i.version} (${i.buildNumber})',
          )
        : SynchronousFuture(fixed!),
    builder: (context, v) => Text(
      v.hasData ? 'Версия ${v.data}' : ' ',
      style: inter(13, color: PartizanColors.muted),
    ),
  );
}

/// Adds the fonts' and the map's licenses to the license page.
void registerAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Oswald',
      'Inter',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    final map = await rootBundle.loadString(Art.world);
    final notice = RegExp(
      r'<!--(.*?)-->',
      dotAll: true,
    ).firstMatch(map)?.group(1);
    if (notice != null) {
      yield LicenseEntryWithLineBreaks(const [
        'World map (Simplemaps)',
      ], notice.trim());
    }
  });
}
