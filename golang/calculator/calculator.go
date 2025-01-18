package main

/*
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

typedef struct {
    float x;
    float y;
} Vector2;

typedef struct {
    Vector2 position;
    Vector2 oldPosition;
    Vector2 velocity;
    float mass;
    int32_t isFixed;
} RopePoint;

typedef struct {
    RopePoint* points;
    int32_t pointCount;
    float segmentLength;
    float stiffness;
    float damping;
} RopeSystem;

typedef struct {
    float gravity;
    float windForce;
    float airResistance;
} PhysicsParams;
*/
import "C"
import (
	"math"
	"unsafe"
)

//export CreateRopeSystem
func CreateRopeSystem(pointCount C.int32_t, length C.float) *C.RopeSystem {
	rope := (*C.RopeSystem)(C.malloc(C.size_t(unsafe.Sizeof(C.RopeSystem{}))))
	rope.points = (*C.RopePoint)(C.malloc(C.size_t(unsafe.Sizeof(C.RopePoint{}) * uintptr(pointCount))))
	rope.pointCount = pointCount
	rope.segmentLength = length / C.float(pointCount-1)
	rope.stiffness = 0.5
	rope.damping = 0.98

	points := unsafe.Slice(rope.points, pointCount)
	for i := range points {
		points[i].position.x = C.float(i) * rope.segmentLength
		points[i].position.y = 0
		points[i].oldPosition = points[i].position
		points[i].velocity.x = 0
		points[i].velocity.y = 0
		points[i].mass = 1.0
		points[i].isFixed = 0
	}

	// Fix the first point
	points[0].isFixed = 1

	return rope
}

//export UpdateRopePhysics
func UpdateRopePhysics(rope *C.RopeSystem, params *C.PhysicsParams, deltaTime C.float) {
	if rope == nil || rope.points == nil {
		return
	}

	points := unsafe.Slice(rope.points, rope.pointCount)
	dt := C.float(deltaTime)

	// Verlet integration
	for i := range points {
		if points[i].isFixed == 1 {
			continue
		}

		// Save current position
		tempX := points[i].position.x
		tempY := points[i].position.y

		// Apply forces
		points[i].velocity.x += params.windForce * dt
		points[i].velocity.y += params.gravity * dt

		// Apply air resistance
		points[i].velocity.x *= (1.0 - params.airResistance)
		points[i].velocity.y *= (1.0 - params.airResistance)

		// Update position using Verlet integration
		points[i].position.x += points[i].velocity.x * dt
		points[i].position.y += points[i].velocity.y * dt

		// Update old position
		points[i].oldPosition.x = tempX
		points[i].oldPosition.y = tempY
	}

	// Satisfy constraints (multiple iterations for stability)
	for iter := 0; iter < 3; iter++ {
		for i := 1; i < len(points); i++ {
			p1 := &points[i-1]
			p2 := &points[i]

			// Calculate distance between points
			dx := p2.position.x - p1.position.x
			dy := p2.position.y - p1.position.y
			distance := C.float(math.Sqrt(float64(dx*dx + dy*dy)))

			// Calculate difference from desired length
			diff := (distance - rope.segmentLength) / distance

			// Apply correction based on stiffness
			if p1.isFixed == 0 {
				p1.position.x += dx * diff * rope.stiffness * 0.5
				p1.position.y += dy * diff * rope.stiffness * 0.5
			}
			if p2.isFixed == 0 {
				p2.position.x -= dx * diff * rope.stiffness * 0.5
				p2.position.y -= dy * diff * rope.stiffness * 0.5
			}
		}
	}

	// Update velocities
	for i := range points {
		if points[i].isFixed == 1 {
			continue
		}

		points[i].velocity.x = (points[i].position.x - points[i].oldPosition.x) / dt
		points[i].velocity.y = (points[i].position.y - points[i].oldPosition.y) / dt

		// Apply damping
		points[i].velocity.x *= rope.damping
		points[i].velocity.y *= rope.damping
	}
}

//export DestroyRopeSystem
func DestroyRopeSystem(rope *C.RopeSystem) {
	if rope != nil {
		C.free(unsafe.Pointer(rope.points))
		C.free(unsafe.Pointer(rope))
	}
}

func main() {}
