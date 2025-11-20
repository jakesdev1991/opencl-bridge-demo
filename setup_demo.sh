#!/bin/bash

# 1. Create Directory Structure
echo "Creating directories..."
mkdir -p src/kernels
mkdir -p bin

# 2. Generate Header File
echo "Generating src/OpenCLBridge.h..."
cat << 'EOF' > src/OpenCLBridge.h
#pragma once

#define CL_TARGET_OPENCL_VERSION 200
#include <CL/cl.h>
#include <string>
#include <vector>
#include <iostream>

class OpenCLBridge {
public:
    OpenCLBridge();
    ~OpenCLBridge();

    bool init();
    bool loadKernel(const std::string& filePath, const std::string& kernelName);
    bool runVectorAdd(const std::vector<float>& inputA, 
                      const std::vector<float>& inputB, 
                      std::vector<float>& outputC);

private:
    cl_platform_id platform_id;
    cl_device_id device_id;
    cl_context context;
    cl_command_queue command_queue;
    cl_program program;
    cl_kernel kernel;

    std::string loadSource(const std::string& filePath);
};
EOF

# 3. Generate Implementation File
echo "Generating src/OpenCLBridge.cpp..."
cat << 'EOF' > src/OpenCLBridge.cpp
#include "OpenCLBridge.h"
#include <fstream>
#include <sstream>
#include <vector>

OpenCLBridge::OpenCLBridge() : 
    platform_id(nullptr), device_id(nullptr), 
    context(nullptr), command_queue(nullptr), 
    program(nullptr), kernel(nullptr) {}

OpenCLBridge::~OpenCLBridge() {
    if (kernel) clReleaseKernel(kernel);
    if (program) clReleaseProgram(program);
    if (command_queue) clReleaseCommandQueue(command_queue);
    if (context) clReleaseContext(context);
}

bool OpenCLBridge::init() {
    cl_int err;
    cl_uint num_platforms;

    err = clGetPlatformIDs(1, &platform_id, &num_platforms);
    if (err != CL_SUCCESS) {
        std::cerr << "Error getting platform ID." << std::endl;
        return false;
    }

    err = clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_GPU, 1, &device_id, NULL);
    if (err != CL_SUCCESS) {
        std::cerr << "Error getting GPU device. Trying CPU..." << std::endl;
        err = clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_CPU, 1, &device_id, NULL);
    }

    char deviceName[128];
    clGetDeviceInfo(device_id, CL_DEVICE_NAME, 128, deviceName, NULL);
    std::cout << "[Bridge] Initialized on device: " << deviceName << std::endl;

    context = clCreateContext(NULL, 1, &device_id, NULL, NULL, &err);
    command_queue = clCreateCommandQueue(context, device_id, 0, &err);

    return true;
}

std::string OpenCLBridge::loadSource(const std::string& filePath) {
    std::ifstream file(filePath);
    if (!file.is_open()) {
        std::cerr << "Failed to open kernel file: " << filePath << std::endl;
        return "";
    }
    std::stringstream buffer;
    buffer << file.rdbuf();
    return buffer.str();
}

bool OpenCLBridge::loadKernel(const std::string& filePath, const std::string& kernelName) {
    cl_int err;
    std::string sourceStr = loadSource(filePath);
    const char* source = sourceStr.c_str();
    
    if (sourceStr.empty()) return false;

    program = clCreateProgramWithSource(context, 1, &source, NULL, &err);
    err = clBuildProgram(program, 1, &device_id, NULL, NULL, NULL);
    
    if (err != CL_SUCCESS) {
        size_t len;
        char buffer[2048];
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, sizeof(buffer), buffer, &len);
        std::cerr << "Build Log: " << buffer << std::endl;
        return false;
    }

    kernel = clCreateKernel(program, kernelName.c_str(), &err);
    return (err == CL_SUCCESS);
}

