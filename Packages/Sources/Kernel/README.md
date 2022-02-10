# Kernel Package

This directory contains the files make up the kernel that does the actual filtering of audio samples. Most of the
actual work is performed in classes defined in C++ header files. There is a Obj-C++
[KernelBridge](Packages/Sources/Kernel/Kernel.h) class that provides an interface that Swift can use, but it 
just wraps a C++ `Kernel` class. The key is to not leak any C++ constructs into a file that might be used by Swift.

- [Kerne](Packages/Sources/Kernel/Kernel.h) -- provides simple interface in Obj-C for the kernel.
- [C++](Packages/Sources/Kernel/C++/Kernel.hpp) -- holds the C++ header file that performs the actual sample rendering.
Note that many of the include files it uses are found in the `AUv3-DSP-Headers` library that comes from the 
[AUv3Support](https://github.com/bradhowes/AUv3Support) package.

Note that although the `KernelBridge` Obj-C class is defined here, there is the
[KernelBridge](Packages/Sources/KernelBridge) Swift package that adds necessary protocol conformances to it since this
is not possible to do in Obj-C. That is why the Obj-C files for the `KernelBridge` class are in the `Kernel` package
and not in the `KernelBridge` package: the only place that can use C++ include files is the `KernelBridge.mm` file, and
the only place we can add protocol conformance is in the `KernelBridge.swift` file.
