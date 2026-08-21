#!/bin/bash
# ANGLE ARMv8.0-A Strict Validation Script
# This script validates that built libraries conform to ARMv8.0-A baseline ISA
# and do not contain instructions or features from ARMv8.1+

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
TOTAL=0

# Function to print test result
print_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TOTAL=$((TOTAL + 1))
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}[PASS]${NC} $test_name: $message"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}[FAIL]${NC} $test_name: $message"
        FAILED=$((FAILED + 1))
    fi
}

# Function to print section header
print_section() {
    echo ""
    echo -e "${YELLOW}=== $1 ===${NC}"
}

# Function to check if tool exists
check_tool() {
    local tool_name="$1"
    if ! command -v "$tool_name" &> /dev/null; then
        echo -e "${RED}Error: $tool_name is not installed or not in PATH${NC}"
        exit 1
    fi
}

# Print header
print_section "ANGLE ARMv8.0-A Strict Validation"
echo "Validating ARMv8.0 baseline compliance..."
echo ""

# Check required tools
print_section "Checking required tools"
check_tool "file"
check_tool "readelf"
check_tool "llvm-objdump"
echo -e "${GREEN}All required tools are available${NC}"

# Configuration
LIBRARY_DIR="${1:-out/Android-arm64-v8}"
LIBEGL_NAME="libEGL_angle.so"
LIBGLESv2_NAME="libGLESv2_angle.so"

print_section "Checking library files"

# Check if library directory exists
if [ ! -d "$LIBRARY_DIR" ]; then
    print_result "Library directory exists" "FAIL" "Directory $LIBRARY_DIR not found"
    echo ""
    echo -e "${RED}Error: Build directory not found. Please build ANGLE first.${NC}"
    echo "Usage: $0 <build_directory>"
    echo "Example: $0 out/Android-arm64-v8"
    exit 1
fi

# Check for libEGL_angle.so
LIBEGL_PATH="$LIBRARY_DIR/$LIBEGL_NAME"
if [ -f "$LIBEGL_PATH" ]; then
    print_result "libEGL_angle.so exists" "PASS" "Found at $LIBEGL_PATH"
else
    print_result "libEGL_angle.so exists" "FAIL" "Not found in $LIBRARY_DIR"
fi

# Check for libGLESv2_angle.so
LIBGLESv2_PATH="$LIBRARY_DIR/$LIBGLESv2_NAME"
if [ -f "$LIBGLESv2_PATH" ]; then
    print_result "libGLESv2_angle.so exists" "PASS" "Found at $LIBGLESv2_PATH"
else
    print_result "libGLESv2_angle.so exists" "FAIL" "Not found in $LIBRARY_DIR"
fi

print_section "ELF Header Validation"

# Function to validate ELF header
validate_elf() {
    local lib_path="$1"
    local lib_name="$(basename "$lib_path")"
    
    if [ ! -f "$lib_path" ]; then
        return
    fi
    
    # Check ELF class (must be ELF64)
    ELF_CLASS=$(readelf -h "$lib_path" 2>/dev/null | grep "Class:" | awk '{print $2}')
    if [ "$ELF_CLASS" = "ELF64" ]; then
        print_result "$lib_name ELF64" "PASS" "64-bit ELF format"
    else
        print_result "$lib_name ELF64" "FAIL" "Expected ELF64, got $ELF_CLASS"
    fi
    
    # Check machine (must be AArch64)
    ELF_MACHINE=$(readelf -h "$lib_path" 2>/dev/null | grep "Machine:" | awk '{print $2}')
    if [ "$ELF_MACHINE" = "AArch64" ]; then
        print_result "$lib_name AArch64" "PASS" "ARM64 architecture"
    else
        print_result "$lib_name AArch64" "FAIL" "Expected AArch64, got $ELF_MACHINE"
    fi
    
    # Check file type
    FILE_TYPE=$(file "$lib_path")
    if echo "$FILE_TYPE" | grep -q "ELF 64-bit LSB shared object, ARM aarch64"; then
        print_result "$lib_name file type" "PASS" "ARM64 shared library"
    else
        print_result "$lib_name file type" "FAIL" "Unexpected file type: $FILE_TYPE"
    fi
}

validate_elf "$LIBEGL_PATH"
validate_elf "$LIBGLESv2_PATH"

print_section "ARMv8.0 ISA Validation"

