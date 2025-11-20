#!/data/data/com.termux/files/usr/bin/sh
mkdir -p bin
clang++ src/main.cpp src/OpenCLBridge.cpp \
    -o bin/cl_demo \
    -std=c++17 \
    -lOpenCL \
    -Wall

if [ $? -eq 0 ]; then
    echo "Build successful."
else
    echo "Build failed."
fi
