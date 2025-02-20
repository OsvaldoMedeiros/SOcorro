; ---------------------------------------------------------------------------
; É carregado em 0x1000:0000 (3 setores).
;
;   Comandos disponíveis no prompt do editor:
;       criar  -> cria um novo arquivo
;       ler    -> lê e mostra o conteúdo de um arquivo
;       gravar -> grava dados em um arquivo
;       sair   -> volta (fica em loop infinito, pois o kernel não retorna)
;
; Obs:
;   Nome de arquivo limitado a 11 bytes, sem espaços, terminado em 0.
;   O kernel armazena/recupera dados de 1 setor (512 bytes) em 0x9000:0000.
; ---------------------------------------------------------------------------

[org 0x0000]        ; origem do código (offset = 0, mas segmento será 0x1000)
bits 16

; ===========================================================================
; CÓDIGO
; ===========================================================================
main:
    ; Ajusta DS = CS para podermos acessar as variáveis de dados
    push cs
    pop ds

editor_loop:
    ; Exibe prompt
    mov si, promptEditor
    call print_string

    ; Lê comando do usuário para editorBuffer
    mov bx, editorBuffer
    mov word [TAM_LIMPAR], TAMANHO_SETOR
    call limpar_buffer
    mov di, editorBuffer
    call read_line

    ; Tira uma linha
    call newline

    ; Compara com "criar"
    mov si, editorBuffer
    mov di, cmdCriar
    mov cx, 5
    call compare_strings
    je do_criar

    ; Compara com "ler"
    mov si, editorBuffer
    mov di, cmdLer
    mov cx, 3
    call compare_strings
    je do_ler

    ; Compara com "gravar"
    mov si, editorBuffer
    mov di, cmdGravar
    mov cx, 6
    call compare_strings
    je do_gravar

    ; Compara com "sair"
    mov si, editorBuffer
    mov di, cmdSair
    mov cx, 4
    call compare_strings
    je do_sair

    ; Se nenhum comando coincide
    mov si, msgErroComando
    call print_string
    call newline
    jmp editor_loop
    

; ---------------------------------------------------------------------------
; do_criar
; ---------------------------------------------------------------------------
do_criar:
    ; Pede ao usuário o nome do arquivo
    mov si, msgDigiteNomeArq
    call print_string

    ; limpa buffer
    mov bx, fileNameBuffer
    mov word [TAM_LIMPAR], 12
    call limpar_buffer

    ; Lê o nome para fileNameBuffer
    mov di, fileNameBuffer
    call read_line
    call newline

    ; Chama syscall criar_arquivo (AX=1)
    mov ax, 0x0001
    mov si, fileNameBuffer
    int 0x80
    ; Se houve erro, o kernel já exibiu msg (ou travou). Caso contrário:
    mov si, msgArquivoCriado
    call print_string
    call newline
    jmp editor_loop 

; ---------------------------------------------------------------------------
; do_ler
; ---------------------------------------------------------------------------
do_ler:
    ; Pede ao usuário o nome do arquivo
    mov si, msgDigiteNomeArq
    call print_string

    ; limpa buffer
    mov bx, fileNameBuffer
    mov word [TAM_LIMPAR], 12
    call limpar_buffer

    ; Lê nome para fileNameBuffer
    mov di, fileNameBuffer
    call read_line
    call newline

    ; limpando buffer
    mov bx, editorBuffer
    mov word [TAM_LIMPAR], TAMANHO_SETOR
    call limpar_buffer
    
    ; Chama syscall ler_arquivo (AX=2)
    mov ax, 0x0002
    mov si, fileNameBuffer
    int 0x80
    ; Kernel colocou o conteúdo em 0x9000:0000, com até 512 bytes,
    ; terminados em 0 se menor que 512, ou sem 0 se cheio.

    ; acessando informações na região 0x9000:0000
    push ds
    mov ax, 0x9000
    mov ds, ax
    mov si, 0               ; ds:si => 0x9000:0000 (início do buffer do kernel)
    pop ds
    
    ; copiando da região 0x9000:0000
    call copy_kernel_buffer_to_editorBuffer

    ; Exibe o que foi lido
    mov si, msgConteudoLido
    call print_string
    call newline

    ; Imprime o conteúdo
    mov si, editorBuffer
    call print_string
    call newline

    mov si, msgArquivoLido
    call print_string
    call newline

    jmp editor_loop