# Function to check for ARMv8.1+ instructions
check_armv8_instructions() {
    local lib_path="$1"
    local lib_name="$(basename "$lib_path")"
    local disasm_file="${lib_path}.disasm"
    
    if [ ! -f "$lib_path" ]; then
        return
    fi
    
    # Disassemble the library
    llvm-objdump -d "$lib_path" > "$disasm_file" 2>/dev/null
    
    # ARMv8.1+ instructions to check for:
    # LSE atomics: LDADD, LDCLR, LDEOR, LDSET, SWP, CASP, STADD, STCLR, STEOR, STSET
    # CRC32: CRC32B, CRC32H, CRC32W, CRC32X, CRC32CB, CRC32CH, CRC32CW, CRC32CX
    # FP16: FCMLA, FMLAL, FMLSL (with half-precision)
    # Dot Product: SDOT, UDOT, FMLA (vector)
    # SVE/SVE2: Any SVE instruction
    # I8MM: USMMLA, SUSBL, etc.
    # BF16: BFMMLA, etc.
    
    # Check for LSE atomics (ARMv8.1)
    if grep -qiE '\b(ldadd|ldclr|ldeor|ldset|swp|casp|stadd|stclr|steor|stset)\b' "$disasm_file" 2>/dev/null; then
        print_result "$lib_name no LSE atomics" "FAIL" "Found ARMv8.1 LSE atomic instructions"
        rm -f "$disasm_file"
        return
    else
        print_result "$lib_name no LSE atomics" "PASS" "No ARMv8.1 LSE atomic instructions"
    fi
    
    # Check for CRC32 (ARMv8.1)
    if grep -qiE '\b(crc32|CRC32)\b' "$disasm_file" 2>/dev/null; then
        print_result "$lib_name no CRC32" "FAIL" "Found ARMv8.1 CRC32 instructions"
        rm -f "$disasm_file"
        return
    else
        print_result "$lib_name no CRC32" "PASS" "No ARMv8.1 CRC32 instructions"
    fi
    
    # Check for FP16 (ARMv8.2)
    if grep -qiE '\b(fcml[ah]|fmlal[2h]|fmlsl[2h]|bfmml[ah])\b' "$disasm_file" 2>/dev/null; then
        print_result "$lib_name no FP16" "FAIL" "Found ARMv8.2 FP16 instructions"
        rm -f "$disasm_file"
        return
    else
        print_result "$lib_name no FP16" "PASS" "No ARMv8.2 FP16 instructions"
    fi
    
    # Check for Dot Product (ARMv8.2/8.4)
    if grep -qiE '\b(sdot|udot|usdot|sudot)\b' "$disasm_file" 2>/dev/null; then
        print_result "$lib_name no DotProd" "FAIL" "Found ARMv8.2+ Dot Product instructions"
        rm -f "$disasm_file"
        return
    else
        print_result "$lib_name no DotProd" "PASS" "No ARMv8.2+ Dot Product instructions"
    fi
    
    # Check for SVE (ARMv8.2+)
    if grep -qiE '\b(sve|ptrue|ptrues|whilelo|whilert|whilele|whilelt|deh|sqinc|sqdec|sqaddv|sqmaxv|sqminv)\b' "$disasm_file" 2>/dev/null; then
        print_result "$lib_name no SVE" "FAIL" "Found ARMv8.2+ SVE instructions"
        rm -f "$disasm_file"
        return
    else
        print_result "$lib_name no SVE" "PASS" "No ARMv8.2+ SVE instructions"
    fi
    
    # Check for SVE2 (ARMv8.4+)
    if grep -qiE '\b(sve2|sve2\.)\b' "$disasm_file" 2>/dev/null; then
        print_result "$lib_name no SVE2" "FAIL" "Found ARMv8.4+ SVE2 instructions"
        rm -f "$disasm_file"
        return
    else
        print_result "$lib_name no SVE2" "PASS" "No ARMv8.4+ SVE2 instructions"
    fi
    
    # Check for I8MM (ARMv8.2+)
    if grep -qiE '\b(usmmla|smmla|usmml|smmla|usbl|sbl|usbl2|sbl2)\b' "$disasm_file" 2>/dev/null; then
        print_result "$lib_name no I8MM" "FAIL" "Found ARMv8.2+ I8MM instructions"
        rm -f "$disasm_file"
        return
    else
        print_result "$lib_name no I8MM" "PASS" "No ARMv8.2+ I8MM instructions"
    fi
    
    # Check for BF16 (ARMv8.6+)
    if grep -qiE '\b(bfmml[ah]|bfdot|bfmlal[2h])\b' "$disasm_file" 2>/dev/null; then
        print_result "$lib_name no BF16" "FAIL" "Found ARMv8.6+ BF16 instructions"
        rm -f "$disasm_file"
        return
    else
        print_result "$lib_name no BF16" "PASS" "No ARMv8.6+ BF16 instructions"
    fi
    
    # Clean up
    rm -f "$disasm_file"
}

