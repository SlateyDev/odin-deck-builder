package game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

image_draw_centered_text :: proc(dst: ^rl.Image, font: rl.Font, text: cstring, pos: rl.Vector2, font_size: f32, fore_color: rl.Color) {
	text_size := rl.MeasureTextEx(font, text, font_size, 2)
	rl.ImageDrawTextEx(dst, font, text, {pos.x - text_size.x / 2, pos.y - text_size.y / 2}, font_size, 2, rl.WHITE)
}

MEASURE_STATE :: false
DRAW_STATE :: true

image_draw_text_boxed :: proc(dst: ^rl.Image, font: rl.Font, text: string, rec: rl.Rectangle, fontSize: f32, spacing: f32, wordWrap: bool, tint: rl.Color, leading: f32 = 0.0) {
	length := i32(len(text))

	textOffsetY : f32 = 0.0          // Offset between lines (on line break '\n')
    textOffsetX : f32 = 0.0       // Offset X to next character to draw

    scaleFactor := fontSize / f32(font.baseSize)

    // Word/character wrapping mechanism variables
    state := wordWrap? MEASURE_STATE : DRAW_STATE

    startLine : i32 = -1         // Index where to begin drawing (where a line begins)
    endLine : i32 = -1           // Index where to stop drawing (where a line ends)
    lastk : i32 = -1             // Holds last value of the character position

	i : i32 = 0
	k : i32 = 0
    for i < length {
        // Get next codepoint from byte string and glyph index in font
        codepointByteCount : i32 = 0
		r := string([]u8{text[i]})
        codepoint := rl.GetCodepoint(strings.clone_to_cstring(r, context.temp_allocator), &codepointByteCount)
        index := rl.GetGlyphIndex(font, codepoint)

        // NOTE: Normally we exit the decoding sequence as soon as a bad byte is found (and return 0x3f)
        // but we need to draw all of the bad bytes using the '?' symbol moving one byte
        if (codepoint == 0x3f) do codepointByteCount = 1
        i += codepointByteCount - 1

        glyphWidth : f32 = 0.0
        if (codepoint != '\n') {
            glyphWidth = (font.glyphs[index].advanceX == 0) ? font.recs[index].width*scaleFactor : f32(font.glyphs[index].advanceX) * scaleFactor

            if i + 1 < length do glyphWidth = glyphWidth + spacing
        }

        // NOTE: When wordWrap is ON we first measure how much of the text we can draw before going outside of the rec container
        // We store this info in startLine and endLine, then we change states, draw the text between those two variables
        // and change states again and again recursively until the end of the text (or until we get outside of the container).
        // When wordWrap is OFF we don't need the measure state so we go to the drawing state immediately
        // and begin drawing on the next line before we can get outside the container.
        if state == MEASURE_STATE {
            // TODO: There are multiple types of spaces in UNICODE, maybe it's a good idea to add support for more
            // Ref: http://jkorpela.fi/chars/spaces.html
            if (codepoint == ' ') || (codepoint == '\t') || (codepoint == '\n') do endLine = i

            if (textOffsetX + glyphWidth) > rec.width {
                endLine = (endLine < 1)? i : endLine
                if i == endLine do endLine -= codepointByteCount
                if (startLine + codepointByteCount) == endLine do endLine = (i - codepointByteCount)

                state = !state
            } else if (i + 1) == length {
                endLine = i
                state = !state
            } else if codepoint == '\n' {
				state = !state
			}

            if state == DRAW_STATE {
                textOffsetX = 0
                i = startLine
                glyphWidth = 0

                // Save character position when we switch states
                tmp := lastk
                lastk = k - 1
                k = tmp
            }
        } else {
            if codepoint == '\n' {
                if !wordWrap {
                    textOffsetY += f32(font.baseSize + font.baseSize/2)*scaleFactor + leading
                    textOffsetX = 0
                }
            } else {
                if !wordWrap && ((textOffsetX + glyphWidth) > rec.width) {
                    textOffsetY += f32(font.baseSize + font.baseSize/2)*scaleFactor + leading
                    textOffsetX = 0
                }

                // When text overflows rectangle height limit, just stop drawing
                if (textOffsetY + f32(font.baseSize)*scaleFactor + leading) > rec.height do break

                // Draw current character glyph
                if (codepoint != ' ') && (codepoint != '\t') {
                    rl.ImageDrawTextEx(dst, font, fmt.ctprintf("%r", codepoint), { rec.x + textOffsetX, rec.y + textOffsetY }, fontSize, 0, tint)
                }
            }

            if wordWrap && (i == endLine) {
                textOffsetY += f32(font.baseSize + font.baseSize/2)*scaleFactor + leading
                textOffsetX = 0
                startLine = endLine
                endLine = -1
                glyphWidth = 0
                k = lastk

                state = !state
            }
        }

        if (textOffsetX != 0) || (codepoint != ' ') do textOffsetX += glyphWidth  // avoid leading spaces

		i += 1
		k += 1
    }
}
