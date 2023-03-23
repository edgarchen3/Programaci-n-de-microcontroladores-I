#include <stdio.h>

int main() {
    /*int a, b, suma;

    printf("Ingrese dos numeros enteros separados por un espacio: ");
    scanf("%d %d", &a, &b);
    suma = a + b;
    printf("La suma de %d y %d es %d\n", a, b, suma);
    */

    float t, toCelcius;

    printf("Ingrese la temperatura en grados Fahrenheit: ");
    scanf("%f", &t);
    toCelcius = ( (float) 5/9)*(t-32);
    printf("La temperatura en grados Celcius es %f\n", toCelcius);

    return 0;
}