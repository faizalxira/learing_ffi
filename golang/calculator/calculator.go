package main

/*
#include <stdlib.h>
#include <stdint.h>

typedef struct Vec2 {
    float x;
    float y;
} Vec2;

typedef struct FluidParticle {
    Vec2 position;
    Vec2 velocity;
    Vec2 force;
    float density;
    float pressure;
    float mass;
} FluidParticle;

typedef struct FluidSystem {
    FluidParticle* particles;
    int32_t count;
    float h;  // smoothing length
    float k;  // gas constant
    float mu; // viscosity
    float rest_density;
    float boundary_damping;
    Vec2 gravity;
    Vec2 bounds;
} FluidSystem;
*/
import "C"

import (
	"math"
	"unsafe"
)

const (
	POLY6      = 315.0 / (64.0 * math.Pi)
	SPIKY_GRAD = -45.0 / math.Pi
	VISC_LAP   = 45.0 / math.Pi
)

//export CreateFluidSystem
func CreateFluidSystem(count C.int32_t, width, height C.float) *C.FluidSystem {
	system := (*C.FluidSystem)(C.malloc(C.size_t(unsafe.Sizeof(C.FluidSystem{}))))
	system.particles = (*C.FluidParticle)(C.malloc(C.size_t(unsafe.Sizeof(C.FluidParticle{}) * uintptr(count))))
	system.count = count
	system.h = 16.0
	system.k = 0.04
	system.mu = 0.1
	system.rest_density = 1000.0
	system.boundary_damping = 0.5
	system.gravity.x = 0
	system.gravity.y = 9.81 * 100
	system.bounds.x = width
	system.bounds.y = height

	// Initialize particles in a grid
	particles := unsafe.Slice(system.particles, count)
	particlesPerRow := int(math.Sqrt(float64(count)))
	spacing := float64(system.h) / 2.0

	for i := range particles {
		row := i / particlesPerRow
		col := i % particlesPerRow
		particles[i].position.x = C.float(float64(col)*spacing + 50)
		particles[i].position.y = C.float(float64(row)*spacing + 50)
		particles[i].velocity.x = 0
		particles[i].velocity.y = 0
		particles[i].force.x = 0
		particles[i].force.y = 0
		particles[i].density = 0
		particles[i].pressure = 0
		particles[i].mass = 1.0
	}

	return system
}

//export UpdateFluidSystem
func UpdateFluidSystem(system *C.FluidSystem, deltaTime C.float) {
	if system == nil || system.particles == nil {
		return
	}

	particles := unsafe.Slice(system.particles, system.count)
	h2 := float64(system.h * system.h)

	// Compute density and pressure
	for i := range particles {
		particles[i].density = 0
		for j := range particles {
			dx := float64(particles[j].position.x - particles[i].position.x)
			dy := float64(particles[j].position.y - particles[i].position.y)
			r2 := dx*dx + dy*dy

			if r2 < h2 {
				particles[i].density = C.float(float64(particles[i].density) +
					float64(particles[j].mass)*POLY6*math.Pow(h2-r2, 3))
			}
		}
		particles[i].pressure = C.float(float64(system.k) *
			(float64(particles[i].density) - float64(system.rest_density)))
	}

	// Compute forces
	for i := range particles {
		fx, fy := 0.0, 0.0

		for j := range particles {
			if i == j {
				continue
			}

			dx := float64(particles[j].position.x - particles[i].position.x)
			dy := float64(particles[j].position.y - particles[i].position.y)
			r := math.Sqrt(dx*dx + dy*dy)

			if r < float64(system.h) {
				// Pressure force
				pressure := float64(particles[i].pressure+particles[j].pressure) /
					(2.0 * float64(particles[j].density))
				factor := SPIKY_GRAD * math.Pow(float64(system.h)-r, 2) * pressure
				fx += dx / r * factor
				fy += dy / r * factor

				// Viscosity force
				dvx := float64(particles[j].velocity.x - particles[i].velocity.x)
				dvy := float64(particles[j].velocity.y - particles[i].velocity.y)
				visc := float64(system.mu) * (float64(system.h) - r) /
					float64(particles[j].density)
				fx += dvx * visc * VISC_LAP
				fy += dvy * visc * VISC_LAP
			}
		}

		// Add gravity
		fx += float64(system.gravity.x)
		fy += float64(system.gravity.y)

		particles[i].force.x = C.float(fx)
		particles[i].force.y = C.float(fy)
	}

	// Update positions
	dt := float64(deltaTime)
	for i := range particles {
		// Update velocity
		particles[i].velocity.x += C.float(float64(particles[i].force.x) * dt)
		particles[i].velocity.y += C.float(float64(particles[i].force.y) * dt)

		// Update position
		particles[i].position.x += particles[i].velocity.x * deltaTime
		particles[i].position.y += particles[i].velocity.y * deltaTime

		// Boundary conditions
		if particles[i].position.x < 0 {
			particles[i].velocity.x *= -system.boundary_damping
			particles[i].position.x = 0
		}
		if particles[i].position.x > system.bounds.x {
			particles[i].velocity.x *= -system.boundary_damping
			particles[i].position.x = system.bounds.x
		}
		if particles[i].position.y < 0 {
			particles[i].velocity.y *= -system.boundary_damping
			particles[i].position.y = 0
		}
		if particles[i].position.y > system.bounds.y {
			particles[i].velocity.y *= -system.boundary_damping
			particles[i].position.y = system.bounds.y
		}
	}
}

//export DestroyFluidSystem
func DestroyFluidSystem(system *C.FluidSystem) {
	if system != nil {
		C.free(unsafe.Pointer(system.particles))
		C.free(unsafe.Pointer(system))
	}
}

func main() {}
