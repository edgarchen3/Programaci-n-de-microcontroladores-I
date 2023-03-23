#include <stdio.h>

int main() {
    int N = 10;
    int *p1; 

    int myArray[N];

    for (int i = 0; i < N; i++) {
        printf("Enter your integer: ");
        scanf("%d", &myArray[i]);
    }

    printf("The elements multiplied by 2 are:\n");
    p1 = &myArray[0];

    for (int i = 0; i < N; i++) {
        *p1 *= 2;
        printf("%d\n", *p1);
        p1++;
    }

    return 0;
}