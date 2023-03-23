#include <stdio.h>
#include "add.h"

int main() {
    
    int a, b;
    printf("Enter two numbers separated by a space: ");
    scanf("%d %d", &a, &b);
    
    int n1 = add (a, b);
    int n2 = dif (a, b);
    int n3 = mul (a, b);
    int n4 = div (a, b);

    printf("Here is PI: %f. \n The operations with %d and %d, give:\nAddition:%d\nDifference:%d\nMultiplication:%d\nDivision:%d\n", PI, a, b, n1, n2, n3, n4);

    return 0;
}