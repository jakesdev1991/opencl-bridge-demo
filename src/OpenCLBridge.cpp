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
