import 'dart:ffi';
import 'dart:ui'as ui;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

base class Vector2 extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
}

base class RopePoint extends Struct {
  external Vector2 position;
  external Vector2 oldPosition;
  external Vector2 velocity;
  @Float()
  external double mass;
  @Int32()
  external int isFixed;
}

base class RopeSystem extends Struct {
  external Pointer<RopePoint> points;
  @Int32()
  external int pointCount;
  @Float()
  external double segmentLength;
  @Float()
  external double stiffness;
  @Float()
  external double damping;
}

base class PhysicsParams extends Struct {
  @Float()
  external double gravity;
  @Float()
  external double windForce;
  @Float()
  external double airResistance;
}

typedef CreateRopeSystemFunc = Pointer<RopeSystem> Function(Int32 pointCount, Float length);
typedef CreateRopeSystem = Pointer<RopeSystem> Function(int pointCount, double length);

typedef UpdateRopePhysicsFunc = Void Function(
    Pointer<RopeSystem> rope, Pointer<PhysicsParams> params, Float deltaTime);
typedef UpdateRopePhysics = void Function(
    Pointer<RopeSystem> rope, Pointer<PhysicsParams> params, double deltaTime);

typedef DestroyRopeSystemFunc = Void Function(Pointer<RopeSystem> rope);
typedef DestroyRopeSystem = void Function(Pointer<RopeSystem> rope);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rope Physics Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RopeSimulation(),
    );
  }
}

class RopeSimulation extends StatefulWidget {
  const RopeSimulation({Key? key}) : super(key: key);

  @override
  _RopeSimulationState createState() => _RopeSimulationState();
}

class _RopeSimulationState extends State<RopeSimulation>
    with SingleTickerProviderStateMixin {
  late final DynamicLibrary _lib;
  late final CreateRopeSystem _createRopeSystem;
  late final UpdateRopePhysics _updateRopePhysics;
  late final DestroyRopeSystem _destroyRopeSystem;
  late final Pointer<RopeSystem> _ropeSystem;
  late final Pointer<PhysicsParams> _physicsParams;
  late final AnimationController _controller;

  double _gravity = 9.81;
  double _windForce = 0.0;
  double _airResistance = 0.01;
  Offset _anchorPoint = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _initializePhysics();
    _setupAnimation();
  }

  void _loadLibrary() {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libcalculator.so')
        : throw UnsupportedError('Unsupported platform');

    _createRopeSystem = _lib
        .lookupFunction<CreateRopeSystemFunc, CreateRopeSystem>('CreateRopeSystem');
    _updateRopePhysics = _lib
        .lookupFunction<UpdateRopePhysicsFunc, UpdateRopePhysics>('UpdateRopePhysics');
    _destroyRopeSystem = _lib
        .lookupFunction<DestroyRopeSystemFunc, DestroyRopeSystem>('DestroyRopeSystem');
  }

  void _initializePhysics() {
    _ropeSystem = _createRopeSystem(20, 300.0); // 20 points, 300 pixels long
    _physicsParams = calloc<PhysicsParams>();
    _updatePhysicsParams();
  }

  void _updatePhysicsParams() {
    _physicsParams.ref.gravity = _gravity;
    _physicsParams.ref.windForce = _windForce;
    _physicsParams.ref.airResistance = _airResistance;
  }

  void _setupAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(() {
      _updateRopePhysics(_ropeSystem, _physicsParams, 1 / 60);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rope Physics Simulation')),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanStart: (details) {
                _isDragging = true;
                _anchorPoint = details.localPosition;
                setState(() {
                  _ropeSystem.ref.points.ref.position.x = _anchorPoint.dx;
                  _ropeSystem.ref.points.ref.position.y = _anchorPoint.dy;
                });
              },
              onPanUpdate: (details) {
                if (_isDragging) {
                  _anchorPoint = details.localPosition;
                  setState(() {
                    _ropeSystem.ref.points.ref.position.x = _anchorPoint.dx;
                    _ropeSystem.ref.points.ref.position.y = _anchorPoint.dy;
                  });
                }
              },
              onPanEnd: (details) {
                _isDragging = false;
              },
              child: CustomPaint(
                painter: RopePainter(_ropeSystem),
                size: ui.Size.infinite,
              ),
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSlider('Gravity', _gravity, 0, 20, (v) => _gravity = v),
          _buildSlider('Wind Force', _windForce, -10, 10, (v) => _windForce = v),
          _buildSlider('Air Resistance', _airResistance, 0, 0.1, (v) => _airResistance = v),
        ],
      ),
    );
  }

  Widget _buildSlider(
      String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Text(label),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: (v) {
              setState(() {
                onChanged(v);
                _updatePhysicsParams();
              });
            },
          ),
        ),
        Text(value.toStringAsFixed(2)),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _destroyRopeSystem(_ropeSystem);
    calloc.free(_physicsParams);
    super.dispose();
  }
}
class RopePainter extends CustomPainter {
  final Pointer<RopeSystem> rope;

  RopePainter(this.rope);

  @override
  void paint(Canvas canvas, ui.Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Convert the pointer to a Dart list by manually iterating through it
    final points = <RopePoint>[];
    for (var i = 0; i < rope.ref.pointCount; i++) {
      points.add(rope.ref.points.elementAt(i).ref);
    }

    // Draw the rope path
    if (points.isNotEmpty) {
      path.moveTo(points[0].position.x, points[0].position.y);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].position.x, points[i].position.y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw points
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.red;
    for (var point in points) {
      canvas.drawCircle(
        Offset(point.position.x, point.position.y),
        4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
