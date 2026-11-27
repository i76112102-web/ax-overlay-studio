//
//  pacia_gadget.s
//
//  lara's findpacia() dlsym's "$sSwySWSnySiGciM" and scans the next 0x1000
//  bytes for the instruction sequence:
//      pacia x16, x17
//      mov x0, x16
//      ret
//  Export it as a real assembly symbol so the linker cannot dead-strip it.
//

    .section __TEXT,__text,regular,pure_instructions
    .globl _$sSwySWSnySiGciM
    .p2align 2
_$sSwySWSnySiGciM:
    .long 0xDAC10230           // pacia x16, x17
    mov x0, x16
    ret

