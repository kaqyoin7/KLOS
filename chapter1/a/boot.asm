%define _BOOT_DEBUG_ ;制作Boot Sector(.bin)时注释此行
                     ;此行打开后使用 "nasm boot.asm -o boot.com" 制作为DOS下可运行的COM文件，用于调试

%ifdef _BOOT_DEBUG_
    org 0100h
%else
    org 07c00h
%endif

    mov ax,cs
    mov ds,ax
    mov es,ax
    call DispStr
    jmp $   ; $: 当前地址
DispStr:
    mov ax,BootMessage  ;将BootMessage(即Hello, OS world!字符串)的首地址传给ax
    mov bp,ax
    mov cx,16
    mov ax,01301h
    mov bx,000ch
    mov dl, 0
    int 10h
    ret
BootMessage: db "Hello, OS world!"
; $$:一个section（节）的开始处被汇编后的地址，在该程序中仅有一个section，因此此处$$表示程序被编译后的开始地址
times 510-($-$$) db 0  ;因此($-$$)为表示汇编后程序开始地址到本行地址的长度，此处即为用0填充510B中剩下的空间

dw 0xaa55 ;作为boot sector的结束标志，刚好2B，与前面的510B合计为512B
