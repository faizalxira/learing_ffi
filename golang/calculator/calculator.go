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

//export ApplyGrayscale
func ApplyGrayscale(img *C.ImageData) *C.ImageData {
	width := int(img.width)
	height := int(img.height)
	channels := int(img.channels)

	size := width * height * channels
	input := (*[1 << 30]uint8)(unsafe.Pointer(img.data))[:size:size]

	output := (*C.uint8_t)(C.malloc(C.size_t(size)))
	outputSlice := (*[1 << 30]uint8)(unsafe.Pointer(output))[:size:size]

	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			i := (y*width + x) * channels
			r := float64(input[i])
			g := float64(input[i+1])
			b := float64(input[i+2])

			gray := uint8((r*0.299 + g*0.587 + b*0.114))

			outputSlice[i] = gray
			outputSlice[i+1] = gray
			outputSlice[i+2] = gray
			if channels == 4 {
				outputSlice[i+3] = input[i+3] // preserve alpha
			}
		}
	}

	result := (*C.ImageData)(C.malloc(C.size_t(unsafe.Sizeof(C.ImageData{}))))
	result.data = output
	result.width = img.width
	result.height = img.height
	result.channels = img.channels
	return result
}

//export ApplySepia
func ApplySepia(img *C.ImageData) *C.ImageData {
	width := int(img.width)
	height := int(img.height)
	channels := int(img.channels)

	size := width * height * channels
	input := (*[1 << 30]uint8)(unsafe.Pointer(img.data))[:size:size]

	output := (*C.uint8_t)(C.malloc(C.size_t(size)))
	outputSlice := (*[1 << 30]uint8)(unsafe.Pointer(output))[:size:size]

	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			i := (y*width + x) * channels
			r := float64(input[i])
			g := float64(input[i+1])
			b := float64(input[i+2])

			tr := math.Min(255, (r*0.393)+(g*0.769)+(b*0.189))
			tg := math.Min(255, (r*0.349)+(g*0.686)+(b*0.168))
			tb := math.Min(255, (r*0.272)+(g*0.534)+(b*0.131))

			outputSlice[i] = uint8(tr)
			outputSlice[i+1] = uint8(tg)
			outputSlice[i+2] = uint8(tb)
			if channels == 4 {
				outputSlice[i+3] = input[i+3]
			}
		}
	}

	result := (*C.ImageData)(C.malloc(C.size_t(unsafe.Sizeof(C.ImageData{}))))
	result.data = output
	result.width = img.width
	result.height = img.height
	result.channels = img.channels
	return result
}

//export FreeImageData
func FreeImageData(img *C.ImageData) {
	C.free(unsafe.Pointer(img.data))
	C.free(unsafe.Pointer(img))
}

func main() {}
