import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/security/screen_protection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../content/domain/content.dart';

final screenProtectionProvider = Provider<ScreenProtection>(
  (ref) => ScreenProtection(),
);

typedef ViewerArgs = ({String id, bool manage});

/// Metadata needed to decide how to render the file.
final viewerContentProvider = FutureProvider.autoDispose
    .family<Content, ViewerArgs>(
      (ref, a) => a.manage
          ? ref.watch(manageContentRepositoryProvider).get(a.id)
          : ref.watch(contentRepositoryProvider).detail(a.id),
    );

/// File bytes, held in memory only for as long as the viewer is open
/// (FR-055: never written to disk, never exposed as a URL).
final viewerBytesProvider = FutureProvider.autoDispose
    .family<FileBytes, ViewerArgs>(
      (ref, a) => a.manage
          ? ref.watch(manageContentRepositoryProvider).preview(a.id)
          : ref.watch(contentRepositoryProvider).file(a.id),
    );

/// FR-051..058: in-app viewer for PDFs and images with watermark and
/// capture restriction. There is intentionally no download/share/open-in.
class SecureViewerScreen extends ConsumerStatefulWidget {
  const SecureViewerScreen({super.key, required this.id, this.manage = false});

  final String id;

  /// Manager preview (library/admin) instead of the student endpoint.
  final bool manage;

  @override
  ConsumerState<SecureViewerScreen> createState() => _SecureViewerScreenState();
}

class _SecureViewerScreenState extends ConsumerState<SecureViewerScreen> {
  StreamSubscription<bool>? _captureSub;
  bool _captured = false;
  bool _protectionOn = false;
  int? _page;
  int? _pageCount;

  ViewerArgs get _args => (id: widget.id, manage: widget.manage);

  @override
  void initState() {
    super.initState();
    _captureSub = ref
        .read(screenProtectionProvider)
        .captureChanges
        .listen((c) => setState(() => _captured = c));
    // Capture protection is always on while protected content is shown.
    _protectionOn = true;
    unawaited(ref.read(screenProtectionProvider).enable());
  }

  @override
  void dispose() {
    _captureSub?.cancel();
    if (_protectionOn) unawaited(ref.read(screenProtectionProvider).disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final content = ref.watch(viewerContentProvider(_args));
    // Non-identifying viewer code issued by the server (FR-057): part of the
    // student metadata, and sent with every file response.
    final code =
        content.value?.watermarkText ??
        ref.watch(viewerBytesProvider(_args)).value?.watermark;
    final watermark = code == null
        ? null
        : '$code · ${context.formatDate(DateTime.now())}';

    return Theme(
      data: AppTheme.dark(),
      child: Scaffold(
        backgroundColor: AppColors.surfaceDark,
        appBar: AppBar(
          backgroundColor: AppColors.navy950,
          title: Text(
            content.value?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_pageCount != null && _page != null)
              Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 16),
                  child: Text(
                    l.pageOf(_page!, _pageCount!),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            content.when(
              loading: () => _Loading(label: l.loadingFile),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(viewerContentProvider(_args)),
              ),
              data: (c) => _buildFile(context, c),
            ),
            if (watermark != null)
              IgnorePointer(child: _Watermark(text: watermark)),
            if (_captured) _CaptureShield(message: l.captureHidden),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: IgnorePointer(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      l.viewerProtected,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFile(BuildContext context, Content content) {
    final l = context.l10n;
    final file = content.file;
    if (file == null) {
      return EmptyView(icon: Icons.hourglass_empty_rounded, title: l.noFileYet);
    }
    if (!file.isViewable) {
      return EmptyView(icon: Icons.block_rounded, title: l.unsupportedFormat);
    }
    final bytes = ref.watch(viewerBytesProvider(_args));
    return bytes.when(
      loading: () => _Loading(label: l.loadingFile),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(viewerBytesProvider(_args)),
      ),
      data: (data) => file.isPdf
          ? PdfViewer.data(
              data.bytes,
              sourceName: 'content-${content.id}-v${file.version}',
              params: PdfViewerParams(
                backgroundColor: AppColors.surfaceDark,
                margin: 12,
                sizeDelegateProvider: const PdfViewerSizeDelegateProviderLegacy(
                  maxScale: 6,
                ),
                textSelectionParams: const PdfTextSelectionParams(
                  enabled: false,
                ),
                onViewerReady: (document, controller) => setState(() {
                  _pageCount = document.pages.length;
                  _page = 1;
                }),
                onPageChanged: (page) => setState(() => _page = page),
                errorBannerBuilder: (context, error, _, _) => EmptyView(
                  icon: Icons.broken_image_outlined,
                  title: l.unsupportedFormat,
                ),
              ),
            )
          : PhotoView(
              imageProvider: MemoryImage(data.bytes),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              backgroundDecoration: const BoxDecoration(
                color: AppColors.surfaceDark,
              ),
              semanticLabel: content.title,
              errorBuilder: (context, _, _) => EmptyView(
                icon: Icons.broken_image_outlined,
                title: l.unsupportedFormat,
              ),
            ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.cyan400),
          const SizedBox(height: AppSpacing.lg),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

/// Tiled diagonal watermark with the student's non-sensitive code (FR-057).
class _Watermark extends StatelessWidget {
  const _Watermark({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRect(child: CustomPaint(painter: _WatermarkPainter(text))),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter(this.text);
  final String text;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.09),
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const gapX = 60.0;
    const gapY = 110.0;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(-math.pi / 7);
    final span = math.sqrt(size.width * size.width + size.height * size.height);
    for (var y = -span / 2; y < span / 2; y += gapY) {
      final offset = (y ~/ gapY).isEven ? 0.0 : (painter.width + gapX) / 2;
      for (
        var x = -span / 2 - offset;
        x < span / 2;
        x += painter.width + gapX
      ) {
        painter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter old) => old.text != text;
}

class _CaptureShield extends StatelessWidget {
  const _CaptureShield({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navy950,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.screen_lock_portrait_rounded,
                size: 56,
                color: AppColors.cyan400,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
