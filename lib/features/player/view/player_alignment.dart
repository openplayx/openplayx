part of 'player_page.dart';

extension _PlayerAlignment on PlayerPageState {
  Widget _alignmentSurface({bool landscape = false, bool mobile = false}) =>
      PlayerGlass(
        key: const Key('panel-alignment'),
        padding: EdgeInsets.only(
          bottom: mobile ? _insets.bottom : 0,
          right: mobile && landscape ? _insets.right : 0,
        ),
        radius: mobile && !landscape
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.zero,
        child: Column(
          children: [
            if (mobile && !landscape)
              GestureDetector(
                key: const Key('alignment-handle'),
                behavior: HitTestBehavior.opaque,
                onTap: _closePanel,
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 200) _closePanel();
                },
                child: SizedBox(
                  height: 32,
                  width: double.infinity,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: PlayerStyle.track,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: SubtitleAlignmentPanel(
                controller: _player.alignment,
                subtitles: _subtitles,
                pickReference: widget.pickSubtitle,
                addSubtitle: () => unawaited(_addSubtitleFile()),
                seek: _seekAbsolute,
                close: _closePanel,
                supportsDelay: _backend.supportsDelays,
              ),
            ),
          ],
        ),
      );

  List<Widget> _mobileAlignmentSheet(bool landscape) {
    final size = MediaQuery.sizeOf(context);
    return [
      Positioned.fill(
        child: GestureDetector(
          key: const Key('panel-barrier'),
          behavior: HitTestBehavior.opaque,
          onTap: _closePanel,
          child: const ColoredBox(color: Color(0x59000000)),
        ),
      ),
      if (landscape)
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: math.min(size.width * .6, 380),
          child: _alignmentSurface(mobile: true, landscape: true),
        )
      else
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: size.height * .65,
          child: _alignmentSurface(mobile: true),
        ),
    ];
  }
}
