# ANGLE Android ARMv8.0-A Strict Build Configuration

This document describes the ARMv8.0-A strict build configuration for ANGLE (Almost Native Graphics Layer Engine) targeted at Android arm64-v8a devices with baseline ARMv8.0-A ISA support.

## Overview

This fork of ANGLE has been configured to produce builds that are **strictly compatible with ARMv8.0-A baseline** devices. This means:

- **No ARMv8.1+ instructions** (LSE atomics, CRC32, FP16, Dot Product, etc.)
- **No ARMv8.2+ extensions** (SVE, SVE2, I8MM, BF16, etc.)
- **Vulkan backend only** (no D3D11, Metal, OpenGL, SwiftShader, etc.)
- **Android arm64-v8a ABI** with strict ARMv8.0-A ISA
- **Output libraries**: `libEGL_angle.so`, `libGLESv2_angle.so`

## Changes Made

### 1. New Configuration Files

#### `build_overrides/armv8_android.gni`
- Defines ARMv8.0-A strict compiler flags:
  - `-march=armv8-a` (ARMv8.0-A baseline)
  - `-mno-outline-atomics` (disable LSE atomics from ARMv8.1)
  - `-mno-crc` (disable CRC32 from ARMv8.1)
  - `-mno-fp16` (disable FP16 from ARMv8.2)
  - `-mno-dotprod` (disable Dot Product from ARMv8.2/8.4)
  - `-mno-sve` (disable SVE from ARMv8.2+)
  - `-mno-sve2` (disable SVE2 from ARMv8.4+)
  - `-mno-i8mm` (disable I8MM from ARMv8.2+)
  - `-mno-bf16` (disable BF16 from ARMv8.6+)
  - `-mtune=generic` (prevent native CPU optimization)
- Forces Vulkan-only backend for Android
- Disables all other backends (D3D11, Metal, GL, SwiftShader, Null, WGPU)
- Ensures library naming with `_angle` suffix

#### `args_android_armv80.gn`
Complete GN arguments file for Android ARMv8.0-A builds:
- Target: Android arm64
- Backend: Vulkan only
- Optimization: Release mode (-O2)
- API Level: 26 (minimum supported by this ANGLE version)
- All non-Vulkan backends disabled
- ARMv8.0-A strict ISA flags

### 2. Modified Files

#### `gni/angle.gni`
- Modified backend enable flags to disable non-Vulkan backends for Android:
  - `angle_enable_d3d11 = is_win && !is_android`
  - `angle_enable_gl = ... && !is_android`
  - `angle_enable_metal = is_apple && !is_android`
  - `angle_enable_swiftshader = false`
  - `angle_enable_null = !is_official_build && !is_android`

#### `BUILD.gn`
- Added import for `//build_overrides/armv8_android.gni`
- This ensures ARMv8.0-A strict flags are applied to all builds

### 3. Validation Tools

#### `tools/check_armv80.sh`
Comprehensive validation script that checks:
1. **ELF Header Validation**
   - ELF64 class
   - AArch64 machine type
   - Shared library format

2. **ARMv8.0 ISA Validation**
   - Scans disassembly for ARMv8.1+ instructions:
     - LSE atomics (LDADD, LDCLR, LDEOR, LDSET, SWP, CASP, etc.)
     - CRC32 instructions
     - FP16 instructions
     - Dot Product instructions (SDOT, UDOT)
     - SVE/SVE2 instructions
     - I8MM instructions
     - BF16 instructions

3. **ELF Attributes Validation**
   - Checks for ARMv8.1+ features in ELF attributes

4. **Library Dependencies**
   - Verifies Vulkan dependency
   - Checks for unexpected OpenGL dependencies

5. **SONAME Validation**
   - Ensures libraries have `_angle` suffix to avoid conflicts

## Build Instructions

### Prerequisites

1. **Android NDK** (recommended: r25+)
2. **GN (Generate Ninja)**
3. **Ninja** build system
4. **Clang** (from NDK)
5. **Python 3**
6. **llvm-objdump** (for validation)
7. **readelf** (for validation)
8. **file** command (for validation)

### Build Steps

