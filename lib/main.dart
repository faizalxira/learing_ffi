import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';

// FFI signature for the Add function
typedef AddFunc = Int32 Function(Int32 a, Int32 b);
typedef Add = int Function(int a, int b);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final DynamicLibrary calculatorLib;
  late final Add add;
  int result = 0;

  @override
  void initState() {
    super.initState();
    // Load the dynamic library
    calculatorLib = Platform.isAndroid
        ? DynamicLibrary.open("libcalculator.so")
        : throw UnsupportedError('Unsupported platform');
    
    // Look up the Add function
    add = calculatorLib
        .lookupFunction<AddFunc, Add>('Add');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter + Golang FFI Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Result: $result'),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  result = add(5, 3);
                });
              },
              child: Text('Calculate 5 + 3'),
            ),
          ],
        ),
      ),
    );
  }
}