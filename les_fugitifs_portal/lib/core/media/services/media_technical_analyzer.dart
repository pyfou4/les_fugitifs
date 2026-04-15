class MediaTechnicalAnalysis {
  final String technicalStatus;
  final List<String> warnings;
  final String? resolutionLabel;
  final String? aspectRatio;

  const MediaTechnicalAnalysis({
    required this.technicalStatus,
    required this.warnings,
    required this.resolutionLabel,
    required this.aspectRatio,
  });
}

class MediaTechnicalAnalyzer {
  const MediaTechnicalAnalyzer();

  MediaTechnicalAnalysis analyze({
    required String type,
    required int fileSizeBytes,
    int? width,
    int? height,
    int? durationSec,
    String? mimeType,
  }) {
    final warnings = <String>[];
    var status = 'ok';

    if (type == 'video') {
      if (mimeType != null && mimeType.isNotEmpty && mimeType != 'video/mp4') {
        status = 'error';
        warnings.add('Format vidéo non recommandé pour Flutter Web.');
      }
      if (width != null && width > 1920) {
        status = _promoteStatus(status, 'warning');
        warnings.add('Résolution supérieure au 1080p recommandé.');
      }
      if (fileSizeBytes > 80 * 1024 * 1024) {
        status = _promoteStatus(status, 'warning');
        warnings.add('Poids vidéo élevé pour lecture web fluide.');
      }
      if (durationSec != null && durationSec > 300) {
        status = _promoteStatus(status, 'warning');
        warnings.add('Durée longue, à vérifier côté UX.');
      }
    }

    if (type == 'image') {
      if (fileSizeBytes > 10 * 1024 * 1024) {
        status = _promoteStatus(status, 'warning');
        warnings.add('Image lourde pour un simple affichage.');
      }
      if (width != null && width > 3000) {
        status = _promoteStatus(status, 'warning');
        warnings.add('Dimensions image très élevées.');
      }
    }

    if (type == 'audio') {
      if (mimeType != null && mimeType.isNotEmpty &&
          mimeType != 'audio/mpeg' &&
          mimeType != 'audio/mp3' &&
          mimeType != 'audio/wav') {
        status = _promoteStatus(status, 'error');
        warnings.add('Format audio à confirmer pour compatibilité web.');
      }
      if (fileSizeBytes > 20 * 1024 * 1024) {
        status = _promoteStatus(status, 'warning');
        warnings.add('Audio volumineux.');
      }
    }

    return MediaTechnicalAnalysis(
      technicalStatus: status,
      warnings: List<String>.unmodifiable(warnings),
      resolutionLabel: _buildResolutionLabel(width: width, height: height),
      aspectRatio: _buildAspectRatio(width: width, height: height),
    );
  }

  String _promoteStatus(String current, String candidate) {
    if (current == 'error' || candidate == current) {
      return current;
    }
    if (candidate == 'error') {
      return 'error';
    }
    if (current == 'ok' && candidate == 'warning') {
      return 'warning';
    }
    return current;
  }

  String? _buildResolutionLabel({int? width, int? height}) {
    if (width == null || height == null) {
      return null;
    }
    final longSide = width > height ? width : height;
    if (longSide >= 3840) return '4K';
    if (longSide >= 2560) return '1440p';
    if (longSide >= 1920) return '1080p';
    if (longSide >= 1280) return '720p';
    return '${width}x$height';
  }

  String? _buildAspectRatio({int? width, int? height}) {
    if (width == null || height == null || height == 0) {
      return null;
    }
    final gcd = _computeGcd(width, height);
    return '${width ~/ gcd}:${height ~/ gcd}';
  }

  int _computeGcd(int a, int b) {
    while (b != 0) {
      final temp = b;
      b = a % b;
      a = temp;
    }
    return a;
  }
}
