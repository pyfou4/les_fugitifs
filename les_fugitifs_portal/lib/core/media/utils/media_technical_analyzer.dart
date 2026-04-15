class MediaTechnicalAnalysisResult {
  final String technicalStatus;
  final List<String> technicalWarnings;
  final String? resolutionLabel;
  final String? aspectRatio;

  const MediaTechnicalAnalysisResult({
    required this.technicalStatus,
    required this.technicalWarnings,
    required this.resolutionLabel,
    required this.aspectRatio,
  });
}

class MediaTechnicalAnalyzer {
  const MediaTechnicalAnalyzer();

  MediaTechnicalAnalysisResult analyze({
    required String type,
    required int fileSizeBytes,
    int? width,
    int? height,
    int? durationSec,
    String? mimeType,
  }) {
    final warnings = <String>[];

    final aspectRatio = _computeAspectRatio(width: width, height: height);
    final resolutionLabel = _computeResolutionLabel(width: width, height: height);

    if (type == 'video') {
      if ((width ?? 0) > 1920 || (height ?? 0) > 1080) {
        warnings.add('Video exceeds recommended 1080p playback target for web.');
      }
      if (fileSizeBytes > 80 * 1024 * 1024) {
        warnings.add('Video file is heavier than the recommended 80 MB soft limit.');
      }
      if (mimeType != null && !mimeType.startsWith('video/')) {
        warnings.add('Mime type does not look like a supported video format.');
      }
      if (aspectRatio != null && aspectRatio != '16:9') {
        warnings.add('Aspect ratio differs from the recommended 16:9 format.');
      }
    } else if (type == 'image') {
      if (fileSizeBytes > 10 * 1024 * 1024) {
        warnings.add('Image file is heavier than the recommended 10 MB soft limit.');
      }
      if ((width ?? 0) > 3000 || (height ?? 0) > 3000) {
        warnings.add('Image dimensions are unusually large for standard web display.');
      }
    } else if (type == 'audio') {
      if (fileSizeBytes > 20 * 1024 * 1024) {
        warnings.add('Audio file is heavier than the recommended 20 MB soft limit.');
      }
      if (mimeType != null && !mimeType.startsWith('audio/')) {
        warnings.add('Mime type does not look like a supported audio format.');
      }
      if ((durationSec ?? 0) > 600) {
        warnings.add('Audio duration is unusually long for an in-game media slot.');
      }
    }

    final technicalStatus = warnings.isEmpty ? 'ok' : 'warning';

    return MediaTechnicalAnalysisResult(
      technicalStatus: technicalStatus,
      technicalWarnings: warnings,
      resolutionLabel: resolutionLabel,
      aspectRatio: aspectRatio,
    );
  }

  String? _computeResolutionLabel({
    int? width,
    int? height,
  }) {
    final maxSide = (width ?? 0) > (height ?? 0) ? (width ?? 0) : (height ?? 0);
    if (maxSide <= 0) return null;
    if (maxSide >= 3840) return '4k';
    if (maxSide >= 2560) return '1440p';
    if (maxSide >= 1920) return '1080p';
    if (maxSide >= 1280) return '720p';
    return '${width ?? 0}x${height ?? 0}';
  }

  String? _computeAspectRatio({
    int? width,
    int? height,
  }) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }

    final gcd = _gcd(width, height);
    return '${width ~/ gcd}:${height ~/ gcd}';
  }

  int _gcd(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final temp = y;
      y = x % y;
      x = temp;
    }
    return x == 0 ? 1 : x;
  }
}
