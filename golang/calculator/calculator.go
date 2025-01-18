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

typedef struct {
    float brightness;
    float contrast;
    float saturation;
    float hue;
} FilterParams;
*/
import "C"
import (
	"math"
	"unsafe"
)

func processImageSafely(img *C.ImageData, processor func(r, g, b float64) (uint8, uint8, uint8)) *C.ImageData {
	if img == nil || img.data == nil {
		return nil
	}

	width := int(img.width)
	height := int(img.height)
	channels := int(img.channels)

	// Create output image
	output := (*C.ImageData)(C.malloc(C.size_t(unsafe.Sizeof(C.ImageData{}))))
	output.data = (*C.uint8_t)(C.malloc(C.size_t(width * height * channels)))
	output.width = img.width
	output.height = img.height
	output.channels = img.channels

	// Create Go slices from C arrays
	inputSlice := (*[1 << 30]uint8)(unsafe.Pointer(img.data))[: width*height*channels : width*height*channels]
	outputSlice := (*[1 << 30]uint8)(unsafe.Pointer(output.data))[: width*height*channels : width*height*channels]

	// Process each pixel
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			i := (y*width + x) * channels

			r := float64(inputSlice[i])
			g := float64(inputSlice[i+1])
			b := float64(inputSlice[i+2])

			newR, newG, newB := processor(r, g, b)

			outputSlice[i] = newR
			outputSlice[i+1] = newG
			outputSlice[i+2] = newB
			if channels == 4 {
				outputSlice[i+3] = inputSlice[i+3] // Preserve alpha channel
			}
		}
	}

	return output
}

//export ApplyAdvancedFilters
func ApplyAdvancedFilters(img *C.ImageData, params *C.FilterParams) *C.ImageData {
	return processImageSafely(img, func(r, g, b float64) (uint8, uint8, uint8) {
		// Apply brightness
		r *= float64(params.brightness)
		g *= float64(params.brightness)
		b *= float64(params.brightness)

		// Apply contrast
		factor := (259 * (float64(params.contrast)*100 + 255)) / (255 * (259 - float64(params.contrast)*100))
		r = factor*(r-128) + 128
		g = factor*(g-128) + 128
		b = factor*(b-128) + 128

		// Apply saturation
		gray := (r + g + b) / 3
		r = gray + float64(params.saturation)*(r-gray)
		g = gray + float64(params.saturation)*(g-gray)
		b = gray + float64(params.saturation)*(b-gray)

		// Clamp values
		return uint8(math.Min(255, math.Max(0, r))),
			uint8(math.Min(255, math.Max(0, g))),
			uint8(math.Min(255, math.Max(0, b)))
	})
}

//export ApplyBlur
func ApplyBlur(img *C.ImageData, radius C.int) *C.ImageData {
	if img == nil || img.data == nil {
		return nil
	}

	width := int(img.width)
	height := int(img.height)
	channels := int(img.channels)
	r := int(radius)

	output := (*C.ImageData)(C.malloc(C.size_t(unsafe.Sizeof(C.ImageData{}))))
	output.data = (*C.uint8_t)(C.malloc(C.size_t(width * height * channels)))
	output.width = img.width
	output.height = img.height
	output.channels = img.channels

	inputSlice := (*[1 << 30]uint8)(unsafe.Pointer(img.data))[: width*height*channels : width*height*channels]
	outputSlice := (*[1 << 30]uint8)(unsafe.Pointer(output.data))[: width*height*channels : width*height*channels]

	// Box blur implementation
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			var sumR, sumG, sumB float64
			count := 0

			for dy := -r; dy <= r; dy++ {
				for dx := -r; dx <= r; dx++ {
					nx := x + dx
					ny := y + dy

					if nx >= 0 && nx < width && ny >= 0 && ny < height {
						idx := (ny*width + nx) * channels
						sumR += float64(inputSlice[idx])
						sumG += float64(inputSlice[idx+1])
						sumB += float64(inputSlice[idx+2])
						count++
					}
				}
			}

			idx := (y*width + x) * channels
			outputSlice[idx] = uint8(sumR / float64(count))
			outputSlice[idx+1] = uint8(sumG / float64(count))
			outputSlice[idx+2] = uint8(sumB / float64(count))
			if channels == 4 {
				outputSlice[idx+3] = inputSlice[idx+3]
			}
		}
	}

	return output
}

func main() {}
