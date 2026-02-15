BITS 32

section .text
global gdt_flush
global read_esp
global read_ebp

gdt_flush:
    ; cdecl: [esp+4] = gdtr*, [esp+8] = data selector, [esp+12] = code selector
    mov eax, [esp + 4]
    lgdt [eax]

    mov ax, [esp + 8]
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    movzx eax, word [esp + 12]
    push eax
    push dword .reload_cs
    retf

.reload_cs:
    ret

read_esp:
    mov eax, esp
    ret

read_ebp:
    mov eax, ebp
    ret
