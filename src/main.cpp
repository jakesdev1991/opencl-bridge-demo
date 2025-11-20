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
