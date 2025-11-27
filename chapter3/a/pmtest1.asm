%include "pm.inc"

org 0100h
    jmp LABEL_BEGIN

[SECTION .gdt] ;also "SECTION .gdt"
; GDT define
LABEL_GDT:      Descriptor  0, 0, 0     ; 空描述符
LABEL_DESC_CODE32:      Descriptor  0, SegCode32Len - 1, DA_C + DA_32
LABEL_DESC_VIDEO:       Descriptor  0B8000H, 0FFFFH, DA_DRW
; GDT end

GdtLen  equ $ - LABEL_GDT
GdtPtr  dw GdtLen       ; GDT界限 (GdtPtr 用于写入 GDTR)
        dd 0    ; GDT基址

; GDT选择子
SelectorCode32  equ LABEL_DESC_CODE32 - LABEL_GDT
SelectorVideo   equ LABEL_DESC_VIDEO -  LABEL_GDT
; GDT选择子结束
; End of Section .gdt

[SECTION .s16]  ;also "SECTION .s16"
[BITS 16]   ;also "BITS 16"
LABEL_BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp ,0100h

    ; 初始化 32位代码段描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah

    ; 初始化GdtPtr
    xor eax, eax
    mov ax, cs  ;原程序中为 mvo ax, ds
    shl eax, 4
    add eax, LABEL_GDT
    mov dword [GdtPtr + 2], eax

    ; 载入 GDTR
    lgdt [GdtPtr]

    ; 关中断
    cli

    ; 打开地址线A20
    in al, 92h
    or al, 02h
    out 92h, al

    ; 准备切换到保护模式
    mov eax, cr0
    or  eax, 01H
    mov cr0, eax

    ; 重置段解释机制为保护模式的解释机制，真正进入保护模式
    jmp dword SelectorCode32:0
; End of Section .16


[SECTION .s32]
[BITS 32]
; 32位代码段，由实模式跳入
LABEL_SEG_CODE32:
    mov ax, SelectorVideo
    mov gs, ax

    mov edi, (80 * 10 + 40) * 2  ;
    mov ah, 8Ch ;红字黑低 => 低4位：前景色（红色 = 1100b），高4位：背景色（黑色 = 0000b）,第8bit置1字符闪烁
    mov al, 'F'

    mov [gs:edi], ax

    ;jmp $

SegCode32Len    equ $ - LABEL_SEG_CODE32
; End of Section .32
