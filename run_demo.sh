#!/data/data/com.termux/files/usr/bin/sh
cd "$(dirname "$0")"

# Point to the vendor libs for Adreno GPU support, then execute the new binary
LD_LIBRARY_PATH=/vendor/lib64:/vendor/lib64/egl ./bin/cl_demo
