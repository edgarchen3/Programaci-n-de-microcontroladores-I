#include <stdio.h>

int main() {
    /*int i;

    for (i = 1; i <= 10; i++) {
        printf("%d", i);
    }*/
    

    int i, n1 = 1, n2 = 1, nextTerm, N;

    printf("Enter the number of terms of the Fibonacci's serie: ");
    scanf("%d", &N);

    printf("The N terms of the Fibonacci's serie are:\n");

    for (i = 1; i <= N; i++) {
        printf("%d\n", n1);
        nextTerm = n1 + n2;
        n1 = n2;
        n2 = nextTerm;
    }

    return 0;
}