# Windows Runtime DLLs

This folder contains Microsoft Visual C++ Runtime DLLs required by media_kit and other native dependencies.

## Required DLLs:
- `MSVCP140.dll` - C++ Standard Library
- `VCRUNTIME140.dll` - C Runtime
- `VCRUNTIME140_1.dll` - C Runtime (additional)

## How to obtain these DLLs:

### Option 1: From an existing Windows installation
Copy from `C:\Windows\System32\`:
- MSVCP140.dll
- VCRUNTIME140.dll
- VCRUNTIME140_1.dll

### Option 2: Extract from VC++ Redistributable
1. Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
2. Extract using 7-Zip or similar tool
3. Copy the DLLs to this folder

## License
These DLLs are part of Microsoft Visual C++ Redistributable.
Redistribution is allowed under Microsoft's license terms.
See: https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files