#### Step 1: Generate Build Files

```bash
# Using the provided args file
gn gen out/Android-arm64-v8 --args=args_android_armv80.gn
```

#### Step 2: Build ANGLE

```bash
# Build all ANGLE libraries
autoninja -C out/Android-arm64-v8
```

#### Step 3: Build Specific Targets

```bash
# Build libEGL and libGLESv2
autoninja -C out/Android-arm64-v8 libEGL libGLESv2

# Or build the APK (if needed)
autoninja -C out/Android-arm64-v8 angle_chromium_apk
```

#### Step 4: Validate the Build

```bash
# Run the validation script
./tools/check_armv80.sh out/Android-arm64-v8
```

The validation script will check:
- ELF64 format
- AArch64 architecture
- ARMv8.0-A baseline compliance
- No ARMv8.1+ instructions
- Proper library naming

### Expected Output

After a successful build, the following files will be created:

```
out/Android-arm64-v8/
├── libEGL_angle.so
├── libGLESv2_angle.so
├── libGLESv1_CM_angle.so
├── libfeature_support_angle.so
└── ...
```

## Integration with ZalithLauncher

### File Placement

Copy the built libraries to your ZalithLauncher project:

```bash
# Copy to jniLibs/arm64-v8a/
mkdir -p Quanneggaes4d_LauncherV1/ZalithLauncher/src/main/jniLibs/arm64-v8a/
cp out/Android-arm64-v8/libEGL_angle.so Quanneggaes4d_LauncherV1/ZalithLauncher/src/main/jniLibs/arm64-v8a/
cp out/Android-arm64-v8/libGLESv2_angle.so Quanneggaes4d_LauncherV1/ZalithLauncher/src/main/jniLibs/arm64-v8a/
```

### Library Loading

Ensure your launcher loads the ANGLE libraries correctly:

```java
// In your Java code, ensure the libraries are loaded in the correct order
System.loadLibrary("EGL_angle");
System.loadLibrary("GLESv2_angle");
```

### Rendering Pipeline

The expected rendering pipeline is:

```
Minecraft
    │
    ▼
LWJGL
    │
    ▼
LTW (libltw.so)
    │
    ▼ (OpenGL ES calls)
ANGLE EGL (libEGL_angle.so)
    │
    ▼
ANGLE GLES (libGLESv2_angle.so)
    │
    ▼ (Vulkan backend)
ANGLE Vulkan
    │
    ▼
Android Vulkan Driver
    │
    ▼
GPU
```

## ARMv8.0-A Baseline Compliance

### Supported Features (ARMv8.0-A Baseline)

- **AArch64** base architecture
- **Advanced SIMD (NEON)** - included in ARMv8.0-A baseline
- **Floating-point** - full IEEE 754 support
- **Integer operations** - all standard operations
- **Memory model** - ARMv8-A memory model

### Explicitly Disabled Features

The following ARMv8.1+ features are **explicitly disabled**:

#### ARMv8.1-A
- **LSE (Large System Extensions)**: Atomic operations (LDADD, LDCLR, LDEOR, LDSET, SWP, CASP, STADD, STCLR, STEOR, STSET)
- **CRC32**: Cyclic Redundancy Check instructions

#### ARMv8.2-A
- **FP16**: Half-precision floating-point (FMLAL, FMLSL, FCMLA)
- **Dot Product**: Signed/unsigned dot product (SDOT, UDOT)
- **SVE (Scalable Vector Extension)**: Optional, but disabled for baseline
- **I8MM (Int8 Matrix Multiply)**: Matrix multiplication extensions

#### ARMv8.3-A
- **Complex Numbers**: Complex number arithmetic
- **SVE2**: Enhanced scalable vector extensions

#### ARMv8.4-A
- **SVE2**: Standard scalable vector extension
- **BF16 (BFloat16)**: BFloat16 arithmetic
- **Dot Product (SIMD)**: Vector dot product

#### ARMv8.5-A
- **BF16**: Enhanced BFloat16 support
- **Memory Tagging**: Memory tagging extensions

#### ARMv8.6-A
- **SVE2**: Further SVE2 enhancements
- **BF16**: More BFloat16 operations