; ---------------------------------------------------------------------------
; do_gravar
; ---------------------------------------------------------------------------
do_gravar:
    ; Pede nome do arquivo
    mov si, msgDigiteNomeArq
    call print_string

    ; limpa buffer
    mov bx, fileNameBuffer
    mov word [TAM_LIMPAR], 12
    call limpar_buffer

    mov di, fileNameBuffer
    call read_line
    call newline

    ; Pede conteúdo
    mov si, msgDigiteConteudo
    call print_string
    call newline

    ; limpando buffer
    mov bx, editorBuffer
    mov word [TAM_LIMPAR], TAMANHO_SETOR
    call limpar_buffer

    ; Lê conteúdo para editorBuffer
    mov di, editorBuffer
    call read_line
    call newline

    ; Copia editorBuffer -> 0x9000:0000
    call copy_editorBuffer_to_kernelBuffer

    ; Chama syscall gravar_arquivo (AX=3)
    ;   SI -> nome do arquivo
    ;   DI -> (qualquer), pois internamente o kernel sempre olha 0x9000:0000
    ;         mas manteremos a convenção de "mov di, 0"
    mov ax, 0x0003
    mov si, fileNameBuffer
    xor di, di         ; 0
    int 0x80

    ; Exibe mensagem
    mov si, msgArquivoGravado
    call print_string
    call newline

    jmp editor_loop

; ---------------------------------------------------------------------------
; do_sair
; Simplesmente entra em loop eterno (pois não temos syscall de sair).
; O kernel também não fornece uma "volta". Fica travado.
; ---------------------------------------------------------------------------
do_sair:
    mov si, msgSeparador
    call print_string
    call newline
    mov si, msgFim
    call print_string
    call newline
    jmp $

; ===========================================================================
; Rotinas auxiliares
; ===========================================================================

; ---------------------------------------------------------------------------
; print_string
; Exibe uma string (terminada em 0) na tela via BIOS (int 0x10, função 0x0E)
; ---------------------------------------------------------------------------
print_string:
    pusha
.next_char:
    mov al, [si]
    cmp al, 0
    je .fim
    mov ah, 0x0E
    int 0x10
    inc si
    jmp .next_char
.fim:
    popa
    ret

; ---------------------------------------------------------------------------
; newline
; Imprime CR+LF
; ---------------------------------------------------------------------------
newline:
    pusha
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    popa
    ret

; ---------------------------------------------------------------------------
; read_line
; Lê uma linha do teclado para DS:DI até encontrar ENTER (0Dh).
; Coloca terminador 0 no final.
; ---------------------------------------------------------------------------
read_line:
    pusha
.read_loop:
    ; Espera tecla
    mov ah, 0
    int 0x16

    cmp al, 0Dh        ; ENTER?
    je .fim_leitura

    cmp al, 08h        ; Backspace?
    je .backspace

    ; Mostra a tecla
    mov ah, 0x0E
    int 0x10
    ; Armazena no buffer
    mov [di], al
    inc di
    jmp .read_loop

.backspace:
    cmp di, editorBuffer
    je .read_loop
    ; Volta o cursor uma posição
    mov ah, 0x0E
    mov al, 08h
    int 0x10
    ; Apaga na tela (espaço em branco)
    mov al, ' '
    int 0x10
    ; Volta novamente
    mov al, 08h
    int 0x10

    dec di
    jmp .read_loop

.fim_leitura:
    mov byte [di], 0
    popa
    ret

; ---------------------------------------------------------------------------
; compare_strings
; Compara até CX caracteres ou até encontrar 0.
;   SI -> string1
;   DI -> string2
;   CX -> comprimento máximo
; Retorna ZF=1 (JE) se iguais, ZF=0 se diferente.
; ---------------------------------------------------------------------------
compare_strings:
    pusha
