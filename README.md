baixar:
nasm e qemu-system-x86

verificar tamanho:
 ls -l kernel4.bin

execução:
nasm -f bin bootloader.asm -o bootloader.bin
nasm -f bin kernel.asm -o kernel.bin
nasm -f bin editor.asm -o editor.bin


dd if=/dev/zero of=disk.img bs=512 count=2880
dd if=bootloader.bin of=disk.img bs=512 count=1 seek=0 conv=notrunc
dd if=kernel.bin of=disk.img bs=512 count=5 seek=2 conv=notrunc
dd if=editor.bin of=disk.img bs=512 count=3 seek=7 conv=notrunc

qemu-system-i386 -fda disk.img
