# vLLM Local Build

## Project Context

This is a **local development build of vLLM HEAD** that supports the **llm-dev project** at `~/Dev/llm-dev/`.

**Relationship:**
- **vLLM repository** (you are here): Cutting-edge vLLM development from main branch
- **llm-dev project** (~/Dev/llm-dev/): Multi-modal AI platform that uses vLLM for LLM inference
- **Configuration**: llm-dev configures which vLLM version to use per-model via `llm/config/vllm-versions.json`

## Purpose

This local vLLM build exists to:
1. **Test new quantization formats** that aren't in stable releases (e.g., NVFP4A16/compressed-tensors)
2. **Support cutting-edge models** that require vLLM HEAD features
3. **Maintain development velocity** without waiting for official vLLM releases

Currently configured for:
- **qwen32nvfp4** model: Requires vLLM HEAD for compressed-tensors quantization support
- **RTX 5090 SM 1.0 (Hopper)** GPU architecture

## Fork & Upstream Management

This is a **public fork** with SM 1.0 optimizations:

```
origin:   https://github.com/kitaekatt/vllm.git       (your fork - push here)
upstream: https://github.com/vllm-project/vllm.git    (official - pull from here)
```

**Branch Strategy:**
- `main`: Clean, synced with upstream (no local modifications)
- `sm1.0-optimizations`: Local RTX 5090 optimizations (ready for PRs upstream)

**Syncing with upstream:**
```bash
git fetch upstream
git merge upstream/main main
git push origin main
```

**Contributing back:**
```bash
git push origin sm1.0-optimizations
gh pr create --base vllm-project/vllm:main --head kitaekatt/vllm:sm1.0-optimizations
```

## Build System

### Smart Incremental Rebuilds

The `build-conservative.sh` script automatically detects when to do full vs incremental rebuilds:

```bash
cd ~/Dev/git/vllm && bash build-conservative.sh
```

**Behavior:**
- **First build or flags changed**: Full rebuild (cleans everything, 30-40 minutes)
- **Flags unchanged**: Incremental rebuild (only changed code, 5-10 minutes)
- Tracks flags in `.build_flags.txt`

### Build Flags for RTX 5090

Key configuration for SM 1.0 support:
```bash
export CMAKE_CUDA_ARCHITECTURES="120"  # Force SM 12.0 (RTX 5090) CUTLASS compilation
```

This fixes CUTLASS MoE kernels for Geforce Blackwell architecture.

## Relationship to llm-dev

### How llm-dev Uses This vLLM Build

1. **Configuration** (llm-dev/llm/config/vllm-versions.json):
   ```json
   {
     "head": {
       "venv_path": "/home/christina/Dev/git/vllm/.venv",
       "python_executable": "/home/christina/Dev/git/vllm/.venv/bin/python",
       "status": "development",
       "description": "Latest development version from vLLM main branch (local build)"
     }
   }
   ```

2. **Model Configuration** (llm-dev/llm/config/models.json):
   ```json
   {
     "GY2233/Qwen2.5-32B-Instruct-NVFP4A16": {
       "vllm_version": "head",
       "quantization": "compressed-tensors"
     }
   }
   ```

3. **Runtime**: llm-dev scripts use `/home/christina/Dev/git/vllm/.venv/bin/python` to run models with compressed-tensors support

### When to Use vLLM HEAD

**Use HEAD version for models that:**
- Require quantization formats not in stable releases (NVFP4A16, new formats)
- Need cutting-edge vLLM features not yet released
- Are experimental or very new

**Use stable versions** (0.10.0, 0.11.0) for:
- Production-ready models
- Standard quantizations (AWQ, GPTQ)
- When stability is priority over features

## Architecture Decisions

### Conservative Dynamic Calculation (llm-dev principle)

vLLM parameters (max_context, gpu_memory_utilization, max_num_seqs) are **not hard-coded** in configuration. Instead:
- **Phase 1**: Calculate dynamically from available VRAM using conservative defaults
- **Phase 2**: Run benchmarks to measure actual usage (stored in llm-dev/benchmark_data/vllm_calibration.json)
- **Phase 3**: Use measured data for hardware-specific optimization (future work)

This ensures the same vLLM build works across different GPU VRAM sizes (8GB → 32GB).

## Common Tasks

### Rebuild after code changes
```bash
cd ~/Dev/git/vllm
bash build-conservative.sh  # Detects if incremental or full rebuild needed
```

### Test a specific model with vLLM HEAD
```bash
cd ~/Dev/llm-dev
source .venv/bin/activate
python llm/bin/benchmark.py qwen32nvfp4 --skip-cache-check
```

### Check build flags status
```bash
cd ~/Dev/git/vllm
cat .build_flags.txt
```

### Force full rebuild (if incremental fails)
```bash
cd ~/Dev/git/vllm
rm .build_flags.txt  # Clears flag cache
bash build-conservative.sh  # Will do full rebuild
```

## Current Issues & Status

**CUTLASS SM 1.0 Fix:**
- ✅ Root cause identified: CMAKE_CUDA_ARCHITECTURES not set for RTX 5090
- ✅ Fix applied: Added `export CMAKE_CUDA_ARCHITECTURES="120"` to build-conservative.sh
- ⏳ Rebuild in progress (30-40 minutes)
- 🔄 Next: Validate with qwen32nvfp4 test

## References

- **llm-dev project**: ~/Dev/llm-dev/CLAUDE.md (parent project documentation)
- **vLLM official**: https://github.com/vllm-project/vllm
- **Build logs**: ~/Dev/git/vllm/build-log.txt (after build completes)
