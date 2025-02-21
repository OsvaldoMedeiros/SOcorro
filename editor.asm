bits 16
org 0x0000

%define DIRETORIO_ENTRY_SIZE 15
%define TAMANHO_SETOR 512

start:
    ; Configura DS = CS
    push cs
    pop ds

    call limpar_tela

    ; Mensagem inicial
    mov si, MsgBemVindo
    call print_string
    call print_barra_n

editor_loop:
    ; Exibe prompt
    mov si, PromptEditor
    call print_string

    ; Lê linha de entrada
    mov bx, InputBuffer
    call limpar_buffer

    cld
    mov di, InputBuffer
    call ler_linha
    call print_barra_n

    ; Compara com "criar"
    mov si, InputBuffer
    mov di, CmdCriar
    mov cx, 6
    call compare_strings
    je comando_criar

    ; Compara com "listar"
    mov si, InputBuffer
    mov di, CmdListar
    mov cx, 6
    call compare_strings
    je comando_listar

    ; Se não encontrou
    mov si, MsgErroComando
    call print_string
    call print_barra_n
    jmp editor_loop

;------------------------------------------------------------------------------
; Comando "criar"
; Cria um novo arquivo.
;------------------------------------------------------------------------------
comando_criar:
    ; Solicita o nome do arquivo
    mov si, MsgNomeArquivo
    call print_string

    ; Lê o nome do arquivo
    mov bx, FileNameBuffer
    call limpar_buffer
    mov di, FileNameBuffer
    call ler_linha
    call print_barra_n

    ; Depuração: Imprime o conteúdo do buffer FileNameBuffer
    ;call print_buffer_filename
    ;call print_barra_n

    ; Chama a syscall para criar o arquivo
    mov ax, 0x01          ; Código da syscall "criar_arquivo"
    mov si, FileNameBuffer ; SI aponta para o nome do arquivo
    int 0x80              ; Chama o manipulador de syscalls

    ; Verifica se a criação foi bem-sucedida
    jc .falha_criacao
    mov si, MsgArquivoCriado
    call print_string
    call print_barra_n
    jmp editor_loop

.falha_criacao:
    mov si, MsgErroCriacao
    call print_string
    call print_barra_n
    jmp editor_loop
    

;------------------------------------------------------------------------------
; print_buffer_filename
; Imprime o conteúdo do buffer FileNameBuffer
;------------------------------------------------------------------------------
print_buffer_filename:
    mov bx, FileNameBuffer
    mov cx, 11           ; Limita a impressão aos primeiros 11 bytes
.print_loop:
    mov al, [bx]
    cmp al, 0            ; Terminador nulo
    je .done             ; Se sim, sai do loop
    mov ah, 0x0E         ; Funcao para imprimir caractere na tela
    int 0x10             ; Chama a interrupção de vídeo
    inc bx               ; Avança para o proximo caractere
    loop .print_loop
.done:
    ret

;------------------------------------------------------------------------------
; Comando "listar"
; Lista os arquivos existentes.
;------------------------------------------------------------------------------
comando_listar:
    ; Chama a syscall para listar arquivos
    mov ax, 0x05          ; Código da syscall "listar_arquivos"
    int 0x80              ; Chama o manipulador de syscalls

    ; Imprime os nomes dos arquivos
    mov si, DiretorioBuffer
    mov cx, TAMANHO_SETOR / DIRETORIO_ENTRY_SIZE
.listar_loop:
    ; Verifica se a entrada está vazia
    cmp byte [si], 0
    je .proximo_entrada

    ; Imprime o nome do arquivo
    push cx
    mov di, si
    call print_filename
    call print_barra_n
    pop cx

.proximo_entrada:
    add si, DIRETORIO_ENTRY_SIZE
    loop .listar_loop

    jmp editor_loop

;------------------------------------------------------------------------------
; Funções Auxiliares
;------------------------------------------------------------------------------
limpar_tela:
    mov ah, 0x06
    mov al, 0
    mov bh, 0x0F
    mov ch, 0
    mov cl, 0
    mov dh, 24
    mov dl, 79
    int 0x10

    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 0
    int 0x10
    ret

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

print_barra_n:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

;------------------------------------------------------------------------------
; print_filename
; Imprime até 11 bytes ou até encontrar byte 0
; Entrada: SI -> ponteiro para o nome do arquivo
;------------------------------------------------------------------------------
print_filename:
.pf_loop:
    mov al, [si]       ; Lê o caractere atual
    cmp al, 0          ; Verifica se é um terminador nulo
    je .pf_done        ; Se for, sai do loop
    mov ah, 0x0E       ; Função para imprimir caractere na tela
    int 0x10           ; Chama a interrupção de vídeo
    inc si             ; Avança para o próximo caractere
    jmp .pf_loop       ; Repete o loop
.pf_done:
    ret

ler_linha:
    pusha
    xor cx, cx
.ler_caractere:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .terminar_linha
    stosb
    inc cx
    mov ah, 0x0E
    int 0x10
    jmp .ler_caractere
.terminar_linha:
    mov byte [di], 0
    popa
    ret

limpar_buffer:
    mov cx, 512
    xor al, al
.loop:
    mov [bx], al
    inc bx
    loop .loop
    ret

compare_strings:
.cs_loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .cs_done
    cmp al, 0
    je .cs_done
    inc si
    inc di
    loop .cs_loop
    cmp ax, ax
.cs_done:
    ret

;------------------------------------------------------------------------------
; Variáveis e Constantes
;------------------------------------------------------------------------------
MsgBemVindo         db 'Bem-vindo ao Editor de Texto.', 0
PromptEditor        db '> ', 0
CmdCriar            db 'criar', 0
CmdListar           db 'listar', 0
MsgErroComando      db 'Comando desconhecido.', 0
MsgNomeArquivo      db 'Digite o nome do arquivo: ', 0
MsgErroCriacao      db 'Erro ao criar o arquivo.', 0
MsgArquivoCriado    db 'Arquivo criado com sucesso.', 0

InputBuffer         db 512 dup(0)
FileNameBuffer      db 12 dup(0) ; Nome do arquivo + terminador
DiretorioBuffer     db 512 dup(0)

; Preenchimento até o final do setor
times 1536 - ($ - $$) db 0
