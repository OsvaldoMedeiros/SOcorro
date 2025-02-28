bits 16
org 0x0000   ; Endereço de carregamento (depende do bootloader)

;------------------------------------------------------------------------------
; Estrutura de Diretorio (15 bytes por entrada):
;   0..10:  Nome (11 bytes)
;   11..12: Tamanho (2 bytes)
;   13..14: Setor inicial (2 bytes)
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;  Estrutura de setores
;   boot - setor 1
;   diretorio raiz - setor 2
;   kernel - setor 3...7
;   editor - setor 8...12
;   arquivos - setor 13...
;------------------------------------------------------------------------------

%define DIRETORIO_ENTRY_SIZE 15
%define TAMANHO_SETOR        512
%define NUMERO_MAXIMO_SETORES 2880
%define EDITOR_TAM 5
%define SETOR_EDITOR 8  ; BIOS conta começando em 1, em vez de 0 (uso nas int)
%define SETOR_DIR_RAIZ 2    ;diretorio raiz (armazena nome, tamanho e setor inicial dos arquivos)
%define SETOR_LIVRE_PRIM 13

;------------------------------------------------------------------------------
; Inicio (ponto de entrada)
;------------------------------------------------------------------------------
start:
    ; DS = CS
    push cs
    pop ds

    call inicializar_dir_raiz

    call limpar_tela

    ; Mensagem inicial
    mov si, MensagemInicial
    call print_string
    call print_barra_n

    ; Inicializa variaveis
    mov word [SetorLivre], SETOR_LIVRE_PRIM 
    
    ; Configura vetor de funções da int 0x80
    mov ax, 0x0000
    mov es, ax
    mov word [es:(0x80*4)], syscall_handler
    mov word [es:(0x80*4+2)], cs

;------------------------------------------------------------------------------
; cli_loop
; Loop para ler comandos do usuario e executar
;------------------------------------------------------------------------------
cli_loop:
    mov si, Prompt
    call print_string

    ; Le comando
    mov bx, InputBuffer
    call limpar_buffer
    mov di, InputBuffer
    call ler_linha
    call print_barra_n

    ; Compara com "reiniciar"
    mov si, InputBuffer
    mov di, CmdReiniciar
    mov cx, 9
    call compare_strings
    je reiniciar

    ; Compara com "editar"
    mov si, InputBuffer
    mov di, CmdEditar
    mov cx, 6
    call compare_strings
    je executar_editor

    ; Compara com "limpar"
    mov si, InputBuffer
    mov di, CmdLimpar
    mov cx, 6
    call compare_strings
    je limpar_tela

    ; Se não encontrou
    mov si, MsgErroComando
    call print_string
    call print_barra_n
    jmp cli_loop

;------------------------------------------------------------------------------
; reiniciar
;------------------------------------------------------------------------------
reiniciar:
    mov si, MsgReiniciar
    call print_string

    ; Marca reboot e chama int 19h
    mov ax, 0x0040
    mov ds, ax
    mov word [0x0072], 0x1234
    int 19h

    ; Caso não reinicie, trava aqui
    jmp $

;------------------------------------------------------------------------------
; executar_editor
; Prepara o editor para ser executado, passando o nome do arquivo.
;------------------------------------------------------------------------------
executar_editor:

    ; Carrega o editor na memoria
    mov ah, 0x02
    mov al, EDITOR_TAM     
    mov ch, 0
    mov cl, SETOR_EDITOR     
    mov dh, 0
    mov dl, 0                ; Drive A:
    mov bx, 0x1000           ; ES:BX = 0x1000:0000
    mov es, bx
    xor bx, bx               ; bx <- 0
    int 0x13
    jc erro_leitura_gravacao

    ; Pula para o editor
    jmp 0x1000:0x0000

;------------------------------------------------------------------------------
; print_string
; Imprime string terminada em 0 (nulo)
;------------------------------------------------------------------------------
print_string:
.ps_loop:
    mov al, [si]
    cmp al, 0
    je .ps_done
    mov ah, 0x0E
    int 0x10
    inc si
    jmp .ps_loop
