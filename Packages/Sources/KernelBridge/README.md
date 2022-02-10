# KernelBridge

Contains extensions of the Obj-C++ [KernelBridge](Packages/Sources/Kernel/Kernel.h) class found in the Kernel 
package. This would be unnecessary if Obj-C++ headers in packages could `@import` a dependency package file like the 
Obj-C++ source files can. Since they cannot and we have Swift protocols we want to conform to, this is the solution.
