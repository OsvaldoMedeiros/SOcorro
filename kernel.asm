bits 16
org 0x0000   ; Endereço de carregamento (depende do bootloader!)

;------------------------------------------------------------------------------
; Estrutura de Diretório (15 bytes por entrada):
;   0..10:  Nome (11 bytes)
;   11..12: Tamanho (2 bytes)
;   13..14: Setor inicial (2 bytes)
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;  Estrutura de setores
;   boot - setor 0
;   diretorio raiz - setor 1
;   kernel - setor 2...6
;   editor - setor 7...9
;   arquivos - setor 10...
;------------------------------------------------------------------------------

%define DIRETORIO_ENTRY_SIZE 15
%define TAMANHO_SETOR        512
%define NUMERO_MAXIMO_SETORES 2880
%define EDITOR_TAM 3
%define SETOR_EDITOR 8  ; BIOS conta começando em 1, em vez de 0 (uso nas int)
%define SETOR_DIR_RAIZ 2    ;diretório raiz (armazena nome, tamanho e setor inicial dos arquivos)
%define SETOR_LIVRE_PRIM 11


;------------------------------------------------------------------------------
; Início (ponto de entrada)
;------------------------------------------------------------------------------
start:
    ; DS = CS
    push cs
    pop ds

    call limpar_tela

    ; Mensagem inicial
    mov si, MensagemInicial
    call print_string
    call print_barra_n

    ; Inicializa variáveis
    mov word [SetorLivre], SETOR_LIVRE_PRIM 
    
    ; Configura vetor de funções da int 0x80
    mov ax, 0x0000
    mov es, ax
    mov word [es:(0x80*4)], syscall_handler
    mov word [es:(0x80*4+2)], cs

;------------------------------------------------------------------------------
; cli_loop
; Loop para ler comandos do usuário e executar
;------------------------------------------------------------------------------
cli_loop:
    mov si, Prompt
    call print_string

    ; Lê comando
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

    ; Carrega o editor na memória
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
    pusha
.ps_loop:
    mov al, [si]
    cmp al, 0
    je .ps_done
    mov ah, 0x0E
    int 0x10
    inc si
    jmp .ps_loop
.ps_done:
    popa
    ret

;------------------------------------------------------------------------------
; ler_linha
; Lê uma linha do teclado e armazena em InputBuffer (termina com byte 0)
;------------------------------------------------------------------------------
ler_linha:
    pusha
.ll_loop:
    mov ah, 0
    int 16h

    cmp al, 0Dh  ; Enter?
    je .fim_leitura

    cmp al, 08h  ; Backspace?
    je .backspace

    ; Imprime e armazena
    mov ah, 0x0E
    int 0x10
    mov [di], al
    inc di
    jmp .ll_loop

.backspace:
    cmp di, InputBuffer  ; Verifica se já estamos no início do buffer
    je .ll_loop          ; Se sim, ignora o backspace

    mov ah, 0x03         ; obter a posicao do cursor
    xor bh, bh           ; Página de vídeo 0
    int 0x10             

    cmp dl, 0            ; Verifica se estamos na coluna 0
    jne .apagar_caractere ; Se não estamos na coluna 0, apaga o caractere
    ; Se estamos na coluna 0, precisamos ajustar a linha
    cmp dh, 0            ; Verifica se estamos na primeira linha
    je .ll_loop; Se estamos na primeira linha, não fazemos nada
    jmp .ajustar_linha   ; Caso contrário, ajustamos a linha

.ajustar_linha:
    mov dl, 79           ; Vai para a última coluna da linha anterior
    dec dh               ; Decrementa a linha atual
    jmp .ajustar_cursor  ; Ajusta o cursor

.apagar_caractere:
    dec dl               ; Move o cursor para trás, decrementando a coluna
    
.ajustar_cursor:
    mov ah, 0x02         
    xor bh, bh           ; Página de vídeo 0
    int 0x10             ; Chama a interrupção BIOS

    ; Atualiza o buffer
    dec di               ; Retrocede a posição no buffer
    mov byte [di], 0     ; Limpa o caractere removido

    jmp .ll_loop         ; Volta ao loop principal

.fim_leitura:
    mov byte [di], 0  ; fecha string com 0
    popa
    ret

;------------------------------------------------------------------------------
; compare_strings
; Compara duas strings até um determinado comprimento ou até encontrar 0.
; Entrada:
;   SI -> String 1
;   DI -> String 2
;   CX -> Comprimento máximo de comparação (opcional)
; Saída:
;   ZF = 1 se as strings forem iguais
;------------------------------------------------------------------------------
compare_strings:
    pusha
.cs_loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl          ; Compara os caracteres
    jne .cs_done        ; Se diferentes, sai
    cmp al, 0           ; Verifica se chegou ao fim
    je .cs_done         ; Se sim, termina
    inc si              ; Avança para o próximo caractere
    inc di
    loop .cs_loop       ; Repete até atingir o limite em CX

    ; se chegou aqui, não houve diferenças e não encontrou 0. Logo, strings iguais até o limite
    ; forçar ZF=1 manualmente
    cmp ax, ax          ; isso zera ax e seta ZF=1