bool OpenCLBridge::runVectorAdd(const std::vector<float>& inputA, 
                                const std::vector<float>& inputB, 
                                std::vector<float>& outputC) {
    cl_int err;
    size_t n = inputA.size();
    size_t bytes = n * sizeof(float);

    cl_mem d_a = clCreateBuffer(context, CL_MEM_READ_ONLY, bytes, NULL, NULL);
    cl_mem d_b = clCreateBuffer(context, CL_MEM_READ_ONLY, bytes, NULL, NULL);
    cl_mem d_c = clCreateBuffer(context, CL_MEM_WRITE_ONLY, bytes, NULL, NULL);

    clEnqueueWriteBuffer(command_queue, d_a, CL_TRUE, 0, bytes, inputA.data(), 0, NULL, NULL);
    clEnqueueWriteBuffer(command_queue, d_b, CL_TRUE, 0, bytes, inputB.data(), 0, NULL, NULL);

    int argN = (int)n;
    clSetKernelArg(kernel, 0, sizeof(cl_mem), &d_a);
    clSetKernelArg(kernel, 1, sizeof(cl_mem), &d_b);
    clSetKernelArg(kernel, 2, sizeof(cl_mem), &d_c);
    clSetKernelArg(kernel, 3, sizeof(int), &argN);

    size_t globalSize = n;
    size_t localSize = 64;
    if (globalSize % localSize != 0) globalSize = (globalSize / localSize + 1) * localSize;

    err = clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL, &globalSize, &localSize, 0, NULL, NULL);
    if (err != CL_SUCCESS) return false;

    clEnqueueReadBuffer(command_queue, d_c, CL_TRUE, 0, bytes, outputC.data(), 0, NULL, NULL);

    clReleaseMemObject(d_a);
    clReleaseMemObject(d_b);
    clReleaseMemObject(d_c);

    return true;
}
EOF

# 4. Generate Main.cpp
echo "Generating src/main.cpp..."
cat << 'EOF' > src/main.cpp
#include "OpenCLBridge.h"
#include <iostream>
#include <vector>

int main() {
    std::cout << "=== OpenCL Bridge Demo ===" << std::endl;
    OpenCLBridge bridge;

    if (!bridge.init()) return 1;

    // Ensure this path is relative to where you execute the binary
    if (!bridge.loadKernel("src/kernels/demo.cl", "vector_add")) return 1;

    const int N = 1024;
    std::vector<float> A(N, 1.0f);
    std::vector<float> B(N, 2.0f);
    std::vector<float> C(N);

    std::cout << "Running Vector Add on " << N << " elements..." << std::endl;
    if (bridge.runVectorAdd(A, B, C)) {
        std::cout << "Success! First 5 results: ";
        for(int i = 0; i < 5; i++) std::cout << C[i] << " ";
        std::cout << std::endl;
    } else {
        std::cout << "Failed." << std::endl;
    }
    return 0;
}
EOF

# 5. Generate Kernel File
echo "Generating src/kernels/demo.cl..."
cat << 'EOF' > src/kernels/demo.cl
__kernel void vector_add(__global const float *A, 
                         __global const float *B, 
                         __global float *C,
                         const int N) {
    int i = get_global_id(0);
    if (i < N) {
        C[i] = A[i] + B[i];
    }
}
EOF

# 6. Generate Build Script
echo "Generating build.sh..."
cat << 'EOF' > build.sh
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
EOF
chmod +x build.sh

# 7. Generate Run Script (Based on your QSystemicSelf reference)
echo "Generating run_demo.sh..."
cat << 'EOF' > run_demo.sh
#!/data/data/com.termux/files/usr/bin/sh
cd "$(dirname "$0")"

# Point to the vendor libs for Adreno GPU support, then execute the new binary
LD_LIBRARY_PATH=/vendor/lib64:/vendor/lib64/egl ./bin/cl_demo
EOF
chmod +x run_demo.sh

echo "Done! Type './build.sh' to compile, then './run_demo.sh' to run."