#### ARMv9-A
- **SVE2**: Standard in ARMv9
- **BF16**: Standard in ARMv9
- **MTE (Memory Tagging Extensions)**: Memory safety features

## Validation Checklist

Before deploying, verify that your build passes all these checks:

- [ ] Android platform target
- [ ] ELF64 format
- [ ] AArch64 architecture
- [ ] arm64-v8a ABI
- [ ] ARMv8-A baseline (no ARMv8.1+)
- [ ] No ARMv8.1 instructions
- [ ] No ARMv8.2+ instructions
- [ ] No SVE/SVE2
- [ ] No I8MM
- [ ] No BF16
- [ ] No CPU native detection
- [ ] Vulkan backend enabled
- [ ] EGL functional
- [ ] GLES2 functional
- [ ] Android Surface functional
- [ ] Vulkan physical device detected
- [ ] Vulkan device created
- [ ] Swapchain created
- [ ] First frame presented

## Troubleshooting

### Issue: Build fails with "unknown CPU"

**Solution**: Ensure you're using a recent NDK with ARMv8.0 support. The `-march=armv8-a` flag requires NDK r21+.

### Issue: Validation fails with ARMv8.1+ instructions

**Solution**: Check that:
1. The `armv8_android.gni` file is imported in `BUILD.gn`
2. The compiler flags are being applied (check the build logs)
3. You're not using `-mcpu=native` or similar flags

### Issue: Missing Vulkan dependencies

**Solution**: Ensure Vulkan is properly set up in your NDK. You may need to add:
```bash
# In your environment
export NDK_HOME=/path/to/android-ndk
export ANDROID_NDK_HOME=$NDK_HOME
```

### Issue: Library naming conflicts

**Solution**: The libraries should have the `_angle` suffix. If they don't:
1. Check that `angle_libs_suffix = "_angle"` in your args file
2. Verify the build is using the correct args file

## Build Configuration Reference

### Key GN Arguments

| Argument | Value | Purpose |
|----------|-------|---------|
| `target_os` | `"android"` | Android platform |
| `target_cpu` | `"arm64"` | ARM64 architecture |
| `is_debug` | `false` | Release build |
| `angle_enable_vulkan` | `true` | Enable Vulkan backend |
| `angle_enable_gl` | `false` | Disable OpenGL backend |
| `angle_enable_d3d11` | `false` | Disable D3D11 backend |
| `angle_enable_metal` | `false` | Disable Metal backend |
| `angle_enable_swiftshader` | `false` | Disable SwiftShader |
| `angle_enable_null` | `false` | Disable Null backend |
| `angle_enable_wgpu` | `false` | Disable WGPU backend |
| `android_ndk_api_level` | `26` | Minimum Android API |
| `angle_libs_suffix` | `"_angle"` | Library suffix |

### Compiler Flags

The following compiler flags are applied for ARMv8.0-A strict builds:

```
-march=armv8-a
-mno-outline-atomics
-mno-crc
-mno-fp16
-mno-dotprod
-mno-sve
-mno-sve2
-mno-i8mm
-mno-bf16
-mtune=generic
```

## NDK Version Compatibility

| NDK Version | ARMv8.0 Support | Recommended |
|-------------|-----------------|-------------|
| r20 | Partial | ❌ No |
| r21 | Yes | ⚠️ Minimum |
| r22 | Yes | ✅ Yes |
| r23 | Yes | ✅ Yes |
| r24 | Yes | ✅ Yes |
| r25+ | Yes | ✅ **Recommended** |

## References

- [ARMv8-A Architecture Reference Manual](https://developer.arm.com/documentation/ddi0487/a)
- [ANGLE Project](https://github.com/google/angle)
- [Android NDK](https://developer.android.com/ndk)
- [Vulkan on Android](https://developer.android.com/guide/topics/graphics/vulkan)

## License

This configuration and documentation is provided under the same license as ANGLE (BSD-style). See the LICENSE file for details.

---

**Note**: This configuration is specifically designed for the `denocraftplayerg-max/angle` fork and may need adjustments for other ANGLE versions or forks.