.ps_done:
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
; compare_strings
; Compara duas strings ate um determinado comprimento ou ate encontrar 0.
; Entrada:
;   SI -> String 1
;   DI -> String 2
;   CX -> Comprimento maximo de comparação (opcional)
; Saida:
;   ZF = 1 se as strings forem iguais
;------------------------------------------------------------------------------
compare_strings:
.cs_loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl          ; Compara os caracteres
    jne .cs_done        ; Se diferentes, sai
    cmp al, 0           ; Verifica se chegou ao fim
    je .cs_done         ; Se sim, termina
    inc si              ; Avança para o proximo caractere
    inc di
    loop .cs_loop       ; Repete ate atingir o limite em CX

    ; se chegou aqui, não houve diferenças e não encontrou 0. Logo, strings iguais ate o limite
    ; forçar ZF=1 manualmente
    cmp ax, ax          ; isso zera ax e seta ZF=1
.cs_done:
    ret

;------------------------------------------------------------------------------
; nova linha
;------------------------------------------------------------------------------
print_barra_n:
    mov ah, 0x0E
    mov al, 0x0D    ; CR: cursor na coluna 0
    int 0x10
    mov al, 0x0A    ; LF: cursor na linha seguinte
    int 0x10
    ret

;------------------------------------------------------------------------------
; limpar_tela
; Limpa a tela (int 0x10, função 0x06)
;------------------------------------------------------------------------------
limpar_tela:
    mov ah, 0x06
    mov al, 0         ; 0 indica que toda a janela sera preenchida
    mov bh, 0x0F      ; Atributo (cor de fundo/foreground)
    mov ch, 0         ; Linha inicial (0)
    mov cl, 0         ; Coluna inicial (0)
    mov dh, 24        ; ultima linha (por exemplo, 24 para 25 linhas)
    mov dl, 79        ; ultima coluna (79 para 80 colunas)
    int 0x10

    ; Reposiciona o cursor para o inicio
    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 0
    int 0x10
    ret

;------------------------------------------------------------------------------
; syscall_handler (int 0x80)
;------------------------------------------------------------------------------
syscall_handler:
    push ds          ; Salva o DS do chamador
    pusha
    ; troca DS para o segmento do kernel
    push cs
    pop ds


    ;mov si, MsgDegug
    ;call print_string

    cmp ax, 0x01
    je criar_arquivo

    cmp ax, 0x02
    je ler_arquivo
    ; Atualiza os valores salvos na pilha:
    ;mov word [esp], ax    ; atualiza o valor de retorno em AX
    ;mov word [esp+2], cx  ; atualiza o valor de retorno em CX (tamanho)
    ;jmp syscall_fim

    cmp ax, 0x03
    je gravar_arquivo

    cmp ax, 0x04
    je procurar_arquivo

    cmp ax, 0x05
    je listar_arquivos
    
    jmp syscall_fim

;------------------------------------------------------------------------------
; syscall_fim
;------------------------------------------------------------------------------
syscall_fim:
    popa
    pop ds         ; Restaura o DS original do chamador
    iret

;------------------------------------------------------------------------------
; carregar_DirRaiz
; in: 
; out: DiretorioBuffer na bx
;------------------------------------------------------------------------------
carregar_DirRaiz:
    mov ax, ds
    mov es, ax
    mov bx, DiretorioBuffer
    ;call limpar_buffer

    ; Le diretorio raiz
    mov ah, 0x02
    mov al, NumeroSetores
    mov ch, 0
    mov cl, SETOR_DIR_RAIZ  
    mov dh, 0
    mov dl, 0
    int 0x13
    jc erro_leitura_gravacao
    ret
    
