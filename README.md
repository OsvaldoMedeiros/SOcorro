Claro! Aqui está o **passo a passo completo** em Markdown para converter os códigos `.asm` para serem compatíveis com o **MASM 6.14**, compilar e executar a imagem do disquete no **DOSBox**.

---

## Passo a Passo: Converter, Compilar e Executar no MASM 6.14

### 1. Preparar o Ambiente
1. **Instale o MASM 6.14:**
   - Baixe e instale o **MASM 6.14** (disponível em sites de arquivos históricos ou retrocomputação).
   - Configure o ambiente para usar o MASM (adicione o caminho do MASM à variável de ambiente `PATH`).

2. **Instale o DOSBox:**
   - Baixe e instale o **DOSBox** a partir do site oficial: [https://www.dosbox.com/](https://www.dosbox.com/).

---

### 2. Converter os Códigos para MASM 6.14

#### Bootloader (`bootloader.asm`):
```asm
; Bootloader.asm
; Compatível com MASM 6.14

.model small
.stack 100h
.code

org 7C00h  ; Define o endereço de origem como 7C00h

start:
    ; Inicialização da pilha
    mov ax, 07C0h
    mov ss, ax
    mov sp, 03FEh

    ; Configuração do segmento de dados
    xor ax, ax
    mov ds, ax

    ; Alterar o modo de vídeo
    mov ah, 00h
    mov al, 03h
    int 10h

    ; Ler dados do disquete (setor 2)
    mov ah, 02h
    mov al, 1
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 0
    mov bx, 0800h
    mov es, bx
    mov bx, 0
    int 13h

    ; Pular para o kernel
    jmp 0800h:0000h

    ; Preencher o restante do setor de boot
    db 510-($-start) dup(0)  ; Preenche com zeros
    dw 0xAA55  ; Assinatura de bootloader

end start
```

#### Kernel (`kernel.asm`):
```asm
; Kernel.asm
; Compatível com MASM 6.14

.model small
.stack 100h
.code

org 0000h  ; Define o endereço de origem como 0000h

start:
    push cs
    pop ds
    call clearscreen

    lea si, Mensagem
    mov ah, 0Eh
repetição:
    mov al, [si]
    cmp al, 0h
    jz terminou
    int 10h
    inc si
    jmp repetição

terminou:
    mov ah, 0h
    int 16h
    mov ax, 0040h
    mov ds, ax
    mov word ptr [0072h], 1234h
    jmp 0FFFFh:0000h

clearscreen proc
    pusha
    mov ah, 06h
    mov al, 0
    mov bh, 0000_1111b
    mov ch, 0
    mov cl, 0
    mov dh, 19h
    mov dl, 50h
    int 10h
    popa
    ret
clearscreen endp

Mensagem db 'Meu primeiro SO', 0

end start
```

---

### 3. Compilar os Códigos com o MASM 6.14

1. **Compilar o Bootloader:**
   - Abra o prompt de comando no diretório onde está o arquivo `bootloader.asm`.
   - Execute o seguinte comando:
     ```bash
     ml /c bootloader.asm
     ```
   - Isso gerará um arquivo `bootloader.obj`.

2. **Gerar o Binário do Bootloader:**
   - Execute o seguinte comando para gerar o binário:
     ```bash
     link /Tiny bootloader.obj
     ```
   - Isso criará um arquivo `bootloader.exe`. Renomeie-o para `bootloader.bin`:
     ```bash
     ren bootloader.exe bootloader.bin
     ```

3. **Compilar o Kernel:**
   - No mesmo diretório, compile o arquivo `kernel.asm`:
     ```bash
     ml /c kernel.asm
     ```
   - Isso gerará um arquivo `kernel.obj`.

4. **Gerar o Binário do Kernel:**
   - Execute o seguinte comando para gerar o binário:
     ```bash
     link /Tiny kernel.obj
     ```
   - Isso criará um arquivo `kernel.exe`. Renomeie-o para `kernel.bin`:
     ```bash
     ren kernel.exe kernel.bin
     ```

---

### 4. Criar a Imagem do Disquete

1. **Criar uma Imagem de Disquete Vazia:**
   - Use o comando `dd` (disponível no Linux ou Windows com ferramentas como Git Bash ou WSL):
     ```bash
     dd if=/dev/zero of=floppy.img bs=512 count=2880
     ```

2. **Copiar o Bootloader para a Imagem:**
   - Copie o binário do bootloader para o início da imagem:
     ```bash
     dd if=bootloader.bin of=floppy.img conv=notrunc
     ```

3. **Copiar o Kernel para a Imagem:**
   - Copie o binário do kernel para o setor 2 da imagem:
     ```bash
     dd if=kernel.bin of=floppy.img bs=512 seek=1 conv=notrunc
     ```

---

### 5. Executar no DOSBox

1. **Iniciar o DOSBox:**
   - Abra o DOSBox.

2. **Montar a Imagem do Disquete:**
   - Monte a imagem `floppy.img` como unidade `A:`:
     ```bash
     imgmount a floppy.img -t floppy
     ```

3. **Iniciar o Sistema:**
   - Acesse a unidade `A:` e execute o bootloader:
     ```bash
     a:
     boot
     ```

---

### 6. Resultado Esperado
- O **bootloader** será carregado e executado.
- Ele carregará o **kernel** do setor 2 e passará a execução para ele.
- O **kernel** limpará a tela e exibirá a mensagem **"Meu primeiro SO"**.
- O sistema aguardará uma tecla ser pressionada e, em seguida, reiniciará.

---

### Dicas Adicionais
- Se você quiser automatizar a montagem da imagem e a execução no DOSBox, adicione as seguintes linhas ao arquivo de configuração do DOSBox (`dosbox.conf`):
  ```ini
  [autoexec]
  imgmount a floppy.img -t floppy
  a:
  boot
  ```

- Certifique-se de que os binários gerados (`bootloader.bin` e `kernel.bin`) estejam corretamente alinhados e tenham o tamanho adequado.

---

Pronto! Agora você tem um sistema operacional básico rodando no DOSBox usando o MASM 6.14. Se precisar de mais ajuda, é só perguntar! 😊
