import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class TmdbAttribution extends StatelessWidget {
  const TmdbAttribution({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      ShadButton.ghost(
        onPressed: () => launchUrl(Uri.parse('https://www.themoviedb.org')),
        child: SvgPicture.asset(
          'assets/branding/tmdb.svg',
          width: 100,
          semanticsLabel: 'TMDB',
        ),
      ),
      const Text(
        'This product uses the TMDB API but is not endorsed or certified by TMDB.',
      ),
    ],
  );
}
