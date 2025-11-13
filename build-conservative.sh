#!/bin/bash -x
# Conservative build script for vllm with CUDA
# Minimizes memory usage during compilation to avoid OOM kills

set -e

echo "=========================================="
echo "vllm Conservative Build Script"
echo "=========================================="
echo ""
echo "Build Configuration:"
echo "  - Parallel compilation (-j10, memory-safe for 62GB RAM)"
echo "  - Standard optimization (-O2)"
echo "  - NVCC single-threaded to minimize memory usage"
echo ""

# Check if build flags have changed (for incremental vs full rebuild)
CURRENT_FLAGS="MAX_JOBS=10|NVCC_THREADS=1|CMAKE_BUILD_PARALLEL_LEVEL=10|NINJA_BUILD_PARALLELISM=10|CMAKE_CUDA_ARCHITECTURES=120"
BUILD_FLAGS_FILE=".build_flags.txt"

if [ -f "$BUILD_FLAGS_FILE" ]; then
  PREVIOUS_FLAGS=$(cat "$BUILD_FLAGS_FILE")
  if [ "$PREVIOUS_FLAGS" = "$CURRENT_FLAGS" ]; then
    echo "[1/4] Build flags unchanged - doing INCREMENTAL rebuild (faster)"
    INCREMENTAL_BUILD=true
  else
    echo "[1/4] Build flags changed - doing FULL rebuild (required)"
    echo "  Previous: $PREVIOUS_FLAGS"
    echo "  Current:  $CURRENT_FLAGS"
    INCREMENTAL_BUILD=false
  fi
else
  echo "[1/4] First build - doing FULL rebuild"
  INCREMENTAL_BUILD=false
fi

# Only clean if not incremental
if [ "$INCREMENTAL_BUILD" = "false" ]; then
  echo "  Cleaning previous build artifacts..."

  # Kill any leftover build processes from previous attempts
  echo "  Killing stray build processes..."
  killall -9 uv cmake ninja nvcc python 2>/dev/null || true
  sleep 1

  # Clean directories
  rm -rf build .cmake* _deps .deps CMakeCache.txt CMakeLists.txt.user 2>/dev/null || true
  rm -rf ~/.cache/uv/builds-v0/ 2>/dev/null || true
fi

echo ""

# Set memory-safe build environment for 62GB RAM
# Each CUDA kernel compilation uses ~5-6GB RAM
# 10 parallel jobs = ~60GB peak usage (safe with some margin)
export MAX_JOBS=10
export NVCC_THREADS=1
export CMAKE_BUILD_PARALLEL_LEVEL=10
export NINJA_BUILD_PARALLELISM=10
export CFLAGS="-O2"
export CXXFLAGS="-O2"
export CUDAFLAGS="-O2"
export MAKEFLAGS="-j10"
export CMAKE_CUDA_ARCHITECTURES="120"  # Force SM 12.0 (RTX 5090 Geforce Blackwell) - fixes CUTLASS MoE compilation

# Increase stack size to prevent stack overflow during compilation
ulimit -s unlimited 2>/dev/null || true

echo "[2/4] Environment set:"
echo "  MAX_JOBS=10"
echo "  NVCC_THREADS=1"
echo "  CMAKE_BUILD_PARALLEL_LEVEL=10"
echo "  NINJA_BUILD_PARALLELISM=10"
echo "  CFLAGS=-O2"
echo "  CXXFLAGS=-O2"
echo "  CMAKE_CUDA_ARCHITECTURES=120 (RTX 5090 SM 12.0)"
echo ""

echo "[3/4] Building vllm (this may take 30-40 minutes)..."
echo ""

uv pip install -e .

# Save current flags for next build (incremental rebuild detection)
echo "$CURRENT_FLAGS" > "$BUILD_FLAGS_FILE"

echo ""
echo "[4/4] Build complete!"
echo "=========================================="
echo "vllm installation successful"
if [ "$INCREMENTAL_BUILD" = "true" ]; then
  echo "Build type: INCREMENTAL (flags unchanged)"
else
  echo "Build type: FULL (first build or flags changed)"
fi
echo "=========================================="
