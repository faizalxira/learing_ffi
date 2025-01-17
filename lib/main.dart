import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

// FFI structs
base class ImageData extends Struct {
  external Pointer<Uint8> data;
  @Int32()
  external int width;
  @Int32()
  external int height;
  @Int32()
  external int channels;
}

// FFI signatures
typedef ApplyFilterFunc = Pointer<ImageData> Function(Pointer<ImageData>);
typedef ApplyFilter = Pointer<ImageData> Function(Pointer<ImageData>);

typedef FreeImageDataFunc = Void Function(Pointer<ImageData>);
typedef FreeImageData = void Function(Pointer<ImageData>);

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ImageProcessingPage(),
    );
  }
}

class ImageProcessingPage extends StatefulWidget {
  const ImageProcessingPage({Key? key}) : super(key: key);

  @override
  _ImageProcessingPageState createState() => _ImageProcessingPageState();
}

class _ImageProcessingPageState extends State<ImageProcessingPage> {
  late final DynamicLibrary _lib;
  late final ApplyFilter _applyGrayscale;
  late final ApplyFilter _applySepia;
  late final FreeImageData _freeImageData;
  
  Uint8List? _originalImageBytes;
  Uint8List? _processedImageBytes;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libcalculator.so')
        : throw UnsupportedError('Unsupported platform');

    _applyGrayscale = _lib.lookupFunction<ApplyFilterFunc, ApplyFilter>('ApplyGrayscale');
    _applySepia = _lib.lookupFunction<ApplyFilterFunc, ApplyFilter>('ApplySepia');
    _freeImageData = _lib.lookupFunction<FreeImageDataFunc, FreeImageData>('FreeImageData');
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _originalImageBytes = bytes;
        _processedImageBytes = null;
      });
    }
  }
  
Future<void> _processImage(bool isGrayscale) async {
    try {
      if (_originalImageBytes == null) return;

      final decodedImage = img.decodeImage(_originalImageBytes!);
      if (decodedImage == null) return;

      // Ensure image is in RGBA format
      final rgbaImage = decodedImage.convert(numChannels: 4);
      final pixels = rgbaImage.getBytes();
      
      // Allocate input data
      final inputData = calloc<ImageData>();
      final pixelPointer = calloc<Uint8>(pixels.length);
      
      try {
        // Copy image data
        final pixelList = pixelPointer.asTypedList(pixels.length);
        for (var i = 0; i < pixels.length; i++) {
          pixelList[i] = pixels[i];
        }

        // Setup input structure
        inputData.ref.data = pixelPointer;
        inputData.ref.width = rgbaImage.width;
        inputData.ref.height = rgbaImage.height;
        inputData.ref.channels = 4;

        // Process image
        final outputData = isGrayscale
            ? _applyGrayscale(inputData)
            : _applySepia(inputData);

        if (outputData == nullptr) {
          throw Exception('Image processing failed');
        }

        // Copy processed data
        final outputLength = outputData.ref.width * 
                           outputData.ref.height * 
                           outputData.ref.channels;
        final outputBytes = outputData.ref.data.asTypedList(outputLength);

        final processedImage = img.Image.fromBytes(
          width: outputData.ref.width,
          height: outputData.ref.height,
          // bytes: Uint8List.fromList(outputBytes.toList()),
          bytes: Uint8List.fromList(outputBytes.toList()).buffer,
          numChannels: outputData.ref.channels,
        );

        setState(() {
          _processedImageBytes = img.encodeJpg(processedImage);
        });

        // Cleanup
        _freeImageData(outputData);
      } finally {
        calloc.free(pixelPointer);
        calloc.free(inputData);
      }
    } catch (e, stackTrace) {
      print('Error processing image: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e')),
        );
      }
    }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Processing with Go')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_originalImageBytes != null) ...[
              Image.memory(_originalImageBytes!),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _processImage(true),
                    child: const Text('Grayscale'),
                  ),
                  ElevatedButton(
                    onPressed: () => _processImage(false),
                    child: const Text('Sepia'),
                  ),
                ],
              ),
            ],
            if (_processedImageBytes != null) ...[
              const SizedBox(height: 16),
              Image.memory(_processedImageBytes!),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }
}