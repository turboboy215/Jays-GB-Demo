rgbasm "JAYS.ASM" -o "JAYS.OBJ"
rgblink "JAYS.OBJ" -o "JAYS.GB"
rgbfix "JAYS.GB" -v -p00