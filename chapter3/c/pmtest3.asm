%include "pm.inc"

org 0100h
    jmp LABEL_BEGIN

[SECTION .gdt]

; GDT                                  ; 段基址            段界限     段属性
LABEL_GDT:           Descriptor              0,                0,    0
LABEL_DESC_NORMAL:   Descriptor              0,           0ffffh,    DA_DRW
LABEL_DESC_CODE16:   Descriptor              0,           0FFFFH,    DA_C
LABEL_DESC_CODE32:   Descriptor              0, SegCode32Len - 1,    DA_C + DA_32
LABEL_DESC_DATA:     Descriptor              0,      DataLen - 1,    DA_DRW
LABEL_DESC_STACK:    Descriptor              0,       TopOfStack,    DA_DRWA + DA_32
LABEL_DESC_VIDEO:    Descriptor        0B8000H,           0FFFFH,    DA_DRW     ; 显存首地址，用于显示字符
LABEL_DESC_LDT:      Descriptor              0,       LDTLen - 1,    DA_LDT
; GDT结束

GdtLen  equ  $ - LABEL_GDT   ; GDT长度
GdtPtr  dw  GdtLen  ; GDT界限
        dd  0       ; GDT基址

; GDT选择子
SelectorNormal  equ LABEL_DESC_NORMAL   -   LABEL_GDT
SelectorCode16  equ LABEL_DESC_CODE16   -   LABEL_GDT
SelectorCode32  equ LABEL_DESC_CODE32   -   LABEL_GDT
SelectorData    equ LABEL_DESC_DATA     -   LABEL_GDT 
SelectorStack   equ LABEL_DESC_STACK    -   LABEL_GDT
SelectorVideo   equ LABEL_DESC_VIDEO    -   LABEL_GDT
SelectorLDT     equ LABEL_DESC_LDT      -   LABEL_GDT
; End of [SECTION .gdt]

; LDT
[SECTION .ldt]
LABEL_LDT:
LABEL_LDT_DESC_CODEA:   Descriptor           0,     CodeALen - 1,   DA_C + DA_32

LDTLen  equ $ - LABEL_LDT

; LDT 选择子
SelectorLDTCodeA    equ LABEL_LDT_DESC_CODEA - LABEL_LDT + SA_TIL   ; SA_TIL: 置 TI(Table_Indictor) 位为1，指示该描述符从局部描述符 LDT 中读取
; End of [SECTION .ldt]

; 数据段
[SECTION .data1]
[BITS 32]
LABEL_DATA:
SPValueInRealMode   dw  0   ; 存储实模式下 SP 的值

; 字符串
PMMessage:  db  "In Protect Mode now. ^-^",     0
StrTest:    db  "ABCDEFGHIJKLMNOPQRSTUVWXYZ",   0
OffsetPMMessage equ PMMessage - $$
OffsetStrTest   equ StrTest - $$
DataLen         equ $ - LABEL_DATA
; End of [SECTION .data1]

; 保护模式下堆栈段
[SECTION    .gs]
[BITS   32]
LABEL_STACK:
    times   512 db  0

TopOfStack  equ $ - LABEL_STACK
; End of [SECTION .gs]

