.PHONY: all clean

all: rtems-memory.png supercore-overview.png

rtems-memory.png: rtems-memory.ditaa
	ditaa -r rtems-memory.ditaa rtems-memory.png

supercore-overview.png: supercore-overview.ditaa
	ditaa -r supercore-overview.ditaa supercore-overview.png

clean:
	rm -f rtems-memory.png
	rm -f supercore-overview.png