;------------------------------------------------------------------------------
; criar_arquivo
;   in: SI -> nome do arquivo (11 bytes no maximo)
;   => cria entrada no diretorio com [SetorLivre]
;------------------------------------------------------------------------------
criar_arquivo:
    call carregar_DirRaiz          ; Carrega o diretorio para DiretorioBuffer

    ; O nome ja esta em DS:SI.
    mov bx, DiretorioBuffer
    xor di, di                   ; Inicializa DI para percorrer o DiretorioBuffer (base em BX)

.busca_espaco:
    cmp byte [bx+di], 0           ; Verifica se a entrada esta livre
    je .encontrou_espaco
    add di, DIRETORIO_ENTRY_SIZE  ; Avança para a proxima entrada
    cmp di, TAMANHO_SETOR
    jne .busca_espaco
    jmp erro_disco_cheio          ; Se não houver espaço, aborta

.encontrou_espaco:
    mov cx, 11                    ; Copia ate 11 bytes do nome
.copy_name:
    mov al, [si]                  ; Carrega o byte do nome
    inc si
    cmp al, 0
    je .fill_rest                ; Se encontrar fim da string, preenche o restante com 0
    mov [bx+di], al               ; Armazena o caractere no diretorio
    inc di
    loop .copy_name
    jmp .done_copy

.fill_rest:
    mov [bx+di], al               ; Al e 0, preenche a posição atual
    inc di
    loop .fill_rest

.done_copy:
    ; Zera o tamanho do arquivo (2 bytes)
    mov word [bx+di], 0
    add di, 2

    ; Define o setor inicial do arquivo
    mov ax, [SetorLivre]
    mov [bx+di], ax
    add di, 2

    ; Incrementa SetorLivre e verifica se ha espaço disponivel
    inc ax
    cmp ax, NUMERO_MAXIMO_SETORES
    jae erro_disco_cheio
    mov [SetorLivre], ax

    clc
    mov ax, ds
    mov es, ax
    mov bx, DiretorioBuffer
    ; Grava o diretorio raiz de volta no disco
    mov bx, DiretorioBuffer
    mov ah, 0x03
    mov al, NumeroSetores
    mov ch, 0
    mov cl, SETOR_DIR_RAIZ
    mov dh, 0
    mov dl, 0
    int 0x13
    jc .erro_disk
    jmp syscall_fim

.erro_disk:
    ;mov si, MsgErroGravacao
    ;call print_string
    mov ah, 0x0E                  ; Função para imprimir caractere
    mov al, ' '                   ; Espaço em branco
    int 0x10
    mov al, 'E'                   ; Letra 'E'
    int 0x10
    mov al, 'R'                   ; Letra 'R'
    int 0x10
    mov al, 'R'                   ; Letra 'R'
    int 0x10
    mov al, '='                   ; Sinal de igual
    int 0x10
    mov al, ah                    ; Imprime o codigo de erro
    add al, '0'                   ; Converte para ASCII
    int 0x10
    call print_barra_n
    jmp syscall_fim
    ;jmp $

;------------------------------------------------------------------------------
; print_buffer_9000
; Imprime os primeiros 512 bytes do buffer em 0x9000:0000.
;------------------------------------------------------------------------------
print_buffer_9000:
    ; Define DS=0x9000 para acessar o buffer
    push ax
    push bx
    push cx
    push si

    mov ax, 0x9000
    mov ds, ax
    xor si, si          ; SI=0 (offset inicial)

    mov cx, 512         ; Loop para 512 bytes
.print_loop:
    ; Imprime caractere atual
    mov al, [si]
    mov ah, 0x0E        ; Função para imprimir caractere na tela
    int 0x10            ; Chama a interrupção de video

    ; Avança para o proximo caractere
    inc si
    loop .print_loop

    ; Limpa a tela apos imprimir o buffer (opcional)
    call limpar_tela

    pop si
    pop cx
    pop bx
    pop ax
    ret

