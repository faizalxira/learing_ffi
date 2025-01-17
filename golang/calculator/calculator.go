package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"strings"
	"unsafe"
)

//export ReverseString
func ReverseString(input *C.char) *C.char {
	goString := C.GoString(input)
	runes := []rune(goString)
	for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
		runes[i], runes[j] = runes[j], runes[i]
	}
	return C.CString(string(runes))
}

//export CountWords
func CountWords(input *C.char) C.int {
	goString := C.GoString(input)
	words := strings.Fields(goString)
	return C.int(len(words))
}

//export Free
func Free(ptr unsafe.Pointer) {
	C.free(ptr)
}

func main() {}
