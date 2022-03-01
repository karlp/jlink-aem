
all: aem-dump

clean:
	$(RM) aem-dump

aem-dump: aem-dump.c
	$(CC) -o $@ $< -ljaylink

