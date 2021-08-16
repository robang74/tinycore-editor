#include <stdio.h>
#include <stdarg.h>

static int fmtstr(char *, size_t, const char *, ...) __attribute__((__format__(__printf__,3,4)));
static int
fmtstr(char *outbuf, size_t length, const char *fmt, ...)
{
	va_list ap;
	int ret;

	va_start(ap, fmt);
	ret = vsnprintf(outbuf, length, fmt, ap);
	va_end(ap);
	return ret > (int)length ? length : ret;
}

int main(void) {
	char funcnamevar[sizeof("FUNCNAME=") + 4] = "FUNCNAME=";
	fmtstr(funcnamevar+9, sizeof(funcnamevar)-9, "%s", "ciaobello");
	printf("output: '%s', value sould be set to 'ciao' and nothing more\n", funcnamevar);
	fmtstr(funcnamevar+9, sizeof(funcnamevar)-9, "%s", "");
	printf("output: '%s', value sould be set to '' and nothing more\n", funcnamevar);
	return 0;
}
