import '../models/reader_preferences.dart';

class RenderDiffJob {
  const RenderDiffJob({
    required this.epubPath,
    required this.cacheDir,
    required this.outputDir,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.devicePixelRatio,
    required this.preferences,
    this.sampleName,
    this.chapterIndices,
    this.maxChapters,
    this.maxPagesPerChapter,
  });

  final String epubPath;
  final String cacheDir;
  final String outputDir;
  final double viewportWidth;
  final double viewportHeight;
  final double devicePixelRatio;
  final ReaderPreferences preferences;
  final String? sampleName;
  final List<int>? chapterIndices;
  final int? maxChapters;
  final int? maxPagesPerChapter;

  Map<String, dynamic> toJson() => {
    'epubPath': epubPath,
    'cacheDir': cacheDir,
    'outputDir': outputDir,
    'viewportWidth': viewportWidth,
    'viewportHeight': viewportHeight,
    'devicePixelRatio': devicePixelRatio,
    'preferences': preferences.toJson(),
    'sampleName': sampleName,
    'chapterIndices': chapterIndices,
    'maxChapters': maxChapters,
    'maxPagesPerChapter': maxPagesPerChapter,
  };

  factory RenderDiffJob.fromJson(Map<String, dynamic> json) {
    return RenderDiffJob(
      epubPath: json['epubPath'] as String? ?? '',
      cacheDir: json['cacheDir'] as String? ?? '',
      outputDir: json['outputDir'] as String? ?? '',
      viewportWidth: (json['viewportWidth'] as num?)?.toDouble() ?? 390,
      viewportHeight: (json['viewportHeight'] as num?)?.toDouble() ?? 844,
      devicePixelRatio: (json['devicePixelRatio'] as num?)?.toDouble() ?? 2.0,
      preferences: ReaderPreferences.fromJson(
        (json['preferences'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      sampleName: json['sampleName'] as String?,
      chapterIndices:
          (json['chapterIndices'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList(),
      maxChapters: (json['maxChapters'] as num?)?.toInt(),
      maxPagesPerChapter: (json['maxPagesPerChapter'] as num?)?.toInt(),
    );
  }
}
