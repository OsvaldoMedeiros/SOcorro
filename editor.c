#include <stdio.h>
#include <termios.h>
#include <unistd.h>

// Função para configurar o terminal (desativar eco e buffer de linha)
void configureTerminal() {
    struct termios term;
    tcgetattr(STDIN_FILENO, &term);
    term.c_lflag &= ~(ECHO | ICANON); // Desativa eco e buffer de linha
    tcsetattr(STDIN_FILENO, TCSANOW, &term);
}

// Função para restaurar o terminal ao estado original
void restoreTerminal() {
    struct termios term;
    tcgetattr(STDIN_FILENO, &term);
    term.c_lflag |= (ECHO | ICANON); // Reativa eco e buffer de linha
    tcsetattr(STDIN_FILENO, TCSANOW, &term);
}

int main() {
    int enter_count = 0; // Contador de enters consecutivos
    char c;
    char buffer[1000]; // Buffer para armazenar o texto
    int index = 0; // Índice atual no buffer

    printf("Editor de Texto Simples. Pressione Enter 5 vezes seguidas para sair.\n");

    // Configura o terminal
    configureTerminal();

    while (1) {
        c = getchar(); // Lê um caractere da entrada

        // Trata o backspace (ASCII 8 ou '\b')
        if (c == 127 || c == 8) { // 127 é o código ASCII para backspace no Linux/Mac, 8 no Windows
            if (index > 0) { // Se houver caracteres para apagar
                index--; // Move o índice para trás
                printf("\b \b"); // Apaga o caractere na tela
            }
        }
        // Trata o Enter ('\n')
        else if (c == '\n') {
            enter_count++; // Incrementa o contador de enters
            buffer[index++] = '\n'; // Adiciona uma nova linha ao buffer
            putchar('\n'); // Exibe uma nova linha na tela
        }
        // Trata outros caracteres
        else {
            enter_count = 0; // Reseta o contador de enters
            buffer[index++] = c; // Adiciona o caractere ao buffer
            putchar(c); // Exibe o caractere na tela
        }

        // Verifica se houve 5 enters consecutivos
        if (enter_count == 5) {
            printf("\n5 enters consecutivos detectados. Encerrando o editor...\n");
            break;
        }

        // Limita o buffer para evitar estouro
        if (index >= sizeof(buffer) - 1) {
            printf("\nLimite de tamanho do texto atingido. Encerrando o editor...\n");
            break;
        }
    }

    // Restaura o terminal ao estado original
    restoreTerminal();

    // Exibe o conteúdo final do buffer (opcional)
    printf("\nConteúdo digitado:\n%s\n", buffer);

    return 0;
}