[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0100H   ; 设置实模式下的栈指针

    mov [LABEL_GO_BACK_TO_REAL + 3], ax
    mov [SPValueInRealMode], sp

    ; 初始化16位代码段描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE16
    mov word [LABEL_DESC_CODE16 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE16 + 4], al
    mov byte [LABEL_DESC_CODE16 + 7], ah

    ; 初始化32位代码段描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah

    ; 初始化数据段描述符
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_DATA
    mov word [LABEL_DESC_DATA + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_DATA + 4], al
    mov byte [LABEL_DESC_DATA + 7], ah

    ; 初始化堆栈段描述符
    xor eax, eax
    mov ax, ss
    shl eax, 4
    add eax, LABEL_STACK
    mov word [LABEL_DESC_STACK + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_STACK + 4], al
    mov byte [LABEL_DESC_STACK + 7], ah

    ; 初始化 LDT 在 GDT 中的描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_LDT
    mov word [LABEL_DESC_LDT + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_LDT + 4], al
    mov byte [LABEL_DESC_LDT + 7], ah

    ; 初始化 LDT 中的描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_CODE_A
    mov word [LABEL_LDT_DESC_CODEA + 2], ax
    shr eax, 16
    mov byte [LABEL_LDT_DESC_CODEA + 4], al
    mov byte [LABEL_LDT_DESC_CODEA + 7], ah

    ; 为加载 GDTR 做准备
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_GDT
    mov dword [GdtPtr + 2], eax
    
    ; 加载 GDTR
    lgdt [GdtPtr]

    ; 关中断
    cli

    ; 打开地址线 A20
    in al, 92H
    or al, 02H
    out 92H, al

    ;切换至保护模式
    mov eax, cr0
    or eax, 01H
    mov cr0, eax    ; 进入保护模式

    ; 真正进入保护模式
    jmp dword SelectorCode32:0

; 32位代码段，由实模式跳入
[SECTION .s32]
[BITS 32]
LABEL_SEG_CODE32:
    mov ax, SelectorData
    mov ds, ax          ; 数据段选择子
    mov ax, SelectorStack
    mov ss, ax          ; 堆栈段选择子
    mov ax, SelectorVideo
    mov gs, ax          ; 视频段选择子

    mov esp, TopOfStack

    ; 显示一个字符串
    mov ah, 8CH
    xor edi, edi
    mov edi, (80 * 10 + 0) * 2
    mov esi, OffsetPMMessage

    ; D 位置0，进行串操作时ESI\SI，EDI\DI向地址递增方向进行
    cld
.1:
    lodsb   ; 将[DS:SI]的一字节数据送入AL，并根据DF位自动增/减 SI/ESI（DI/EDI不变
    test al, al
    jz .2
    mov [gs:edi], ax
    add edi, 2
    jmp .1
.2:
    call DispReturn ; 换行
    
    ; 加载 LDTR
    mov ax, SelectorLDT
    lldt ax

    ; 跳转到局部任务（jump to LABEL_CODE_A）
    jmp SelectorLDTCodeA:0

; ------------------------------------------------------------------------
; 将待写入位置换为下一行第0列 -> 把 EDI（当前视频内存字节偏移，指向下一个要写的字符位置）调整到下一行的起始位置（列 0）
DispReturn:
    push eax
    push ebx
    mov eax, edi

    mov bl, 160
    div bl      ; 字节除法：除数为8位寄存器操作数或内存操作数，16位被除数默认放在AX中
                ; 得到的8位商送入AL,8位余数送入AH
    and eax, 0FFH   ; 余数清零，保留商
    inc al      ; 写入位置移至下一行

    mov bl, 160
    mul bl      ; 字节乘法：乘数为8位寄存器或内存操作数，被乘数默认放在AL中
				; 得到的16位乘积送入AX
    mov edi, eax

    pop ebx
    pop eax
    
    ret
; DispReturn 结束---------------------------------------------------------

SegCode32Len    equ $ - LABEL_SEG_CODE32
; END of [SECTION .s32]

[SECTION .la]
[BITS 32]
LABEL_CODE_A:
    mov ax, SelectorVideo
    mov gs, ax
    mov al, 'F'
    mov ah, 8CH
    mov edi, (80 * 12 + 0) * 2
    mov [gs:edi], ax

	; 准备经由16位代码段跳回实模式
    jmp SelectorCode16:0

CodeALen:   equ $ - LABEL_CODE_A

; 保护模式下的 16 位代码段. 由 32 位代码段跳入, 跳出该16位代码段后到实模式
[SECTION .s16code]
[BITS 16]
LABEL_SEG_CODE16:
	; 跳回实模式:
    mov ax, SelectorNormal
    mov ds, ax
    mov es, ax
    ;mov fs, ax
    mov gs, ax
    mov ss, ax

    mov eax, cr0
    and eax, 11111110b
    mov cr0, eax        ; CR0 PE位置0，切换为实模式

LABEL_GO_BACK_TO_REAL:
    jmp 0:LABEL_REAL_ENTRY  ; 段基址在程序开始处被设置成正确的值

Code16Len   equ $ - LABEL_SEG_CODE16
; END of [SECTION .s16code]

LABEL_REAL_ENTRY:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov sp, [SPValueInRealMode]

    in  al, 92H        ; ┓
    and al, 11111101b  ; ┣ 关闭 A20 地址线
    out 92H, al        ; ┛

    sti             ; 开中断

    mov ax, 4c00h   ; ┓
    int 21h         ; ┛回到 DOS
; END of [SECTION .s16]