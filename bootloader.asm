bits 16
org 0x7C00      ; Define o endereço de carregamento como 7C00h

%define SETOR_KERNEL 3

start:
    ; Inicialização da pilha
    mov ax, 0x07C0  
    mov ss, ax
    mov sp, 0x03FE

    ; Configuração do segmento de dados
    xor ax, ax
    mov ds, ax

    ; Alterar o modo de vídeo
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Ler dados do disquete (setor 2)
    mov ah, 0x02
    mov al, 0x05        ; ler 5 setores
    mov ch, 0x00
    mov cl, SETOR_KERNEL 
    mov dh, 0x00
    mov dl, 0x00
    mov bx, 0x0800
    mov es, bx
    mov bx, 0x0000
    int 0x13

    ; Pular para o kernel
    jmp 0x0800:0x0000

; Preencher o setor de boot com zeros até o byte 510
times 510 - ($ - $$) db 0
dw 0xAA55      ; Assinatura de bootloader
