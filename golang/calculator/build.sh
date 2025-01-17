#!/bin/bash

export ANDROID_NDK_HOME="C:\Users\XIRA-DeveloperPC\AppData\Local\Android\Sdk\ndk\27.1.12297006"
export GOARCH=arm64
export GOOS=android
export CGO_ENABLED=1
export CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android21-clang

go build -buildmode=c-shared -o ../../android/app/src/main/jniLibs/arm64-v8a/libcalculator.so