package main

/*
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

typedef struct {
    float* data;
    int32_t length;
} AudioBuffer;

typedef struct {
    float gain;
    float echo_delay;
    float echo_intensity;
    float low_pass;
    float high_pass;
} AudioEffects;

typedef struct {
    float* frequencies;
    float* magnitudes;
    int32_t length;
} SpectrumData;
*/
import "C"
import (
	"math"
	"math/cmplx"
	"unsafe"
)

//export ProcessAudioBuffer
func ProcessAudioBuffer(buffer *C.AudioBuffer, effects *C.AudioEffects) *C.AudioBuffer {
	if buffer == nil || buffer.data == nil {
		return nil
	}

	length := int(buffer.length)
	output := (*C.AudioBuffer)(C.malloc(C.size_t(unsafe.Sizeof(C.AudioBuffer{}))))
	output.data = (*C.float)(C.malloc(C.size_t(unsafe.Sizeof(C.float(0)) * uintptr(length))))
	output.length = buffer.length

	inputSlice := (*[1 << 30]float32)(unsafe.Pointer(buffer.data))[:length:length]
	outputSlice := (*[1 << 30]float32)(unsafe.Pointer(output.data))[:length:length]

	// Apply gain
	gain := float32(effects.gain)
	for i := 0; i < length; i++ {
		outputSlice[i] = inputSlice[i] * gain
	}

	// Apply echo
	if effects.echo_delay > 0 {
		delaySamples := int(effects.echo_delay * 44100) // Assuming 44.1kHz sample rate
		intensity := float32(effects.echo_intensity)

		for i := delaySamples; i < length; i++ {
			outputSlice[i] += inputSlice[i-delaySamples] * intensity
		}
	}

	// Apply low-pass filter
	if effects.low_pass > 0 {
		alpha := float32(effects.low_pass)
		outputSlice[0] = inputSlice[0]
		for i := 1; i < length; i++ {
			outputSlice[i] = alpha*outputSlice[i-1] + (1-alpha)*inputSlice[i]
		}
	}

	return output
}

//export AnalyzeSpectrum
func AnalyzeSpectrum(buffer *C.AudioBuffer) *C.SpectrumData {
	length := int(buffer.length)
	fftSize := nextPowerOf2(length)

	// Prepare FFT input
	input := make([]complex128, fftSize)
	inputSlice := (*[1 << 30]float32)(unsafe.Pointer(buffer.data))[:length:length]

	// Apply Hanning window
	for i := 0; i < length; i++ {
		window := 0.5 * (1 - math.Cos(2*math.Pi*float64(i)/float64(length-1)))
		input[i] = complex(float64(inputSlice[i])*window, 0)
	}

	// Perform FFT
	output := fft(input)

	// Create spectrum data
	spectrum := (*C.SpectrumData)(C.malloc(C.size_t(unsafe.Sizeof(C.SpectrumData{}))))
	binCount := fftSize/2 + 1
	spectrum.frequencies = (*C.float)(C.malloc(C.size_t(unsafe.Sizeof(C.float(0)) * uintptr(binCount))))
	spectrum.magnitudes = (*C.float)(C.malloc(C.size_t(unsafe.Sizeof(C.float(0)) * uintptr(binCount))))
	spectrum.length = C.int32_t(binCount)

	freqSlice := (*[1 << 30]float32)(unsafe.Pointer(spectrum.frequencies))[:binCount:binCount]
	magSlice := (*[1 << 30]float32)(unsafe.Pointer(spectrum.magnitudes))[:binCount:binCount]

	// Calculate frequencies and magnitudes
	for i := 0; i < binCount; i++ {
		freqSlice[i] = float32(i) * 44100 / float32(fftSize) // Assuming 44.1kHz sample rate
		magSlice[i] = float32(cmplx.Abs(output[i]))
	}

	return spectrum
}

func nextPowerOf2(n int) int {
	p := 1
	for p < n {
		p *= 2
	}
	return p
}

func fft(input []complex128) []complex128 {
	n := len(input)
	if n <= 1 {
		return input
	}

	even := make([]complex128, n/2)
	odd := make([]complex128, n/2)
	for i := 0; i < n/2; i++ {
		even[i] = input[2*i]
		odd[i] = input[2*i+1]
	}

	evenFFT := fft(even)
	oddFFT := fft(odd)

	result := make([]complex128, n)
	for k := 0; k < n/2; k++ {
		phase := complex(0, -2*math.Pi*float64(k)/float64(n))
		t := cmplx.Exp(phase) * oddFFT[k]
		result[k] = evenFFT[k] + t
		result[k+n/2] = evenFFT[k] - t
	}

	return result
}

func main() {}
