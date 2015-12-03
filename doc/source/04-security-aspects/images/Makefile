.PHONY: all clean

all: attack-setup.png bo-overview.png payload-overview.png

attack-setup.png: attack-setup.ditaa
	ditaa -E attack-setup.ditaa attack-setup.png

bo-overview.png: bo-overview.ditaa
	ditaa -r -E bo-overview.ditaa bo-overview.png

payload-overview.png: payload-overview.ditaa
	ditaa -r -E payload-overview.ditaa payload-overview.png

clean:
	rm -f attack-setup.png
	rm -f bo-overview.png
	rm -f payload-overview.png
