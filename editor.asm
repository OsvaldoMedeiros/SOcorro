; ---------------------------------------------------------------------------
; É carregado em 0x1000:0000 (3 setores).
;
; Obs:
;   Nome de arquivo limitado a 11 bytes, sem espaços, terminado em 0.
;   O kernel armazena/recupera dados de 1 setor (512 bytes) em 0x9000:0000.
; ---------------------------------------------------------------------------
bits 16
org 0x0000

%define DIRETORIO_ENTRY_SIZE 15

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
    mov word [TAM_LIMPAR], TAMANHO_SETOR
    call limpar_buffer

    cld
    mov di, InputBuffer
    call ler_linha
    call print_barra_n

    ; Compara com "criar"
    mov si, InputBuffer
    mov di, cmdCriar
    mov cx, 6
    call compare_strings
    je comando_criar

    ; Compara com "listar"
    mov si, InputBuffer
    mov di, cmdListar
    mov cx, 6
    call compare_strings
    je comando_listar

    ; Compara com "ler"
    mov si, InputBuffer
    mov di, cmdLer
    mov cx, 3
    call compare_strings
    je do_ler

    ; Compara com "gravar"
    mov si, InputBuffer
    mov di, cmdGravar
    mov cx, 6
    call compare_strings
    je do_gravar

    ; Compara com "sair"
    mov si, InputBuffer
    mov di, cmdSair
    mov cx, 4
    call compare_strings
    je do_sair

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
    mov word [TAM_LIMPAR], 11
    call limpar_buffer
    mov di, FileNameBuffer
    call ler_linha
    call print_barra_n

    ; Chama a syscall para criar o arquivo
    mov ax, 0x01          ; Código da syscall "criar_arquivo"
    mov si, FileNameBuffer ; SI aponta para o nome do arquivo
    int 0x80              ; Chama o manipulador de syscalls

    ; Verifica se a criação foi bem-sucedida
    jc .falha_criacao
    mov si, MsgArquivoCriado
    call print_string
    call print_barra_n

    mov word [TAM_LIMPAR], TAMANHO_SETOR
    mov bx, InputBuffer
    call limpar_buffer
    jmp editor_loop

.falha_criacao:
    mov si, MsgErroCriacao
    call print_string
    call print_barra_n
    mov word [TAM_LIMPAR], TAMANHO_SETOR
    mov bx, InputBuffer
    call limpar_buffer
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



; ---------------------------------------------------------------------------
; do_ler
; ---------------------------------------------------------------------------
do_ler:
    ; Pede ao usuário o nome do arquivo
    mov si, MsgNomeArquivo
    call print_string

    ; Limpa o buffer e lê o nome do arquivo
    mov bx, FileNameBuffer
    mov word [TAM_LIMPAR], 11
    call limpar_buffer
    mov di, FileNameBuffer
    call ler_linha
    call print_barra_n
 
    ; Chama syscall ler_arquivo (AX=2)
    mov ax, 0x0002
    mov si, FileNameBuffer
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
    call copy_kernel_buffer_to_InputBuffer

    ; Exibe o que foi lido
    mov si, msgConteudoLido
    call print_string
    call print_barra_n

    ; Imprime o conteúdo
    mov si, InputBuffer
    call print_string
    call print_barra_n

    mov si, msgArquivoLido
    call print_string
    call print_barra_n

    jmp editor_loop

; ---------------------------------------------------------------------------
; do_gravar
; ---------------------------------------------------------------------------
do_gravar:
    ; Pede nome do arquivo
    mov si, MsgNomeArquivo
    call print_string

    ; limpa buffer
    mov bx, FileNameBuffer
    mov word [TAM_LIMPAR], 11
    call limpar_buffer

    mov di, FileNameBuffer
    call ler_linha
    call print_barra_n

    ; Pede conteúdo
    mov si, msgDigiteConteudo
    call print_string
    call print_barra_n

    ; limpando buffer
    mov bx, InputBuffer
    mov word [TAM_LIMPAR], TAMANHO_SETOR
    call limpar_buffer

    ; Lê conteúdo para InputBuffer
    mov di, InputBuffer
    call ler_linha
    call print_barra_n

    ; Copia InputBuffer -> 0x9000:0000
    call copy_InputBuffer_to_kernelBuffer

    ; Chama syscall gravar_arquivo (AX=3)
    ;   SI -> nome do arquivo
    ;   DI -> (qualquer), pois internamente o kernel sempre olha 0x9000:0000
    ;         mas manteremos a convenção de "mov di, 0"
    mov ax, 0x0003
    mov si, FileNameBuffer
    xor di, di         ; 0
    int 0x80

    ; Exibe mensagem
    mov si, msgArquivoGravado
    call print_string
    call print_barra_n

    jmp editor_loop

; ---------------------------------------------------------------------------
; do_sair
; Simplesmente entra em loop eterno (pois não temos syscall de sair).
; O kernel também não fornece uma "volta". Fica travado.
; ---------------------------------------------------------------------------
do_sair:
    mov si, msgSeparador
    call print_string
    call print_barra_n
    mov si, msgFim
    call print_string
    call print_barra_n
    int 19h

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
    pusha
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    popa
    ret

