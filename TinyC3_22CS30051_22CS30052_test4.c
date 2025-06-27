
void reverseString(char *str) {
    int start = 0, end = strlen(str) - 1;
    while (start < end) {
        char temp = str[start];
        str[start] = str[end];
        str[end] = temp;
        start++;
        end--;
    }
}

int main() {
    char str[] = "Hello, World!";
    reverseString(str);
    printf("Reversed string: %s\n", str);
    return 0;
}
