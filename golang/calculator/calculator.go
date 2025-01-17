package main

/*
#include <stdlib.h>
#include <stdint.h>

typedef struct {
    uint8_t* data;
    int32_t width;
    int32_t height;
    int32_t channels;
} ImageData;
*/
import "C"
import (
	"math"
	"unsafe"
)

func processImageSafely(img *C.ImageData, process func(r, g, b float64) (uint8, uint8, uint8)) *C.ImageData {
	if img == nil || img.data == nil || img.width <= 0 || img.height <= 0 || img.channels <= 0 {
		return nil
	}

	width := int(img.width)
	height := int(img.height)
	channels := int(img.channels)
	size := width * height * channels

	if size <= 0 || size > (1<<30) {
		return nil
	}

	// Allocate output buffer
	output := (*C.uint8_t)(C.malloc(C.size_t(size)))
	if output == nil {
		return nil
	}

	// Create safe slices
	inputSlice := (*[1 << 30]uint8)(unsafe.Pointer(img.data))[:size:size]
	outputSlice := (*[1 << 30]uint8)(unsafe.Pointer(output))[:size:size]

	// Process image
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			i := (y*width + x) * channels
			if i+2 >= size {
				continue
			}

			r := float64(inputSlice[i])
			g := float64(inputSlice[i+1])
			b := float64(inputSlice[i+2])

			outputR, outputG, outputB := process(r, g, b)

			outputSlice[i] = outputR
			outputSlice[i+1] = outputG
			outputSlice[i+2] = outputB

			if channels == 4 && i+3 < size {
				outputSlice[i+3] = inputSlice[i+3]
			}
		}
	}

	result := (*C.ImageData)(C.malloc(C.size_t(unsafe.Sizeof(C.ImageData{}))))
	if result == nil {
		C.free(unsafe.Pointer(output))
		return nil
	}

	result.data = output
	result.width = img.width
	result.height = img.height
	result.channels = img.channels
	return result
}

//export ApplyGrayscale
func ApplyGrayscale(img *C.ImageData) *C.ImageData {
	return processImageSafely(img, func(r, g, b float64) (uint8, uint8, uint8) {
		gray := uint8((r*0.299 + g*0.587 + b*0.114))
		return gray, gray, gray
	})
}

//export ApplySepia
func ApplySepia(img *C.ImageData) *C.ImageData {
	return processImageSafely(img, func(r, g, b float64) (uint8, uint8, uint8) {
		tr := uint8(math.Min(255, (r*0.393)+(g*0.769)+(b*0.189)))
		tg := uint8(math.Min(255, (r*0.349)+(g*0.686)+(b*0.168)))
		tb := uint8(math.Min(255, (r*0.272)+(g*0.534)+(b*0.131)))
		return tr, tg, tb
	})
}

//export FreeImageData
func FreeImageData(img *C.ImageData) {
	if img != nil {
		if img.data != nil {
			C.free(unsafe.Pointer(img.data))
		}
		C.free(unsafe.Pointer(img))
	}
}

func main() {}