; ---------------------------------------------------------------------------
; copy_InputBuffer_to_kernelBuffer
; Copia DS:InputBuffer -> 0x9000:0000
; ---------------------------------------------------------------------------
copy_InputBuffer_to_kernelBuffer:
    pusha

    ; Salva nosso DS
    push ds

    ; DS atual = CS => para pegar o InputBuffer corretamente
    push cs
    pop ds

    ; SI = InputBuffer
    mov si, InputBuffer

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
; copy_kernel_buffer_to_InputBuffer
; Copia 0x9000:0000 -> DS:InputBuffer
; ---------------------------------------------------------------------------
copy_kernel_buffer_to_InputBuffer:
    pusha

    ; Configura ES para apontar para o buffer fixo do kernel (0x9000:0000)
    push es
    mov ax, 0x9000
    mov es, ax
    xor si, si

    ; DS continua sendo o segmento do editor; copiamos para InputBuffer
    mov di, InputBuffer

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

;------------------------------------------------------------------------------
; ler_linha
; Le uma linha do teclado e armazena no buffer em di (termina com byte 0)
;------------------------------------------------------------------------------
ler_linha:
.ll_loop:
    mov ah, 0
    int 16h

    cmp al, 0Dh  ; Enter
    je .fim_leitura

    cmp al, 08h  ; Backspace
    je .backspace

    ; Imprime e armazena
    mov ah, 0x0E
    int 0x10
    mov [di], al
    inc di
    jmp .ll_loop

.backspace:
    cmp di, InputBuffer  ; Verifica se ja estamos no inicio do buffer
    je .ll_loop          ; Se sim, ignora o backspace

    mov ah, 0x03         ; obter a posicao do cursor
    xor bh, bh           ; Pagina de video 0
    int 0x10             

    cmp dl, 0            ; Verifica se estamos na coluna 0
    jne .apagar_caractere ; Se não estamos na coluna 0, apaga o caractere
    ; Se estamos na coluna 0, precisamos ajustar a linha
    cmp dh, 0            ; Verifica se estamos na primeira linha
    je .ll_loop; Se estamos na primeira linha, não fazemos nada
    jmp .ajustar_linha   ; Caso contrario, ajustamos a linha

.ajustar_linha:
    mov dl, 79           ; Vai para a ultima coluna da linha anterior
    dec dh               ; Decrementa a linha atual
    jmp .ajustar_cursor  ; Ajusta o cursor

.apagar_caractere:
    dec dl               ; Move o cursor para tras, decrementando a coluna
    
.ajustar_cursor:
    mov ah, 0x02         
    xor bh, bh           ; Pagina de video 0
    int 0x10             ; Chama a interrupção BIOS

    ; Atualiza o buffer
    dec di               ; Retrocede a posição no buffer
    mov byte [di], 0     ; Limpa o caractere removido

    ; Agora limpa visualmente o caractere
    mov ah, 0x0E         ; Serviço de teletype
    mov al, ' '          ; Espaço em branco
    int 0x10             ; Imprime espaço
    
    ; E reposiciona o cursor novamente
    mov ah, 0x02         
    int 0x10 

    jmp .ll_loop         ; Volta ao loop principal

.fim_leitura:
    mov byte [di], 0  ; fecha string com 0
    ret

;------------------------------------------------------------------------------
; Entrada: buffer em bx, tamanho de bytes em TAM_LIMPAR
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
    popa
    ret

;------------------------------------------------------------------------------
; Variáveis e Constantes
;------------------------------------------------------------------------------
MsgBemVindo         db 'Bem-vindo ao Editor de Texto.', 0
PromptEditor        db 'EDITOR> ', 0
cmdCriar            db 'criar', 0
cmdLer              db 'ler', 0
cmdGravar           db 'gravar', 0
cmdSair             db 'sair', 0
cmdListar           db 'listar', 0

MsgErroComando      db 'Comando desconhecido.', 0
MsgNomeArquivo      db 'Digite o nome do arquivo: ', 0
MsgErroCriacao      db 'Erro ao criar o arquivo.', 0
MsgArquivoCriado    db 'Arquivo criado com sucesso.', 0
msgDigiteConteudo   db 'Digite o conteudo (max 511 chars, ENTER finaliza):', 0
msgConteudoLido     db 'Conteudo lido: ', 0
msgArquivoLido      db '[Ok] Leitura concluida!', 0
msgArquivoGravado   db '[Ok] Arquivo gravado!', 0
msgFim              db 'Editor finalizado. Retornando ao kernel (loop).',0

msgSeparador        db '-------------------------------', 0
msgQuebraLinha      db 0Dh, 0Ah, 0
TAM_LIMPAR          dw 0 

InputBuffer         db 512 dup(0)
FileNameBuffer      db 11 dup(0) ; Nome do arquivo + terminador
DiretorioBuffer     db 512 dup(0)

TAMANHO_SETOR       EQU 512

; Preenchimento até o final do setor
times 2560 - ($ - $$) db 0