.cs_done:
    popa
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
    pusha
    mov ah, 0x06
    mov al, 0         ; 0 indica que toda a janela será preenchida
    mov bh, 0x0F      ; Atributo (cor de fundo/foreground)
    mov ch, 0         ; Linha inicial (0)
    mov cl, 0         ; Coluna inicial (0)
    mov dh, 24        ; Última linha (por exemplo, 24 para 25 linhas)
    mov dl, 79        ; Última coluna (79 para 80 colunas)
    int 0x10

    ; Reposiciona o cursor para o início
    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 0
    int 0x10
    popa
    ret

;------------------------------------------------------------------------------
; syscall_handler (int 0x80)
;------------------------------------------------------------------------------
syscall_handler:
    pusha

    cmp ax, 0x01
    je criar_arquivo

    cmp ax, 0x02
    je ler_arquivo
    ; Atualiza os valores salvos na pilha:
    mov word [esp], ax    ; atualiza o valor de retorno em AX
    mov word [esp+2], cx  ; atualiza o valor de retorno em CX (tamanho)
    jmp syscall_fim

    cmp ax, 0x03
    je gravar_arquivo

    cmp ax, 0x04
    je procurar_arquivo
    
    jmp syscall_fim

;------------------------------------------------------------------------------
; syscall_fim
;------------------------------------------------------------------------------
syscall_fim:
    popa
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
    call limpar_buffer

    ; Lê diretório raiz
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
;   in: SI -> nome do arquivo (11 bytes no máximo)
;   => cria entrada no diretório com [SetorLivre]
;------------------------------------------------------------------------------
criar_arquivo:
    ; Carrega diretorio raiz para DiretorioBuffer
    call carregar_DirRaiz

    ; DI percorre entradas no buffer
    xor di, di
.busca_espaco:
    cmp byte [bx+di], 0         ; Primeiro byte = 0 (entrada livre)
    je .verifica_entrada_vazia  ; Verifica os próximos bytes
    add di, DIRETORIO_ENTRY_SIZE
    cmp di, TAMANHO_SETOR
    jb .busca_espaco

.verifica_entrada_vazia:
    ; Verifica se todos os 11 bytes do nome estão zerados
    mov cx, 11
    mov si, di
.verifica_loop:
    cmp byte [bx+si], 0
    jne .busca_espaco           ; Não está vazia, continua busca
    inc si
    loop .verifica_loop
    ; Se chegou aqui, a entrada está realmente vazia
    jmp .encontrou

.encontrou:
    mov cx, 11

; Copia o nome de arquivo (SI) para [bx+di]
.copy_name:
    mov al, [si]
    mov [bx+di], al
    inc si
    inc di
    loop .copy_name

; Zera tamanho (2 bytes)
    mov word [bx+di], 0
    add di, 2

; Define setor inicial <- [SetorLivre]
    mov ax, [SetorLivre]
    mov [bx+di], ax
    add di, 2

; Atualiza SetorLivre. Cada arquivo ocupa 1 setor apenas.
    mov ax, [SetorLivre]
    inc ax
    cmp ax, NUMERO_MAXIMO_SETORES
    jae erro_disco_cheio
    mov [SetorLivre], ax

    ; Grava o diretório raiz
    mov ah, 0x03
    mov al, SETOR_DIR_RAIZ
    mov ch, 0
    mov cl, 1
    mov dh, 0
    mov dl, 0
    int 0x13
    jc erro_leitura_gravacao

    jmp syscall_fim

;------------------------------------------------------------------------------
; ler_arquivo
;  In: SI -> nome do arquivo
;  Out: Dados em BufferDadosSeg:BufferDadosOff
;       ax <- setor lido
;------------------------------------------------------------------------------
ler_arquivo:
    ;  - AX = offset da entrada no diretório
    ;  - DX = setor inicial do arquivo
    ;  - Em DiretorioBuffer ta diretorio raiz
    call procurar_arquivo

    ; Recupera o offset do arquivo armazenado na entrada do diretório.
    mov di, ax                   
    ; O tamanho está armazenado nos bytes 11 e 12 da entrada.
    mov cx, [DiretorioBuffer + di + 11]    ; CX = tamanho do arquivo (2 bytes)
    mov [TamanhoArquivo], cx         ; Armazena o tamanho lógico globalmente

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
    ; Lê o arquivo (1 setor) para o buffer fixo
    mov ah, 0x02                   
    mov al, NumeroSetores          ; Número de setores a ler (1)
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
; Convensão: Os dados do arquivo terminarão com um terminador!
; AX=0x03
; SI -> nome arquivo
; DI -> buffer com dados
; Grava e atualiza tamanho no diretório
;------------------------------------------------------------------------------
gravar_arquivo:
    ; Procurar o arquivo e checar se existe
    call procurar_arquivo
    ; Caso encontre arquivo: AX = offset da entrada; DX = setor inicial

    ; Escrever 1 setor no disco (do buffer 0x9000:0000)
    pusha
    mov ah, 0x03            ; int 0x13, função de escrita (Write Sectors)
    mov al, 1               ; 1 setor
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

    ; Calcular o tamanho lógico do arquivo, escaneando o buffer
    ;          até o terminador 0 ou até 512 bytes.
    pusha
    mov ax, 0x9000
    mov ds, ax
    xor si, si              ; SI = 0
