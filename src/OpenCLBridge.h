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
