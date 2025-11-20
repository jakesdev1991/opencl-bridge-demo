````markdown
# OpenCL Bridge for Samsung Galaxy S25 Ultra

This is a minimal reference implementation for running OpenCL on the **Samsung Galaxy S25 Ultra** via Termux. It bridges C++ application code to the **Adreno 830 GPU** (Snapdragon 8 Elite).

## Hardware Target
* **Device:** Samsung Galaxy S25 Ultra
* **SoC:** Qualcomm Snapdragon 8 Elite
* **GPU:** Adreno 830
* **Driver Path:** `/vendor/lib64/libOpenCL.so`

## Why this works
Android does not officially support OpenCL in its public NDK. However, the S25 Ultra ships with proprietary OpenCL drivers for the Adreno 830 in the vendor partition. This project links against those drivers dynamically using `LD_LIBRARY_PATH`.

## Prerequisites (Termux)

You need the Clang compiler and OpenCL headers:

```bash
pkg install clang ocl-icd opencl-headers
````

## Build & Run

1.  **Compile:**

    ```bash
    ./build.sh
    ```

2.  **Run:**

    ```bash
    ./run_demo.sh
    ```

## Internal Mechanism

The `run_demo.sh` script forces the binary to look into the vendor partition for the GPU drivers:

```bash
LD_LIBRARY_PATH=/vendor/lib64:/vendor/lib64/egl ./bin/cl_demo
```
