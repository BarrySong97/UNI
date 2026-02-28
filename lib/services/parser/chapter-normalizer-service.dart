class ChapterNormalizerService {
  String normalize(String content) {
    return content.replaceAll('\r\n', '\n').trim();
  }
}
