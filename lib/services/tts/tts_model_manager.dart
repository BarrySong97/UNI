import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tts_model_config.dart';

enum TtsModelStatus {
  notDownloaded,
  downloading,
  extracting,
  ready,
  error,
}

class TtsModelState {
  const TtsModelState({
    this.status = TtsModelStatus.notDownloaded,
    this.progress = 0.0,
    this.errorMessage,
  });

  final TtsModelStatus status;

  /// 0.0 – 1.0 download progress.
  final double progress;
  final String? errorMessage;
}

class TtsModelManager extends ChangeNotifier {
  final Map<String, TtsModelState> _states = {};
  late String _modelsRoot;

  Future<void> initialize() async {
    final docsDir = await getApplicationDocumentsDirectory();
    _modelsRoot = p.join(docsDir.path, 'tts-models');
    await Directory(_modelsRoot).create(recursive: true);

    // Check existing models.
    for (final model in TtsModels.all) {
      final dir = Directory(p.join(_modelsRoot, model.dirName));
      final modelFile = File(p.join(dir.path, model.modelFileName));
      if (dir.existsSync() && modelFile.existsSync()) {
        _states[model.id] = const TtsModelState(status: TtsModelStatus.ready);
      } else {
        _states[model.id] =
            const TtsModelState(status: TtsModelStatus.notDownloaded);
      }
    }
    notifyListeners();
  }

  TtsModelState stateOf(TtsModelInfo model) {
    return _states[model.id] ?? const TtsModelState();
  }

  bool isReady(TtsModelInfo model) {
    return stateOf(model).status == TtsModelStatus.ready;
  }

  String getModelPath(TtsModelInfo model) {
    return p.join(_modelsRoot, model.dirName, model.modelFileName);
  }

  String getTokensPath(TtsModelInfo model) {
    return p.join(_modelsRoot, model.dirName, model.tokensRelative);
  }

  String getDataDir(TtsModelInfo model) {
    return p.join(_modelsRoot, model.dirName, model.dataDirRelative);
  }

  Future<void> downloadModel(TtsModelInfo model) async {
    if (stateOf(model).status == TtsModelStatus.downloading ||
        stateOf(model).status == TtsModelStatus.extracting) {
      return;
    }

    _updateState(
        model, const TtsModelState(status: TtsModelStatus.downloading));

    try {
      final tempFile = File(p.join(_modelsRoot, '${model.id}.tar.bz2'));

      // Download.
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(model.downloadUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        // Handle redirects.
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers.value('location');
          if (location != null) {
            final redirectRequest = await client.getUrl(Uri.parse(location));
            final redirectResponse = await redirectRequest.close();
            await _downloadResponse(
                redirectResponse, tempFile, model, client);
            return;
          }
        }
        throw HttpException('Download failed: ${response.statusCode}');
      }

      await _downloadResponse(response, tempFile, model, client);
    } catch (e) {
      _updateState(
        model,
        TtsModelState(
          status: TtsModelStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _downloadResponse(
    HttpClientResponse response,
    File tempFile,
    TtsModelInfo model,
    HttpClient client,
  ) async {
    final contentLength = response.contentLength;
    int received = 0;

    final sink = tempFile.openWrite();
    await for (final chunk in response) {
      sink.add(chunk);
      received += chunk.length;
      if (contentLength > 0) {
        _updateState(
          model,
          TtsModelState(
            status: TtsModelStatus.downloading,
            progress: received / contentLength,
          ),
        );
      }
    }
    await sink.close();
    client.close();

    // Extract.
    _updateState(
        model, const TtsModelState(status: TtsModelStatus.extracting));

    await compute(_extractArchive, _ExtractParams(
      archivePath: tempFile.path,
      outputDir: _modelsRoot,
    ));

    // Cleanup temp file.
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }

    _updateState(model, const TtsModelState(status: TtsModelStatus.ready));
  }

  void _updateState(TtsModelInfo model, TtsModelState state) {
    _states[model.id] = state;
    notifyListeners();
  }

  Future<void> deleteModel(TtsModelInfo model) async {
    final dir = Directory(p.join(_modelsRoot, model.dirName));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    _updateState(
        model, const TtsModelState(status: TtsModelStatus.notDownloaded));
  }
}

class _ExtractParams {
  const _ExtractParams({required this.archivePath, required this.outputDir});
  final String archivePath;
  final String outputDir;
}

/// Runs in an isolate via compute().
void _extractArchive(_ExtractParams params) {
  final bytes = File(params.archivePath).readAsBytesSync();

  // Decompress bzip2 → tar.
  final bz2Decoded = BZip2Decoder().decodeBytes(bytes);

  // Decode tar.
  final archive = TarDecoder().decodeBytes(bz2Decoded);

  for (final file in archive) {
    final filePath = p.join(params.outputDir, file.name);
    if (file.isFile) {
      final outFile = File(filePath);
      outFile.createSync(recursive: true);
      outFile.writeAsBytesSync(file.content as List<int>);
    } else {
      Directory(filePath).createSync(recursive: true);
    }
  }
}