.cmp_loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .done
    cmp al, 0
    je .done
    inc si
    inc di
    loop .cmp_loop
    ; Se saiu por loop=0 sem diferir, consideramos iguais no limite
    cmp ax, ax      ; "força" ZF=1
.done:
    popa
    ret

; ---------------------------------------------------------------------------
; copy_editorBuffer_to_kernelBuffer
; Copia DS:editorBuffer -> 0x9000:0000
; ---------------------------------------------------------------------------
copy_editorBuffer_to_kernelBuffer:
    pusha

    ; Salva nosso DS
    push ds

    ; DS atual = CS => para pegar o editorBuffer corretamente
    push cs
    pop ds

    ; SI = editorBuffer
    mov si, editorBuffer

    ; Ajusta ES=0x9000 para copiar para o buffer do kernel
    mov ax, 0x9000
    mov es, ax

    xor di, di
.copy_loop:
    mov al, [si]
    mov [es:di], al
    inc si
    inc di
    cmp al, 0
    je .done
    cmp di, TAMANHO_SETOR
    jae .done
    jmp .copy_loop
.done:

    ; Restaura DS
    pop ds
    popa
    ret

; ---------------------------------------------------------------------------
; copy_kernel_buffer_to_editorBuffer
; Copia 0x9000:0000 -> DS:editorBuffer
; ---------------------------------------------------------------------------
copy_kernel_buffer_to_editorBuffer:
    pusha

    ; Configura ES para apontar para o buffer fixo do kernel (0x9000:0000)
    push es
    mov ax, 0x9000
    mov es, ax
    xor si, si

    ; DS continua sendo o segmento do editor; copiamos para editorBuffer
    mov di, editorBuffer

.copy_read:
    mov al, es:[si]   ; Acessa a memória no segmento ES (0x9000)
    mov [di], al
    inc si
    inc di
    cmp al, 0
    je .end_copy
    cmp si, TAMANHO_SETOR
    jae .end_copy
    jmp .copy_read

.end_copy:
    pop es
    popa
    ret


;------------------------------------------------------------------------------
; limpar_buffer
; in: buffer em bx, TAM_LIMPAR <- tamanho do buffer
; out: buffer com 0's
;------------------------------------------------------------------------------
limpar_buffer:
    pusha
    mov cx, [TAM_LIMPAR]    ; CX agora representa o número de bytes a limpar
    mov di, bx              ; BX já aponta para o início do buffer
    xor ax, ax              ; AX = 0
.lb_loop:
    mov byte [di], al       ; limpa 1 byte
    inc di
    loop .lb_loop
    popa
    ret


; ===========================================================================
; DADOS
; ===========================================================================
promptEditor        db 'EDITOR> ', 0
cmdCriar            db 'criar', 0
cmdLer              db 'ler', 0
cmdGravar           db 'gravar', 0
cmdSair             db 'sair', 0

msgDigiteNomeArq    db 'Digite o nome do arquivo (max 11 chars): ', 0
msgDigiteConteudo   db 'Digite o conteudo (max 511 chars, ENTER finaliza):', 0
msgConteudoLido     db 'Conteudo lido: ', 0
msgArquivoCriado    db '[Ok] Arquivo criado!', 0
msgArquivoGravado   db '[Ok] Arquivo gravado!', 0
msgErroComando      db '[Erro] Comando desconhecido.', 0
msgArquivoLido      db '[Ok] Leitura concluida!', 0
msgFim              db 'Editor finalizado. Retornando ao kernel (loop).',0

msgSeparador        db '-------------------------------', 0
msgQuebraLinha      db 0Dh, 0Ah, 0
TAM_LIMPAR          dw 0 
TAMANHO_SETOR       EQU 512

; Buffer local do editor para digitação do usuário
editorBuffer        times 512 db 0

; Nome do arquivo (até 11 bytes + 0)
fileNameBuffer      times 12 db 0

; ===========================================================================
; Preenche até 3 setores (1536 bytes) – pois o editor foi definido como 3 setores
; ===========================================================================
times 1536 - ($ - $$) db 0