;------------------------------------------------------------------------------
; ler_arquivo
;  In: SI -> nome do arquivo
;  Out: Dados em BufferDadosSeg:BufferDadosOff
;       ax <- setor lido
;------------------------------------------------------------------------------
ler_arquivo:
    ;  - AX = offset da entrada no diretorio
    ;  - DX = setor inicial do arquivo
    ;  - Em DiretorioBuffer ta diretorio raiz
    call procurar_arquivo

    ; Recupera o offset do arquivo armazenado na entrada do diretorio.
    mov di, ax                   
    ; O tamanho esta armazenado nos bytes 11 e 12 da entrada.
    mov cx, [DiretorioBuffer + di + 11]    ; CX = tamanho do arquivo (2 bytes)
    mov [TamanhoArquivo], cx         ; Armazena o tamanho logico globalmente

    ;---------------------------------------------------------------------
    ; Limpa o buffer fixo de dados (localizado em BufferDadosSeg:BufferDadosOff)
    push ds
    mov ax, BufferDadosSeg           ; Define o segmento fixo
    mov es, ax
    mov bx, BufferDadosOff           ; Offset fixo (0)
    call limpar_buffer               ; Zera os 512 bytes do buffer
    pop ds
    ;---------------------------------------------------------------------

    ;---------------------------------------------------------------------
    ; Le o arquivo (1 setor) para o buffer fixo
    mov ah, 0x02                   
    mov al, NumeroSetores          ; Numero de setores a ler (1)
    mov ch, 0
    mov cl, dl                   ; CL recebe a parte baixa de DX (setor inicial)
    mov dh, 0
    mov dl, 0                    ; Drive A (0)
    ; Configura ES:BX para apontar para o buffer fixo
    mov ax, BufferDadosSeg
    mov es, ax
    mov bx, BufferDadosOff
    int 0x13
    jc erro_leitura_gravacao
    ;---------------------------------------------------------------------

    ; retorna o setor lido em AX
    mov ax, dx
    jmp syscall_fim

;------------------------------------------------------------------------------
; gravar_arquivo
; Convensão: Os dados do arquivo terminarão com um terminador
; AX=0x03
; SI -> nome arquivo
; DI -> buffer com dados
; Grava e atualiza tamanho no diretorio
;------------------------------------------------------------------------------
gravar_arquivo:
    ; Procurar o arquivo e checar se existe
    call procurar_arquivo
    ; Caso encontre arquivo: AX = offset da entrada; DX = setor inicial

    ; Escrever 1 setor no disco (do buffer 0x9000:0000)
    pusha
    mov ah, 0x03 
    mov al, NumeroSetores
    mov ch, 0
    mov cl, dl              ; CL = setor (parte baixa de DX)
    mov dh, 0
    mov dl, 0               ; Drive A:

    mov ax, 0x9000          ; Segmento do buffer fixo
    mov es, ax
    xor bx, bx              ; Offset 0x0000
    int 0x13
    jc erro_leitura_gravacao
    popa

    ; Calcular o tamanho logico do arquivo, escaneando o buffer
    ;          ate o terminador 0 ou ate 512 bytes.
    pusha
    mov ax, 0x9000
    mov ds, ax
    xor si, si              ; SI = 0
.find_terminator:
    mov al, [si]
    cmp al, 0               ; encontrou terminador
    je .found
    inc si
    cmp si, 512             ; limite maximo de 1 setor
    jne .find_terminator
    ; Se chegar aqui, atingiu 512 sem achar terminador
    ; Considerar arquivo com 512 bytes
    mov si, 512
.found:
    mov [TamanhoArquivo], si ; SI contem o tamanho logico
    popa

    ; Carregar o diretorio raiz, atualizar o tamanho no campo da entrada
    ;          e gravar de volta.
    call carregar_DirRaiz    ; Agora DiretorioBuffer tem o diretorio
    mov bx, DiretorioBuffer
    
    mov di, ax               ; AX = offset salvo por procurar_arquivo
    add di, 11               ; pula os 11 bytes de nome

    mov ax, [TamanhoArquivo] ; tamanho logico
    mov [bx + di], ax        ; grava 2 bytes de tamanho na entrada

    ; Grava o diretorio (1 setor) de volta para o disco
    mov ah, 0x03           
    mov al, NumeroSetores
    mov ch, 0
    mov cl, SETOR_DIR_RAIZ  
    mov dh, 0
    mov dl, 0               ; Drive A:
    int 0x13
    jc erro_leitura_gravacao

    jmp syscall_fim

