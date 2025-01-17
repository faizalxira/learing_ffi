import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';

// FFI signatures
typedef ReverseStringFunc = Pointer<Utf8> Function(Pointer<Utf8>);
typedef ReverseString = Pointer<Utf8> Function(Pointer<Utf8>);

typedef CountWordsFunc = Int32 Function(Pointer<Utf8>);
typedef CountWords = int Function(Pointer<Utf8>);

typedef FreeFunc = Void Function(Pointer<Void>);
typedef Free = void Function(Pointer<Void>);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final DynamicLibrary _lib;
  late final ReverseString _reverseString;
  late final CountWords _countWords;
  late final Free _free;
  
  final TextEditingController _controller = TextEditingController();
  String _reversedText = '';
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libcalculator.so')
        : throw UnsupportedError('Unsupported platform');

    _reverseString = _lib.lookupFunction<ReverseStringFunc, ReverseString>('ReverseString');
    _countWords = _lib.lookupFunction<CountWordsFunc, CountWords>('CountWords');
    _free = _lib.lookupFunction<FreeFunc, Free>('Free');
  }

  void _processText() {
    final text = _controller.text;
    final inputPtr = text.toNativeUtf8();
    
    try {
      final resultPtr = _reverseString(inputPtr);
      setState(() {
        _reversedText = resultPtr.toDartString();
        _wordCount = _countWords(inputPtr);
      });
      _free(resultPtr.cast());
    } finally {
      calloc.free(inputPtr);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter + Golang Text Processor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter text',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _processText,
              child: Text('Process Text'),
            ),
            SizedBox(height: 16),
            Text('Reversed text: $_reversedText'),
            Text('Word count: $_wordCount'),
          ],
        ),
      ),
    );
  }
}