check_armv8_instructions "$LIBEGL_PATH"
check_armv8_instructions "$LIBGLESv2_PATH"

print_section "ELF Attributes Validation"

# Function to check ELF attributes
check_elf_attributes() {
    local lib_path="$1"
    local lib_name="$(basename "$lib_path")"
    
    if [ ! -f "$lib_path" ]; then
        return
    fi
    
    # Check for ARM attributes
    ATTRIBUTES=$(readelf -A "$lib_path" 2>/dev/null)
    
    # Check for ARMv8.1+ features in attributes
    if echo "$ATTRIBUTES" | grep -qiE '(Tag_Advanced_SIMD_arch|Tag_FP_arch|Tag_CRC_arch)'; then
        # Extract the architecture version
        if echo "$ATTRIBUTES" | grep -qi 'ARMv8\.[1-9]'; then
            print_result "$lib_name ARM attributes" "FAIL" "Found ARMv8.1+ in ELF attributes"
        else
            print_result "$lib_name ARM attributes" "PASS" "ARMv8.0 or lower in ELF attributes"
        fi
    else
        print_result "$lib_name ARM attributes" "PASS" "No advanced ARM attributes or ARMv8.0 baseline"
    fi
}

check_elf_attributes "$LIBEGL_PATH"
check_elf_attributes "$LIBGLESv2_PATH"

print_section "Library Dependencies Validation"

# Function to check library dependencies
check_dependencies() {
    local lib_path="$1"
    local lib_name="$(basename "$lib_path")"
    
    if [ ! -f "$lib_path" ]; then
        return
    fi
    
    # Check NEEDED entries
    NEEDED=$(readelf -d "$lib_path" 2>/dev/null | grep "NEEDED" | awk '{print $5}')
    
    # Check for Vulkan dependency
    if echo "$NEEDED" | grep -qi "libvulkan"; then
        print_result "$lib_name Vulkan dependency" "PASS" "Links to Vulkan"
    else
        print_result "$lib_name Vulkan dependency" "WARN" "No Vulkan dependency found (may be static)"
    fi
    
    # Check for OpenGL dependency (should not be present)
    if echo "$NEEDED" | grep -qiE '(libGL|libEGL|libGLES)'; then
        # This is okay as long as it's not libGL.so.1 (system GL)
        print_result "$lib_name GL dependencies" "PASS" "Has GL-related dependencies (expected for ANGLE)"
    fi
}

check_dependencies "$LIBEGL_PATH"
check_dependencies "$LIBGLESv2_PATH"

print_section "SONAME Validation"

# Function to check SONAME
check_soname() {
    local lib_path="$1"
    local lib_name="$(basename "$lib_path")"
    
    if [ ! -f "$lib_path" ]; then
        return
    fi
    
    SONAME=$(readelf -d "$lib_path" 2>/dev/null | grep "SONAME" | awk '{print $5}')
    
    if [ -n "$SONAME" ]; then
        if echo "$SONAME" | grep -q "_angle"; then
            print_result "$lib_name SONAME" "PASS" "SONAME is $SONAME"
        else
            print_result "$lib_name SONAME" "WARN" "SONAME is $SONAME (may conflict with system libraries)"
        fi
    else
        print_result "$lib_name SONAME" "INFO" "No SONAME set"
    fi
}

check_soname "$LIBEGL_PATH"
check_soname "$LIBGLESv2_PATH"

# Print summary
print_section "Validation Summary"
echo "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All validation tests passed!${NC}"
    echo "The libraries are compatible with ARMv8.0-A baseline."
    exit 0
else
    echo ""
    echo -e "${RED}✗ Some validation tests failed!${NC}"
    echo "The libraries may contain ARMv8.1+ instructions or features."
    exit 1
fi