;------------------------------------------------------------------------------
; listar_arquivos
;------------------------------------------------------------------------------
listar_arquivos:
    ; Carregar o diretorio raiz no buffer DiretorioBuffer
    call carregar_DirRaiz
    mov bx, DiretorioBuffer
    
    cld  
    mov si, DiretorioBuffer      ; Origem
    push es
    mov ax, BufferDadosSeg             ; Define o segmento de destino
    mov es, ax
    xor di, BufferDadosOff      ; Offset 0x0000 no segmento 0x9000
    mov cx, 256                ; 512 bytes / 2 = 256 palavras (word)
    rep movsw                  ; Copia CX palavras de [DS:SI] para [ES:DI]
    pop es
    jmp syscall_fim


;------------------------------------------------------------------------------
; print_filename
; Imprime ate 11 bytes ou ate encontrar byte 0
;------------------------------------------------------------------------------
print_filename:
.pf_loop:
    cmp cx, 0
    je .pf_done
    mov al, [si]
    cmp al, 0
    je .pf_done
    mov ah, 0x0E
    int 0x10
    inc si
    loop .pf_loop
.pf_done:
    ret

;------------------------------------------------------------------------------
; Incializar diretorio raiz com 0s
;------------------------------------------------------------------------------
inicializar_dir_raiz:
    mov bx, DiretorioBuffer
    mov cx, 512
    xor al, al
.loop:
    mov [bx], al
    inc bx
    loop .loop
    ; Grava o buffer zerado no setor 2
    mov ah, 0x03
    mov al, NumeroSetores
    mov ch, 0
    mov cl, SETOR_DIR_RAIZ
    mov dh, 0
    mov dl, 0
    int 0x13
    ret
;------------------------------------------------------------------------------
; procurar_arquivo
; in: nome do arquivo em SI
; out: ax <- offset do arquivo em diretorio raiz
;      dx <- setor do arquivo
;------------------------------------------------------------------------------
procurar_arquivo:
    pusha

    ; Carrega diretorio para DiretorioBuffer
    call carregar_DirRaiz
    mov bx, DiretorioBuffer
    
    ; DI percorre entradas no buffer
    xor di, di
.find_loop:
    mov cx, 11          ; tamanho do nome do arquivo
    push di
    push si            ; Salva o ponteiro para o nome a ser buscado
.cmp_name:
    mov al, [si]        ; Pega o caractere do nome procurado
    mov bl, [bx+di]     ; Pega o caractere da entrada atual no diretorio
    cmp al, bl
    jne .not_match
    cmp al, 0           ; Se chegou ao fim do nome (caractere nulo)
    je .match_end
    inc si
    inc di
    loop .cmp_name

.match_end:
    pop si
    pop di              ; recupera o offset original da entrada
    mov [EntryPtr], di  ; salva o offset
    popa
    ; AX <- offset da entrada
    ; DX <- setor inicial lido do diretorio raiz (na posição: DiretorioBuffer + EntryPtr + 13)
    mov ax, [EntryPtr]          ; AX = offset da entrada
    mov bx, DiretorioBuffer     ; Aqui o DiretorioBuffer e o diretorio raiz
    add bx, ax                ; BX = DiretorioBuffer + offset da entrada
    add bx, 13                ; BX agora aponta para o campo do setor inicial (bytes 13 e 14)
    mov dx, [bx]              ; DX = setor inicial do arquivo
    mov ax, [EntryPtr]        ; AX = offset da entrada (se assim desejar)
    ret

