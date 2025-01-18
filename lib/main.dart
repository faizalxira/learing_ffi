import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

base class Vec2 extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
}

base class FluidParticle extends Struct {
  external Vec2 position;
  external Vec2 velocity;
  external Vec2 force;
  @Float()
  external double density;
  @Float()
  external double pressure;
  @Float()
  external double mass;
}

base class FluidSystem extends Struct {
  external Pointer<FluidParticle> particles;
  @Int32()
  external int count;
  @Float()
  external double h;
  @Float()
  external double k;
  @Float()
  external double mu;
  @Float()
  external double rest_density;
  @Float()
  external double boundary_damping;
  external Vec2 gravity;
  external Vec2 bounds;
}

typedef CreateFluidSystemFunc = Pointer<FluidSystem> Function(
    Int32 count, Float width, Float height);
typedef CreateFluidSystem = Pointer<FluidSystem> Function(
    int count, double width, double height);

typedef UpdateFluidSystemFunc = Void Function(
    Pointer<FluidSystem> system, Float deltaTime);
typedef UpdateFluidSystem = void Function(
    Pointer<FluidSystem> system, double deltaTime);

typedef DestroyFluidSystemFunc = Void Function(Pointer<FluidSystem> system);
typedef DestroyFluidSystem = void Function(Pointer<FluidSystem> system);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluid Simulation',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FluidSimulation(),
    );
  }
}

class FluidSimulation extends StatefulWidget {
  const FluidSimulation({Key? key}) : super(key: key);

  @override
  _FluidSimulationState createState() => _FluidSimulationState();
}

class _FluidSimulationState extends State<FluidSimulation>
    with SingleTickerProviderStateMixin {
  late final DynamicLibrary _lib;
  late final CreateFluidSystem _createFluidSystem;
  late final UpdateFluidSystem _updateFluidSystem;
  late final DestroyFluidSystem _destroyFluidSystem;
  late final Pointer<FluidSystem> _fluidSystem;
  late final AnimationController _controller;

  double _gravity = 9.81;
  double _viscosity = 0.1;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _setupAnimation();
  }

  void _loadLibrary() {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libcalculator.so')
        : throw UnsupportedError('Unsupported platform');

    _createFluidSystem = _lib
        .lookupFunction<CreateFluidSystemFunc, CreateFluidSystem>('CreateFluidSystem');
    _updateFluidSystem = _lib
        .lookupFunction<UpdateFluidSystemFunc, UpdateFluidSystem>('UpdateFluidSystem');
    _destroyFluidSystem = _lib
        .lookupFunction<DestroyFluidSystemFunc, DestroyFluidSystem>('DestroyFluidSystem');
  }

  void _setupAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _fluidSystem = _createFluidSystem(1000, size.width, size.height);
      _controller.addListener(() {
        if (!_paused) {
          _updateFluidSystem(_fluidSystem, 1 / 60);
          setState(() {});
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SPH Fluid Simulation')),
      body: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: FluidPainter(_fluidSystem),
              size: ui.Size.infinite,
            ),
          ),
          _buildControls(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _paused = !_paused),
        child: Icon(_paused ? Icons.play_arrow : Icons.pause),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSlider('Gravity', _gravity, 0, 20, (v) {
            setState(() {
              _gravity = v;
              _fluidSystem.ref.gravity.y = v * 100;
            });
          }),
          _buildSlider('Viscosity', _viscosity, 0, 1, (v) {
            setState(() {
              _viscosity = v;
              _fluidSystem.ref.mu = v;
            });
          }),
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
            onChanged: onChanged,
          ),
        ),
        Text(value.toStringAsFixed(2)),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _destroyFluidSystem(_fluidSystem);
    super.dispose();
  }
}

class FluidPainter extends CustomPainter {
  final Pointer<FluidSystem> system;

  FluidPainter(this.system);

  @override
  void paint(Canvas canvas, ui.Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final particleCount = system.ref.count;
    final particlesPointer = system.ref.particles;

    for (int i = 0; i < particleCount; i++) {
      // Access each FluidParticle by offsetting the pointer.
      final particle = particlesPointer.elementAt(i).ref;

      final pressure = particle.pressure / 1000;
      final color = HSLColor.fromAHSL(
        0.6,
        200 + pressure * 40,
        1.0,
        0.5,
      ).toColor();

      paint.color = color;
      canvas.drawCircle(
        Offset(particle.position.x, particle.position.y),
        8,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
