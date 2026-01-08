#!/usr/bin/env python3
"""
Patch PuLID to work with newer InsightFace versions.
The newer InsightFace removed 'providers' from FaceAnalysis.__init__()
"""

import os
import sys

PULID_FILE = "/comfyui/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py"

if not os.path.exists(PULID_FILE):
    print(f"ERROR: {PULID_FILE} not found!")
    sys.exit(1)

with open(PULID_FILE, "r") as f:
    lines = f.readlines()

patched_lines = []
patched = False

for i, line in enumerate(lines):
    # Look for the FaceAnalysis line with providers argument
    if "FaceAnalysis(" in line and "providers=" in line:
        # Extract indentation
        indent = len(line) - len(line.lstrip())
        spaces = " " * indent
        
        # Replace with fixed version (no providers argument)
        new_line = f'{spaces}model = FaceAnalysis(name="antelopev2", root=INSIGHTFACE_DIR)\n'
        patched_lines.append(new_line)
        patched = True
        print(f"Line {i+1} PATCHED:")
        print(f"  OLD: {line.rstrip()}")
        print(f"  NEW: {new_line.rstrip()}")
    else:
        patched_lines.append(line)

if patched:
    with open(PULID_FILE, "w") as f:
        f.writelines(patched_lines)
    print("\n✅ Successfully patched pulidflux.py")
else:
    print("\n⚠️ No 'providers=' found in FaceAnalysis calls - may already be patched")

# Verify the patch
print("\n=== Verification ===")
with open(PULID_FILE, "r") as f:
    content = f.read()
    
if "providers=" in content:
    for i, line in enumerate(content.split("\n")):
        if "FaceAnalysis(" in line and "providers=" in line:
            print(f"❌ FAILED: Line {i+1} still has providers: {line.strip()}")
            sys.exit(1)
    print("✅ No providers= in FaceAnalysis calls")
else:
    print("✅ No providers= found anywhere in file")

print("✅ Patch verification complete!")