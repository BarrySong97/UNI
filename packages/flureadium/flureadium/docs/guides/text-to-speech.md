# Text-to-Speech Guide

This guide covers integrating text-to-speech (TTS) into your reading app.

## Enabling TTS

### Basic Setup

```dart
// Enable TTS with default settings
await flureadium.ttsEnable(null);

// Or with custom preferences
await flureadium.ttsEnable(TTSPreferences(
  speed: 1.0,   // Normal speed
  pitch: 1.0,   // Normal pitch
));
```

### With Voice Selection

```dart
// Get available voices
final voices = await flureadium.ttsGetAvailableVoices();

// Select a voice
final englishVoice = voices.firstWhere(
  (v) => v.language.startsWith('en'),
  orElse: () => voices.first,
);

// Enable with selected voice
await flureadium.ttsEnable(TTSPreferences(
  speed: 1.0,
  pitch: 1.0,
  voiceIdentifier: englishVoice.identifier,
));
```

## Playback Controls

### Basic Controls

```dart
// Start playing from current position
await flureadium.play(null);

// Start from a specific position
await flureadium.play(savedLocator);

// Pause
await flureadium.pause();

// Resume
await flureadium.resume();

// Stop completely
await flureadium.stop();
```

### Sentence Navigation

```dart
// Move to next sentence
await flureadium.next();

// Move to previous sentence
await flureadium.previous();
```

## Voice Selection

### Getting Available Voices

```dart
final voices = await flureadium.ttsGetAvailableVoices();

for (final voice in voices) {
  print('Name: ${voice.name}');
  print('Language: ${voice.language}');
  print('ID: ${voice.identifier}');
  print('---');
}
```

### Setting a Voice

```dart
// Set by identifier
await flureadium.ttsSetVoice(
  'com.apple.voice.compact.en-US.Samantha',
  'en-US',
);

// Or just identifier without language filter
await flureadium.ttsSetVoice(voiceId, null);
```

### Voice Picker UI

```dart
class VoicePicker extends StatefulWidget {
  @override
  State<VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends State<VoicePicker> {
  List<ReaderTTSVoice>? _voices;
  String? _selectedVoiceId;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voices = await flureadium.ttsGetAvailableVoices();
    setState(() => _voices = voices);
  }

  @override
  Widget build(BuildContext context) {
    if (_voices == null) {
      return CircularProgressIndicator();
    }

    // Group by language
    final grouped = <String, List<ReaderTTSVoice>>{};
    for (final voice in _voices!) {
      final lang = voice.language.split('-').first;
      grouped.putIfAbsent(lang, () => []).add(voice);
    }

    return ListView(
      children: grouped.entries.map((entry) {
        return ExpansionTile(
          title: Text(_languageName(entry.key)),
          children: entry.value.map((voice) {
            return RadioListTile<String>(
              title: Text(voice.name),
              subtitle: Text(voice.language),
              value: voice.identifier,
              groupValue: _selectedVoiceId,
              onChanged: (id) async {
                setState(() => _selectedVoiceId = id);
                await flureadium.ttsSetVoice(id!, voice.language);
              },
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  String _languageName(String code) {
    const names = {'en': 'English', 'es': 'Spanish', 'fr': 'French'};
    return names[code] ?? code;
  }
}
```

## Speed and Pitch Control

### Adjusting Speed

```dart
await flureadium.ttsSetPreferences(TTSPreferences(
  speed: 1.5,  // 50% faster
));
```

### Speed Slider

```dart
class SpeedControl extends StatefulWidget {
  @override
  State<SpeedControl> createState() => _SpeedControlState();
}

class _SpeedControlState extends State<SpeedControl> {
  double _speed = 1.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Speed: ${_speed.toStringAsFixed(1)}x'),
        Slider(
          min: 0.5,
          max: 2.0,
          divisions: 15,
          value: _speed,
          onChanged: (value) async {
            setState(() => _speed = value);
            await flureadium.ttsSetPreferences(TTSPreferences(
              speed: value,
            ));
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => _setSpeed(0.75),
              child: Text('0.75x'),
            ),
            TextButton(
              onPressed: () => _setSpeed(1.0),
              child: Text('1x'),
            ),
            TextButton(
              onPressed: () => _setSpeed(1.5),
              child: Text('1.5x'),
            ),
            TextButton(
              onPressed: () => _setSpeed(2.0),
              child: Text('2x'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    await flureadium.ttsSetPreferences(TTSPreferences(speed: speed));
  }
}
```

## TTS Highlighting

Highlight the current sentence and word being spoken.

### Setting Decoration Styles

```dart
await flureadium.setDecorationStyle(
  // Current sentence highlight
  ReaderDecorationStyle(
    style: DecorationStyle.highlight,
    tint: Color(0x80FFFF00),  // Semi-transparent yellow
  ),
  // Current word highlight
  ReaderDecorationStyle(
    style: DecorationStyle.underline,
    tint: Color(0xFF0000FF),  // Blue underline
  ),
);
```

### Customizable Highlight Colors

```dart
class TTSHighlightSettings {
  Color sentenceColor;
  Color wordColor;

  TTSHighlightSettings({
    this.sentenceColor = const Color(0x80FFFF00),
    this.wordColor = const Color(0xFF0000FF),
  });

  Future<void> apply() async {
    await flureadium.setDecorationStyle(
      ReaderDecorationStyle(
        style: DecorationStyle.highlight,
        tint: sentenceColor,
      ),
      ReaderDecorationStyle(
        style: DecorationStyle.underline,
        tint: wordColor,
      ),
    );
  }
}
```

## Tracking Playback State

### Listening to State Changes

