import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vector;

base class Vector3 extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double z;
}

base class Particle extends Struct {
  external Vector3 position;
  external Vector3 velocity;
  external Vector3 acceleration;
  @Float()
  external double mass;
  @Float()
  external double lifetime;
  @Float()
  external double age;
}

base class ParticleSystem extends Struct {
  external Pointer<Particle> particles;
  @Int32()
  external int count;
}

base class PhysicsParams extends Struct {
  @Float()
  external double gravity;
  @Float()
  external double windX;
  @Float()
  external double windY;
  @Float()
  external double windZ;
  @Float()
  external double damping;
}

typedef InitializeParticleSystemFunc = Pointer<ParticleSystem> Function(Int32 count);
typedef InitializeParticleSystem = Pointer<ParticleSystem> Function(int count);

typedef UpdateParticleSystemFunc = Void Function(
    Pointer<ParticleSystem> system, Pointer<PhysicsParams> params, Float deltaTime);
typedef UpdateParticleSystem = void Function(
    Pointer<ParticleSystem> system, Pointer<PhysicsParams> params, double deltaTime);

typedef DeleteParticleSystemFunc = Void Function(Pointer<ParticleSystem> system);
typedef DeleteParticleSystem = void Function(Pointer<ParticleSystem> system);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Particle System Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ParticleSystemDemo(),
    );
  }
}

class ParticleSystemDemo extends StatefulWidget {
  const ParticleSystemDemo({Key? key}) : super(key: key);

  @override
  _ParticleSystemDemoState createState() => _ParticleSystemDemoState();
}

class _ParticleSystemDemoState extends State<ParticleSystemDemo>
    with SingleTickerProviderStateMixin {
  late final DynamicLibrary _lib;
  late final InitializeParticleSystem _initializeParticleSystem;
  late final UpdateParticleSystem _updateParticleSystem;
  late final DeleteParticleSystem _deleteParticleSystem;
  late final Pointer<ParticleSystem> _particleSystem;
  late final Pointer<PhysicsParams> _physicsParams;
  late final AnimationController _controller;

  double _gravity = 9.81;
  double _windX = 0.0;
  double _windY = 0.0;
  double _windZ = 0.0;
  double _damping = 0.1;
  vector.Vector3 _cameraRotation = vector.Vector3.zero();

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

    _initializeParticleSystem = _lib.lookupFunction<
        InitializeParticleSystemFunc,
        InitializeParticleSystem>('InitializeParticleSystem');
    _updateParticleSystem = _lib.lookupFunction<UpdateParticleSystemFunc,
        UpdateParticleSystem>('UpdateParticleSystem');
    _deleteParticleSystem = _lib.lookupFunction<DeleteParticleSystemFunc,
        DeleteParticleSystem>('DeleteParticleSystem');
  }

  void _initializePhysics() {
    _particleSystem = _initializeParticleSystem(1000);
    _physicsParams = calloc<PhysicsParams>();
    _updatePhysicsParams();
  }

  void _updatePhysicsParams() {
    _physicsParams.ref.gravity = _gravity;
    _physicsParams.ref.windX = _windX;
    _physicsParams.ref.windY = _windY;
    _physicsParams.ref.windZ = _windZ;
    _physicsParams.ref.damping = _damping;
  }

  void _setupAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(() {
      _updateParticleSystem(_particleSystem, _physicsParams, 1 / 60);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Particle System')),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _cameraRotation.x += details.delta.dy * 0.01;
                  _cameraRotation.y += details.delta.dx * 0.01;
                });
              },
              child: CustomPaint(
                painter: ParticleSystemPainter(
                  _particleSystem,
                  _cameraRotation,
                ),
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
          _buildSlider('Wind X', _windX, -10, 10, (v) => _windX = v),
          _buildSlider('Wind Y', _windY, -10, 10, (v) => _windY = v),
          _buildSlider('Wind Z', _windZ, -10, 10, (v) => _windZ = v),
          _buildSlider('Damping', _damping, 0, 1, (v) => _damping = v),
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
    _deleteParticleSystem(_particleSystem);
    calloc.free(_physicsParams);
    super.dispose();
  }
}

class ParticleSystemPainter extends CustomPainter {
  final Pointer<ParticleSystem> system;
  final vector.Vector3 cameraRotation;

  ParticleSystemPainter(this.system, this.cameraRotation);

  @override
  void paint(Canvas canvas, ui.Size size) {
    final paint = Paint()..color = Colors.blue;
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.height / 2;

    final rotationMatrix = vector.Matrix4.identity()
      ..rotateX(cameraRotation.x)
      ..rotateY(cameraRotation.y);

    for (var i = 0; i < system.ref.count; i++) {
      final particle = system.ref.particles[i];
      final pos = vector.Vector3(
        particle.position.x.toDouble(),
        particle.position.y.toDouble(),
        particle.position.z.toDouble(),
      );

      final transformed = rotationMatrix.transformed3(pos);
      final screenPos = Offset(
        center.dx + transformed.x * scale,
        center.dy + transformed.y * scale,
      );

      final opacity = (1 - particle.age / particle.lifetime).clamp(0.0, 1.0);
      paint.color = Colors.blue.withOpacity(opacity);
      
      canvas.drawCircle(screenPos, particle.mass * 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}