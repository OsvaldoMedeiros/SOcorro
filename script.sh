#!/bin/bash
set -x  # Habilitar modo de debug para mostrar comandos e saídas

clear

# Detectar o sistema operacional
if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
    # Linux ou macOS
    rm -f kernel.bin editor.bin bootloader.bin disk.img
elif [[ "$OS" == "Windows_NT" ]]; then
    # Windows (CMD/PowerShell)
    powershell.exe Remove-Item kernel.bin, editor.bin, bootloader.bin, disk.img -Force
fi


# Compilação dos arquivos assembly
nasm -f bin bootloader.asm -o bootloader.bin
nasm -f bin kernel.asm -o kernel.bin
nasm -f bin editor.asm -o editor.bin

# Criação da imagem de disco (2880 blocos de 512 bytes)
dd if=/dev/zero of=disk.img bs=512 count=2880

# Copiar o bootloader para o setor 0 (MBR)
dd if=bootloader.bin of=disk.img bs=512 count=1 seek=0 conv=notrunc

# Zerar o setor 1
dd if=/dev/zero of=disk.img bs=512 count=1 seek=1 conv=notrunc

# Copiar o kernel para a imagem (a partir do setor 2, 5 setores)
dd if=kernel.bin of=disk.img bs=512 count=5 seek=2 conv=notrunc

# Copiar o editor para a imagem (a partir do setor 7, 5 setores)
dd if=editor.bin of=disk.img bs=512 count=5 seek=7 conv=notrunc

# Executar a imagem no QEMU (modo disquete)
qemu-system-i386 -fda disk.img
