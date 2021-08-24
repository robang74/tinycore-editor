#include <stdio.h>
#include <unistd.h>

int main(int argc, char **argv){

	if (argc < 2) return 1;

	const char arr[] = { '/', '-', '\\', '|' };
	unsigned int i = 0, j;
	chdir("/proc");

	for (j = 1; j < argc; j++) {
		while (access(argv[j],F_OK) == 0) {
			printf("%c\b",arr[i]);
			fflush(stdout);
			i++;
			i %= 4;
			usleep(100000);
		}
	}
	return 0;
}