.find_terminator:
    mov al, [si]
    cmp al, 0               ; encontrou terminador?
    je .found
    inc si
    cmp si, 512             ; limite máximo de 1 setor
    jne .find_terminator
    ; Se chegar aqui, atingiu 512 sem achar terminador
    ; Considerar arquivo com 512 bytes
    mov si, 512
.found:
    mov [TamanhoArquivo], si ; SI contém o tamanho lógico
    popa

    ; Carregar o diretório raiz, atualizar o tamanho no campo da entrada
    ;          e gravar de volta.
    call carregar_DirRaiz    ; Agora DiretorioBuffer tem o diretório
    mov di, ax               ; AX = offset salvo por procurar_arquivo
    add di, 11               ; pula os 11 bytes de nome

    mov bx, DiretorioBuffer
    mov ax, [TamanhoArquivo] ; tamanho lógico
    mov [bx + di], ax        ; grava 2 bytes de tamanho na entrada

    ; Grava o diretório (1 setor) de volta para o disco
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
; procurar_arquivo
; in: nome do arquivo em SI
; out: ax <- offset do arquivo em diretorio raiz
;      dx <- setor do arquivo
;------------------------------------------------------------------------------
procurar_arquivo:
    pusha

    ; Carrega diretorio para DiretorioBuffer
    call carregar_DirRaiz

    ; DI percorre entradas no buffer
    xor di, di
.find_loop:
    mov cx, 11          ; tamanho do nome do arquivo
    push di
    push si            ; Salva o ponteiro para o nome a ser buscado
.cmp_name:
    mov al, [si]        ; Pega o caractere do nome procurado
    mov bl, [bx+di]     ; Pega o caractere da entrada atual no diretório
    cmp al, bl
    jne .not_match
    cmp al, 0           ; Se chegou ao fim do nome (caractere nulo)
    je .match_end
    inc si
    inc di
    loop .cmp_name

.match_end:
    pop di              ; recupera o offset original da entrada
    mov [EntryPtr], di  ; salva o offset
    popa  
    ; AX <- offset da entrada
    ; DX <- setor inicial lido do diretório raiz (na posição: DiretorioBuffer + EntryPtr + 13)
    mov ax, [EntryPtr]          ; AX = offset da entrada
    mov bx, DiretorioBuffer     ; Aqui o DiretorioBuffer é o diretorio raiz
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
    pusha
    mov cx, TAMANHO_SETOR
    xor ax, ax
.lb_loop:
    mov [bx], ax   ; grava word = 0
    add bx, 2
    loop .lb_loop
    popa
    ret

;------------------------------------------------------------------------------
; importante para salvar o nome do arquivo em di
; in: nome em si
; out: nome em di
;------------------------------------------------------------------------------
copiar_string:
    pusha
.cs_loop:
    mov al, [si]         ; Lê um byte da fonte (SI)
    mov [di], al         ; Copia o byte para o destino (DI)
    inc si               ; Incrementa SI para o próximo caractere
    inc di               ; Incrementa DI para o próximo caractere
    cmp al, 0            ; Verifica se encontrou o terminador nulo (0)
    jne .cs_loop         ; Se não encontrou, continua copiando
    popa
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
    jmp cli_loop

;------------------------------------------------------------------------------
; Dados, Buffers e Variáveis
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

; Buffer para input do CLI
InputBuffer             db 512 dup(0)

; Buffer para diretório e dados
DiretorioBuffer         db 512 dup(0)

; Variáveis
SetorLivre              dw 2
EntryPtr                dw 0
TamanhoArquivo          dw 0  

; constantes
NumeroSetores EQU 1         ;todo arquivo ocupará sempre apenas 1 setor (512 bytes)

; Endereço fixo compartilhado para o buffer de dados
BufferDadosSeg  EQU 0x9000   ; segmento fixo (0x9000)
BufferDadosOff  EQU 0x0000   ; offset fixo dentro do segmento

; Endereço fixo compartilhado para o nome do arquivo
%define FileNameSeg  0x8000   ; segmento fixo para o nome do arquivo
%define FileNameOff  0x0000   ; offset fixo dentro desse segmento (pode ser 0)

times 2560 - ($ - $$) db 0
