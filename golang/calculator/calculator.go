package main

/*
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

typedef struct {
    float x;
    float y;
    float z;
} Vector3;

typedef struct {
    Vector3 position;
    Vector3 velocity;
    Vector3 acceleration;
    float mass;
    float lifetime;
    float age;
} Particle;

typedef struct {
    Particle* particles;
    int32_t count;
} ParticleSystem;

typedef struct {
    float gravity;
    float wind_x;
    float wind_y;
    float wind_z;
    float damping;
} PhysicsParams;
*/
import "C"
import (
	"math"
	"math/rand"
	"unsafe"
)

//export InitializeParticleSystem
func InitializeParticleSystem(count C.int32_t) *C.ParticleSystem {
	system := (*C.ParticleSystem)(C.malloc(C.size_t(unsafe.Sizeof(C.ParticleSystem{}))))
	system.particles = (*C.Particle)(C.malloc(C.size_t(unsafe.Sizeof(C.Particle{}) * uintptr(count))))
	system.count = count

	particles := unsafe.Slice(system.particles, count)
	for i := range particles {
		initializeParticle(&particles[i], true)
	}

	return system
}

func initializeParticle(p *C.Particle, randomPosition bool) {
	if randomPosition {
		p.position.x = C.float(rand.Float64()*2 - 1) // -1 to 1
		p.position.y = C.float(rand.Float64()*2 - 1)
		p.position.z = C.float(rand.Float64()*2 - 1)
	}

	// Random initial velocity
	speed := rand.Float64() * 2
	angle := rand.Float64() * 2 * math.Pi
	elevation := rand.Float64() * math.Pi

	p.velocity.x = C.float(speed * math.Cos(angle) * math.Cos(elevation))
	p.velocity.y = C.float(speed * math.Sin(elevation))
	p.velocity.z = C.float(speed * math.Sin(angle) * math.Cos(elevation))

	p.acceleration.x = 0
	p.acceleration.y = 0
	p.acceleration.z = 0

	p.mass = C.float(rand.Float64()*0.5 + 0.5)
	p.lifetime = C.float(rand.Float64()*2 + 3)
	p.age = 0
}

//export UpdateParticleSystem
func UpdateParticleSystem(system *C.ParticleSystem, params *C.PhysicsParams, deltaTime C.float) {
	if system == nil || system.particles == nil {
		return
	}

	particles := unsafe.Slice(system.particles, system.count)
	dt := C.float(deltaTime) // Keep as C.float

	for i := range particles {
		p := &particles[i]

		// Update age
		p.age += deltaTime
		if p.age >= p.lifetime {
			initializeParticle(p, false)
			p.position.y = -1 // Start from bottom
			continue
		}

		// Apply forces
		p.acceleration.x = params.wind_x / p.mass
		p.acceleration.y = -params.gravity + params.wind_y/p.mass
		p.acceleration.z = params.wind_z / p.mass

		// Update velocity with acceleration (using C.float for all operations)
		p.velocity.x += p.acceleration.x * dt
		p.velocity.y += p.acceleration.y * dt
		p.velocity.z += p.acceleration.z * dt

		// Apply damping (convert damping to C.float)
		damping := C.float(1.0 - float64(params.damping))
		p.velocity.x *= damping
		p.velocity.y *= damping
		p.velocity.z *= damping

		// Update position
		p.position.x += p.velocity.x * dt
		p.position.y += p.velocity.y * dt
		p.position.z += p.velocity.z * dt

		// Boundary conditions
		if p.position.y < -1 {
			p.position.y = -1
			p.velocity.y = -p.velocity.y * C.float(0.5) // Convert 0.5 to C.float
		}
	}
}

//export DeleteParticleSystem
func DeleteParticleSystem(system *C.ParticleSystem) {
	if system != nil {
		C.free(unsafe.Pointer(system.particles))
		C.free(unsafe.Pointer(system))
	}
}

func main() {}
