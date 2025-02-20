# Guia de Compilação e Execução

## Baixar Dependências
Instale o **NASM** e o **QEMU**

##Verificar o Tamanho do Arquivo

Para checar o tamanho do kernel compilado:
```
ls -l kernel.bin
```
## Compilação dos Arquivos

Compile o bootloader, kernel e editor:
```
nasm -f bin bootloader.asm -o bootloader.bin
nasm -f bin kernel.asm -o kernel.bin
nasm -f bin editor.asm -o editor.bin
```
## Gerar Imagem de Disco e Registrar os Arquivos

Crie a imagem do disco e grave os arquivos:

```
dd if=/dev/zero of=disk.img bs=512 count=2880
dd if=bootloader.bin of=disk.img bs=512 count=1 seek=0 conv=notrunc
dd if=kernel.bin of=disk.img bs=512 count=5 seek=2 conv=notrunc
dd if=editor.bin of=disk.img bs=512 count=3 seek=7 conv=notrunc
```
## Executar no QEMU

Inicie a imagem no emulador:
```
qemu-system-i386 -fda disk.img
```

