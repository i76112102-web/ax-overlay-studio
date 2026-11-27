#import <UIKit/UIKit.h>
#import "AppDelegate.h"

__attribute__((visibility("default")))
uint64_t AX_pacia_gadget_shim(uint64_t x0, uint64_t x16, uint64_t x17) {
    asm volatile ("mov x16, %[p]\n"
                  "mov x17, %[m]\n"
                  ".long 0xDAC10230\n"   // pacia x16, x17
                  "mov x0, x16\n"
                  "ret\n"
                  :
                  : [p] "r"(x16), [m] "r"(x17), "r"(x0)
                  : "x0", "x16", "x17");
    return x0;
}

// lara findpacia() looks up this Swift-mangled symbol and scans the following
// 0x1000 bytes for the pacia gadget. Export the shim under that exact name.
__asm__(".globl _$sSwySWSnySiGciM\n"
        "_$sSwySWSnySiGciM = _AX_pacia_gadget_shim");

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