.not_match:
    pop si
    pop di
    add di, DIRETORIO_ENTRY_SIZE    ; salta cabeçalho do arquivo analisado
    cmp di, 512                    ; verifica se chegou ao fim do setor do diretorio raiz
    jne .find_loop                 
    xor ax, ax                      ; se chegou ao fim sem achar o arquivo, ativa flag ZF
    call erro_arquivo_nao_encontrado
    popa
    ret

;------------------------------------------------------------------------------
; limpar_buffer
; in: buffer em bx
; out: buffer com 512 0's
;------------------------------------------------------------------------------
limpar_buffer:
    mov cx, TAMANHO_SETOR
    xor ax, ax
.lb_loop:
    mov [bx], ax   ; grava word = 0
    add bx, 2
    loop .lb_loop
    ret

;------------------------------------------------------------------------------
; importante para salvar o nome do arquivo em di
; in: nome em si
; out: nome em di
;------------------------------------------------------------------------------
copiar_string:
.cs_loop:
    mov al, [si]         ; Le um byte da fonte (SI)
    mov [di], al         ; Copia o byte para o destino (DI)
    inc si               ; Incrementa SI para o proximo caractere
    inc di               ; Incrementa DI para o proximo caractere
    cmp al, 0            ; Verifica se encontrou o terminador nulo (0)
    jne .cs_loop         ; Se não encontrou, continua copiando
    ret

;------------------------------------------------------------------------------
; erro_arquivo_nao_encontrado
;------------------------------------------------------------------------------
erro_arquivo_nao_encontrado:
    mov si, MsgErroArquivoNaoEncontrado
    call print_string
    jmp syscall_fim

;------------------------------------------------------------------------------
; erro_disco_cheio
;------------------------------------------------------------------------------
erro_disco_cheio:
    mov si, MsgErroDiscoCheio
    call print_string
    jmp syscall_fim

;------------------------------------------------------------------------------
; erro_leitura_gravacao
;------------------------------------------------------------------------------
erro_leitura_gravacao:
    mov si, MsgErroGravacao
    call print_string
    ret


;------------------------------------------------------------------------------
; Dados, Buffers e Variaveis
;------------------------------------------------------------------------------

Prompt                  db '> ', 0
CmdReiniciar            db 'reiniciar', 0
CmdEditar             db 'editar', 0
MsgErroComando          db 'Comando desconhecido.', 0
MensagemInicial         db 'Nosso primeiro SO', 0
MsgReiniciar            db 'Reiniciando o sistema...', 0
CmdLimpar               db 'limpar', 0

MsgErroGravacao         db 'Erro de leitura/gravacao.', 0
MsgErroArquivoNaoEncontrado db 'Erro: Arquivo nao encontrado.', 0
MsgErroDiscoCheio       db 'Erro: Disco cheio.', 0
MsgDegug                db 'Aqui', 0

; Buffer para input do CLI
InputBuffer             db 512 dup(0)

; Buffer para diretorio e dados
DiretorioBuffer         db 512 dup(0)

; Variaveis globais para lidar com o nome do arquivo
kernel_filename_buffer  times 12 db 0  ; Buffer para armazenar o nome do arquivo (11 bytes + terminador)
caller_ds               dw 0           ; Variavel para armazenar o DS do editor

; Variaveis
SetorLivre              dw 2
EntryPtr                dw 0
TamanhoArquivo          dw 0  

; constantes
NumeroSetores EQU 1         ;todo arquivo ocupara sempre apenas 1 setor (512 bytes)

; Endereço fixo compartilhado para o buffer de dados
BufferDadosSeg  EQU 0x9000   ; segmento fixo (0x9000)
BufferDadosOff  EQU 0x0000   ; offset fixo dentro do segmento

; Endereço fixo compartilhado para o nome do arquivo
;%define FileNameSeg  0x8000   ; segmento fixo para o nome do arquivo
;%define FileNameOff  0x0000   ; offset fixo dentro desse segmento (pode ser 0)

times 2560 - ($ - $$) db 0
