import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:fl_chart/fl_chart.dart';

base class AudioBuffer extends Struct {
  external Pointer<Float> data;
  @Int32()
  external int length;
}

base class AudioEffects extends Struct {
  @Float()
  external double gain;
  @Float()
  external double echoDelay;
  @Float()
  external double echoIntensity;
  @Float()
  external double lowPass;
  @Float()
  external double highPass;
}

base class SpectrumData extends Struct {
  external Pointer<Float> frequencies;
  external Pointer<Float> magnitudes;
  @Int32()
  external int length;
}

typedef ProcessAudioBufferFunc = Pointer<AudioBuffer> Function(
    Pointer<AudioBuffer> buffer, Pointer<AudioEffects> effects);
typedef ProcessAudioBuffer = Pointer<AudioBuffer> Function(
    Pointer<AudioBuffer> buffer, Pointer<AudioEffects> effects);

typedef AnalyzeSpectrumFunc = Pointer<SpectrumData> Function(
    Pointer<AudioBuffer> buffer);
typedef AnalyzeSpectrum = Pointer<SpectrumData> Function(
    Pointer<AudioBuffer> buffer);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AudioProcessingPage(),
    );
  }
}

class AudioProcessingPage extends StatefulWidget {
  @override
  _AudioProcessingPageState createState() => _AudioProcessingPageState();
}

class _AudioProcessingPageState extends State<AudioProcessingPage> {
  late final DynamicLibrary _lib;
  late final ProcessAudioBuffer _processAudioBuffer;
  late final AnalyzeSpectrum _analyzeSpectrum;
  final _audioCapture = FlutterAudioCapture();
  
  bool _isRecording = false;
  double _gain = 1.0;
  double _echoDelay = 0.0;
  double _echoIntensity = 0.0;
  double _lowPass = 0.0;
  
  List<FlSpot> _spectrumPoints = [];

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  void _loadLibrary() {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libcalculator.so')
        : throw UnsupportedError('Unsupported platform');

    _processAudioBuffer = _lib
        .lookupFunction<ProcessAudioBufferFunc, ProcessAudioBuffer>(
            'ProcessAudioBuffer');
    _analyzeSpectrum = _lib
        .lookupFunction<AnalyzeSpectrumFunc, AnalyzeSpectrum>(
            'AnalyzeSpectrum');
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _audioCapture.stop();
    } else {
      await _audioCapture.start(_onAudioData, (){});
    }
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  void _onAudioData(dynamic data) {
    if (data is List<double>) {
      final buffer = _createAudioBuffer(data);
      final effects = _createAudioEffects();

      try {
        // Process audio
        final processedBuffer = _processAudioBuffer(buffer, effects);
        
        // Analyze spectrum
        final spectrum = _analyzeSpectrum(processedBuffer);
        
        // Update spectrum visualization
        if (mounted) {
          setState(() {
            _updateSpectrumVisualization(spectrum);
          });
        }
      } finally {
        calloc.free(buffer);
        calloc.free(effects);
      }
    }
  }

  Pointer<AudioBuffer> _createAudioBuffer(List<double> data) {
    final buffer = calloc<AudioBuffer>();
    buffer.ref.length = data.length;
    buffer.ref.data = calloc<Float>(data.length);
    
    final floatData = buffer.ref.data.asTypedList(data.length);
    for (var i = 0; i < data.length; i++) {
      floatData[i] = data[i].toDouble();
    }
    
    return buffer;
  }

  Pointer<AudioEffects> _createAudioEffects() {
    final effects = calloc<AudioEffects>();
    effects.ref.gain = _gain;
    effects.ref.echoDelay = _echoDelay;
    effects.ref.echoIntensity = _echoIntensity;
    effects.ref.lowPass = _lowPass;
    effects.ref.highPass = 0.0;
    return effects;
  }

  void _updateSpectrumVisualization(Pointer<SpectrumData> spectrum) {
    final length = spectrum.ref.length;
    final frequencies = spectrum.ref.frequencies.asTypedList(length);
    final magnitudes = spectrum.ref.magnitudes.asTypedList(length);

    _spectrumPoints = List.generate(length, (i) {
      return FlSpot(frequencies[i], magnitudes[i]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Processing')),
      body: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(spots: _spectrumPoints),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${(value/1000).toStringAsFixed(1)}kHz');
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildSlider('Gain', _gain, 0.0, 2.0),
                _buildSlider('Echo Delay', _echoDelay, 0.0, 1.0),
                _buildSlider('Echo Intensity', _echoIntensity, 0.0, 1.0),
                _buildSlider('Low Pass Filter', _lowPass, 0.0, 1.0),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleRecording,
        child: Icon(_isRecording ? Icons.stop : Icons.mic),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max) {
    return Column(
      children: [
        Text(label),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (newValue) {
            setState(() {
              switch (label) {
                case 'Gain':
                  _gain = newValue;
                  break;
                case 'Echo Delay':
                  _echoDelay = newValue;
                  break;
                case 'Echo Intensity':
                  _echoIntensity = newValue;
                  break;
                case 'Low Pass Filter':
                  _lowPass = newValue;
                  break;
              }
            });
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _audioCapture.stop();
    super.dispose();
  }
}