void my_printf(const char* fmt, ...)
{
    int* argp = (int*)&fmt;
    argp += sizeof(fmt) / sizeof(int); // argp points at 1
    argp++; // argp points at 2
    argp++; // argp points at 3
    argp+=2; // argp points at 4
}

int main()
{
    my_printf("Test %d %u %x %i", 1, 2, 3ll, 4);
    my_printf("Test %% %s %c %d %lx %llu %hd %hhd\n", "abc", 'z', 1, 2ul, 3ull, (short)4, (char)5);
}
