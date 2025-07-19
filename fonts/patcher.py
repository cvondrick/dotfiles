import fontforge
import os

filename = "Monego-BoldItalic.otf"

# Open the font file
font = fontforge.open(filename)

# Set all glyph widths to a fixed value (e.g., 600 units)
fixed_width = 1229
for glyph in font.glyphs():
    if glyph.isWorthOutputting():
        if glyph.width != 1229:
            print(glyph.width)
        glyph.width = fixed_width

# Update OS/2 metrics to indicate fixed-pitch
font.os2_version = 4  # Ensures compatibility with newer systems
font.os2_panose = (2, 9, 6, 3, 0, 0, 0, 0, 0, 0)  # Set PANOSE to indicate monospaced font
#font.os2_monospaced = True  # Marks the font as monospaced

try:
    os.mkdir("patched")
except IOError:
    pass

# Save the new font as OTF
font.generate(os.path.join("patched", "Patched" + filename) )
