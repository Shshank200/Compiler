
int countSetBits(int n) {
    int count = 0;
    while (n) {
        count += n & 1;
        n >>= 1;
    }
    return count;
}

int main() {
    int num = 29; // Binary: 11101
    printf("Number of set bits in %d is %d\n", num, countSetBits(num));
    return 0;
}