```dart
flureadium.onTimebasedPlayerStateChanged.listen((state) {
  switch (state.state) {
    case TimebasedState.playing:
      print('Playing');
      break;
    case TimebasedState.paused:
      print('Paused');
      break;
    case TimebasedState.ended:
      print('Finished');
      break;
    case TimebasedState.loading:
      print('Loading...');
      break;
    case TimebasedState.failure:
      print('Error');
      break;
  }
});
```

### Playback UI State

```dart
class TTSController extends StatefulWidget {
  @override
  State<TTSController> createState() => _TTSControllerState();
}

class _TTSControllerState extends State<TTSController> {
  TimebasedState _state = TimebasedState.paused;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = flureadium.onTimebasedPlayerStateChanged.listen((state) {
      setState(() => _state = state.state);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous),
          onPressed: () => flureadium.previous(),
        ),
        IconButton(
          icon: Icon(_state == TimebasedState.playing
              ? Icons.pause
              : Icons.play_arrow),
          iconSize: 48,
          onPressed: _togglePlayback,
        ),
        IconButton(
          icon: Icon(Icons.skip_next),
          onPressed: () => flureadium.next(),
        ),
      ],
    );
  }

  Future<void> _togglePlayback() async {
    if (_state == TimebasedState.playing) {
      await flureadium.pause();
    } else {
      await flureadium.resume();
    }
  }
}
```

## Complete TTS Integration

```dart
class TTSReaderScreen extends StatefulWidget {
  final Publication publication;

  const TTSReaderScreen({required this.publication, super.key});

  @override
  State<TTSReaderScreen> createState() => _TTSReaderScreenState();
}

class _TTSReaderScreenState extends State<TTSReaderScreen> {
  final _flureadium = Flureadium();
  bool _ttsEnabled = false;
  TimebasedState _playbackState = TimebasedState.paused;
  double _speed = 1.0;
  List<ReaderTTSVoice>? _voices;
  String? _selectedVoiceId;

  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _loadVoices();
    _stateSubscription = _flureadium.onTimebasedPlayerStateChanged.listen(
      (state) => setState(() => _playbackState = state.state),
    );
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    if (_ttsEnabled) {
      _flureadium.stop();
    }
    super.dispose();
  }

  Future<void> _loadVoices() async {
    final voices = await _flureadium.ttsGetAvailableVoices();
    setState(() {
      _voices = voices;
      // Select first English voice by default
      _selectedVoiceId = voices
          .firstWhere(
            (v) => v.language.startsWith('en'),
            orElse: () => voices.first,
          )
          .identifier;
    });
  }

  Future<void> _enableTTS() async {
    await _flureadium.ttsEnable(TTSPreferences(
      speed: _speed,
      voiceIdentifier: _selectedVoiceId,
    ));

    // Set up highlighting
    await _flureadium.setDecorationStyle(
      ReaderDecorationStyle(
        style: DecorationStyle.highlight,
        tint: Color(0x80FFFF00),
      ),
      ReaderDecorationStyle(
        style: DecorationStyle.underline,
        tint: Color(0xFF0000FF),
      ),
    );

    setState(() => _ttsEnabled = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Reader
          Expanded(
            child: ReadiumReaderWidget(
              publication: widget.publication,
            ),
          ),

          // TTS Controls
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              children: [
                // Enable/Disable TTS
                if (!_ttsEnabled)
                  ElevatedButton.icon(
                    icon: Icon(Icons.record_voice_over),
                    label: Text('Enable Read Aloud'),
                    onPressed: _enableTTS,
                  )
                else
                  Column(
                    children: [
                      // Playback controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.skip_previous),
                            onPressed: () => _flureadium.previous(),
                          ),
                          IconButton(
                            icon: Icon(
                              _playbackState == TimebasedState.playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                            ),
                            iconSize: 56,
                            onPressed: _togglePlayback,
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_next),
                            onPressed: () => _flureadium.next(),
                          ),
                          IconButton(
                            icon: Icon(Icons.stop),
                            onPressed: _stopTTS,
                          ),
                        ],
                      ),

                      // Speed control
                      Row(
                        children: [
                          Text('Speed:'),
                          Expanded(
                            child: Slider(
                              min: 0.5,
                              max: 2.0,
                              divisions: 15,
                              value: _speed,
                              label: '${_speed.toStringAsFixed(1)}x',
                              onChanged: (value) async {
                                setState(() => _speed = value);
                                await _flureadium.ttsSetPreferences(
                                  TTSPreferences(speed: value),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // Voice selection
                      if (_voices != null)
                        DropdownButton<String>(
                          value: _selectedVoiceId,
                          items: _voices!.map((v) {
                            return DropdownMenuItem(
                              value: v.identifier,
                              child: Text('${v.name} (${v.language})'),
                            );
                          }).toList(),
                          onChanged: (id) async {
                            setState(() => _selectedVoiceId = id);
                            final voice = _voices!.firstWhere(
                              (v) => v.identifier == id,
                            );
                            await _flureadium.ttsSetVoice(
                              id!,
                              voice.language,
                            );
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePlayback() async {
    if (_playbackState == TimebasedState.playing) {
      await _flureadium.pause();
    } else {
      await _flureadium.play(null);
    }
  }

  Future<void> _stopTTS() async {
    await _flureadium.stop();
    setState(() => _ttsEnabled = false);
  }
}
```

## Platform Notes

### iOS

- Uses AVSpeechSynthesizer
- Rich voice selection
- System voices available

### Android

- Uses TextToSpeech engine
- Voice quality varies by device
- May require downloading voices

### Web

- Uses Web Speech API
- Browser-dependent voice availability
- Limited customization

## See Also

- [TTSPreferences Reference](../api-reference/preferences.md#ttspreferences)
- [Audiobook Playback](audiobook-playback.md) - For pre-recorded audio
- [Streams and Events](../api-reference/streams-events.md) - Playback state tracking
