import 'package:malsami/malsami.dart';

class PhoneticsResult {
  final String us;
  final String uk;
  const PhoneticsResult({required this.us, required this.uk});
}

class PhoneticsService {
  late final EnglishG2P _usG2p;
  late final EnglishG2P _ukG2p;

  Future<void> initialize() async {
    _usG2p = EnglishG2P();
    await _usG2p.initialize();
    _ukG2p = EnglishG2P(british: true);
    await _ukG2p.initialize();
  }

  Future<PhoneticsResult> lookup(String text) async {
    final (usPhonemes, _) = await _usG2p.convert(text);
    final (ukPhonemes, _) = await _ukG2p.convert(text);
    return PhoneticsResult(us: usPhonemes, uk: ukPhonemes);
  }
}
