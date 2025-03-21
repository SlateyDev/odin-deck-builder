package game

import "core:encoding/csv"
import "core:fmt"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

Card_Kind :: enum {
    Action,
    Upgrade,
}

Card :: struct {
    definition: ^Card_Definition,
    randomizer: i32,
    selected: bool,
}

Card_Definition :: struct {
    name: string,
	flavour: string,
    use_cost: int,
    kind: Card_Kind,
    data: union {
        Card_Action,
        Card_Upgrade,
    },
	texture: rl.Texture2D,
}

Card_Upgrade :: struct {

}

Card_Action :: struct {

}

cards := string(#load("card_definitions.csv"))

card_definitions : [dynamic]Card_Definition

setup_card_definitions :: proc() {
	card_definitions = make([dynamic]Card_Definition)

	csv_data, _ := csv.read_all_from_string(cards)
    defer {
        for record in csv_data {
            for &datum in record {
                delete(datum)
            }
            delete(record)
        }
        delete(csv_data)
    }
    fmt.println(csv_data)
}

cleanup_card_definitions :: proc() {
	delete(card_definitions)
}

//Shuffle a deck of cards
shuffle_cards :: proc(deck: ^[dynamic]Card) {
	for &card in deck {
		card.randomizer = rand.int31()
	}
	slice.sort_by_cmp(deck[:], card_shuffle_sorter)
}

card_shuffle_sorter := proc(i: Card, j: Card) -> slice.Ordering {
	if i.randomizer < j.randomizer do return .Less
	if i.randomizer > j.randomizer do return .Greater
	return .Equal
}

//Move a number of cards from source to destination
move_cards :: proc(dest: ^[dynamic]Card, source: ^[dynamic]Card, amount: int) {
	for _ in 0..<amount {
		card, ok := pop_front_safe(source)
		if ok {
			append(dest, card)
		}
	}
}

//Move the cards that pass test from source to destination
move_cards_by :: proc(dest: ^[dynamic]Card, source: ^[dynamic]Card, test: proc(^Card) -> bool) {
	card_index := 0

	for card_index < len(source) {
		if test(&source[card_index]) {
			append(dest, source[card_index])
			ordered_remove(source, card_index)
		} else {
			card_index += 1
		}
	}
}

//Refill cards from the draw pile, if the draw pile becomes empty, shuffle the discard pile back in
//and draw the remaining
refill_hand :: proc(hand: ^[dynamic]Card, draw: ^[dynamic]Card, discard: ^[dynamic]Card, hand_size: int) {
	cards_to_draw := hand_size - len(hand)
	//If cards_to_draw is <0 then we have too many, should we discard some?
	draw_pile_cards := min(cards_to_draw, len(draw))
	remaining_cards := cards_to_draw - draw_pile_cards
	move_cards(hand, draw, hand_size - len(hand))
	if remaining_cards > 0 {
		shuffle_cards(discard)
		move_cards(draw, discard, len(discard))
		move_cards(hand, draw, remaining_cards)
	}
}

CARD_WIDTH :: 278
CARD_HEIGHT :: 378

//Change to draw a card image and overlay with text
draw_card :: proc(mouse_pos: rl.Vector2, position: rl.Vector2, card_info: Card, select_card: proc(Card)) {
	card_rect := rl.Rectangle{position.x - CARD_WIDTH / 2, position.y - CARD_HEIGHT / 2, CARD_WIDTH, CARD_HEIGHT}
	brightness : f32 = 0
	if rl.CheckCollisionPointRec(mouse_pos, card_rect) {
		brightness = 0.2
		if rl.IsMouseButtonReleased(.LEFT) {
			if select_card != nil {
				select_card(card_info)
			}
		}
	}
	rl.DrawRectangleRounded(card_rect, 0.14, 30, rl.ColorBrightness(rl.BEIGE, brightness))
	rl.DrawRectangleRoundedLinesEx(card_rect, 0.14, 30, 1.5, rl.RED)

	rl.DrawRectangleRounded(rl.Rectangle{position.x - CARD_WIDTH / 2 + 5, position.y - CARD_HEIGHT / 4 + CARD_HEIGHT / 2 - 10, CARD_WIDTH - 10, CARD_HEIGHT / 4}, 0.24, 30, rl.BLUE)
	rl.DrawRectangleRoundedLinesEx(rl.Rectangle{position.x - CARD_WIDTH / 2 + 5, position.y - CARD_HEIGHT / 4 + CARD_HEIGHT / 2 - 10, CARD_WIDTH - 10, CARD_HEIGHT / 4}, 0.24, 30, 1.5, rl.BLACK)

	text_width := rl.MeasureText("Title", 20)
	rl.DrawText("Title", i32(position.x) - text_width / 2, i32(position.y) - CARD_HEIGHT / 2 + 10, 20, rl.WHITE)

	// draw_text_boxed(rl.GetFontDefault(), "Here we add some flavour text with maybe a little bit of lorem ipsum. Just kidding, I can't remember lorem ipsum off by heart and I will just type some text to see what happened if it is really long", rl.Rectangle{position.x - CARD_WIDTH / 2 + 7, position.y - CARD_HEIGHT / 4 + CARD_HEIGHT / 2 - 8, CARD_WIDTH - 14, CARD_HEIGHT / 4}, 10, 1.0, true, rl.WHITE)
}

create_card_texture :: proc(card_info: Card) -> rl.Texture2D {
	//TODO: Instead of loading every time, it should use a cached image and use ImageCopy.
	card_layout := rl.LoadImage("assets/card_layout.png")
	defer rl.UnloadImage(card_layout)

	//TODO: Instead of loading every time, it should use a cached font.
	card_font := rl.LoadFont("assets/OLDSH___.TTF")
	defer rl.UnloadFont(card_font)
	rl.GenTextureMipmaps(&card_font.texture)
	rl.SetTextureFilter(card_font.texture, .TRILINEAR)

	image_draw_centered_text(&card_layout, card_font, fmt.ctprintf("%s", card_info.definition.name), {CARD_WIDTH / 2, 273}, 12, rl.WHITE)
	image_draw_text_boxed(&card_layout, card_font, card_info.definition.flavour, {83, 315, 112, 22}, 12, 1, true, rl.BLACK, -10)
	rl.ImageDrawCircle(&card_layout, 38, 44, 20, rl.BLACK)
	image_draw_centered_text(&card_layout, card_font, fmt.ctprintf("%d", card_info.definition.use_cost), {38, 44}, 24, rl.GREEN)

	texture := rl.LoadTextureFromImage(card_layout)
	rl.GenTextureMipmaps(&texture)
	rl.SetTextureFilter(texture, .TRILINEAR)

	return texture
}