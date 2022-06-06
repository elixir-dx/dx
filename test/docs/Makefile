.SUFFIXES: .uml .png
SOURCES != ls *.uml | awk 'sub(".uml$$", ".png")'

.uml.png:
	plantuml $< > $@

all: ${SOURCES}
