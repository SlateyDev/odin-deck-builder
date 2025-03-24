package game

import "core:encoding/csv"
import "core:fmt"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

Card_Kind :: enum {
    Attack,
    Skill,
	Power,
}

Card :: struct {
    definition: ^Card_Definition,
    randomizer: i32,
    selected: bool,

	position: rl.Vector2,
	rotation: f32,
}

Card_Definition :: struct {
    name: string,
	flavour: string,
    use_cost: int,
    kind: Card_Kind,
	texture: rl.Texture2D,
	card_proc: proc(),
}

Player_Cards :: struct {
	hand: [dynamic]Card,
	draw: [dynamic]Card,
	discard: [dynamic]Card,
	hand_size: int,
}

card_strike :: proc() {

}

card_defend :: proc() {

}

card_bash :: proc() {

}

cards := string(#load("card_definitions.csv"))

card_definitions : [dynamic]Card_Definition

//Starter cards
strike_card_definition : Card_Definition = {name = "Strike", flavour = "Deal 6 damage.", use_cost = 1, kind = .Attack, card_proc = card_strike}
defend_card_definition : Card_Definition = {name = "Defend", flavour = "Gain 5 Block.", use_cost = 1, kind = .Skill, card_proc = card_defend}
bash_card_definition : Card_Definition = {name = "Bash", flavour = "Deal 8 damage.\nApply 2 Vulnerable.", use_cost = 2, kind = .Attack, card_proc = card_bash}

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

	append(&card_definitions, Card_Definition{name = "CARD TITLE", flavour = "Some flavour text goes here", use_cost = 1, kind = .Attack, card_proc = card_bash})
	// append(&card_definitions, Card_Definition{name = "Card2", flavour = "", use_cost = 1, kind = .Skill, card_proc = card_})
	// append(&card_definitions, Card_Definition{name = "Card3", flavour = "", use_cost = 2, kind = .Attack, card_proc = card_})

	//Starter cards
	create_card_texture(&strike_card_definition)
	create_card_texture(&defend_card_definition)
	create_card_texture(&bash_card_definition)

	for &card_definition in card_definitions {
		create_card_texture(&card_definition)
	}
}

cleanup_card_definitions :: proc() {
	rl.UnloadTexture(strike_card_definition.texture)
	rl.UnloadTexture(defend_card_definition.texture)
	rl.UnloadTexture(bash_card_definition.texture)
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

draw_card :: proc(player_cards: ^Player_Cards) {
	if len(player_cards.draw) == 0 {
		shuffle_cards(&player_cards.discard)
		move_cards(&player_cards.draw, &player_cards.discard, len(player_cards.discard))
	}
	move_cards(&player_cards.hand, &player_cards.draw, 1)
}

//Refill cards from the draw pile, if the draw pile becomes empty, shuffle the discard pile back in
//and draw the remaining
refill_hand :: proc(player_cards: ^Player_Cards) {
	cards_to_draw := player_cards.hand_size - len(player_cards.hand)
	//If cards_to_draw is <0 then we have too many, should we discard some?
	draw_pile_cards := min(cards_to_draw, len(player_cards.draw))
	remaining_cards := cards_to_draw - draw_pile_cards
	move_cards(&player_cards.hand, &player_cards.draw, player_cards.hand_size - len(player_cards.hand))
	if remaining_cards > 0 {
		shuffle_cards(&player_cards.discard)
		move_cards(&player_cards.draw, &player_cards.discard, len(player_cards.discard))
		move_cards(&player_cards.hand, &player_cards.draw, remaining_cards)
	}
}

CARD_WIDTH :: 278
CARD_HEIGHT :: 378

Render_Card_Proc_Data :: struct {
	val: int,
}

//Change to draw a card image and overlay with text
render_card :: proc(card_definition: ^Card_Definition, mouse_pos: rl.Vector2, position: rl.Vector2, rotation: f32 = 0, tint: rl.Color = rl.WHITE, mouse_pressed: proc(proc_data: ^Render_Card_Proc_Data) = nil, mouse_released: proc(proc_data: ^Render_Card_Proc_Data) = nil, proc_data: ^Render_Card_Proc_Data = nil) {
	card_rect := rl.Rectangle{0, 0, CARD_WIDTH, CARD_HEIGHT}
	card_rotation_rad := rotation * DEG_TO_RAD
	tl := rl.Vector2Rotate({card_rect.x - card_rect.width / 2, card_rect.y - card_rect.height / 2}, card_rotation_rad) + position
	tr := rl.Vector2Rotate({card_rect.x + card_rect.width / 2, card_rect.y - card_rect.height / 2}, card_rotation_rad) + position
	bl := rl.Vector2Rotate({card_rect.x - card_rect.width / 2, card_rect.y + card_rect.height / 2}, card_rotation_rad) + position
	br := rl.Vector2Rotate({card_rect.x + card_rect.width / 2, card_rect.y + card_rect.height / 2}, card_rotation_rad) + position

	rl.DrawTexturePro(card_definition.texture, {0, 0, CARD_WIDTH, CARD_HEIGHT}, {position.x, position.y, CARD_WIDTH, CARD_HEIGHT}, {CARD_WIDTH / 2, CARD_HEIGHT / 2}, rotation, tint)

	points : []rl.Vector2 = {tl, tr, br, bl}
	if rl.CheckCollisionPointPoly(rl.GetMousePosition(), raw_data(points), 4) {
		if mouse_pressed != nil && rl.IsMouseButtonPressed(.LEFT) {
			mouse_pressed(proc_data)
		}
		if mouse_released != nil && rl.IsMouseButtonReleased(.LEFT) {
			mouse_released(proc_data)
		}

		rl.DrawLineV(tl, tr, rl.RED)
		rl.DrawLineV(tr, br, rl.RED)
		rl.DrawLineV(br, bl, rl.RED)
		rl.DrawLineV(bl, tl, rl.RED)
	}


// 	card_rect := rl.Rectangle{position.x - CARD_WIDTH / 2, position.y - CARD_HEIGHT / 2, CARD_WIDTH, CARD_HEIGHT}
// 	brightness : f32 = 0
// 	if rl.CheckCollisionPointRec(mouse_pos, card_rect) {
// 		brightness = 0.2
// 		if rl.IsMouseButtonReleased(.LEFT) {
// 			if select_card != nil {
// 				select_card(card_info)
// 			}
// 		}
// 	}
// 	rl.DrawRectangleRounded(card_rect, 0.14, 30, rl.ColorBrightness(rl.BEIGE, brightness))
// 	rl.DrawRectangleRoundedLinesEx(card_rect, 0.14, 30, 1.5, rl.RED)

// 	rl.DrawRectangleRounded(rl.Rectangle{position.x - CARD_WIDTH / 2 + 5, position.y - CARD_HEIGHT / 4 + CARD_HEIGHT / 2 - 10, CARD_WIDTH - 10, CARD_HEIGHT / 4}, 0.24, 30, rl.BLUE)
// 	rl.DrawRectangleRoundedLinesEx(rl.Rectangle{position.x - CARD_WIDTH / 2 + 5, position.y - CARD_HEIGHT / 4 + CARD_HEIGHT / 2 - 10, CARD_WIDTH - 10, CARD_HEIGHT / 4}, 0.24, 30, 1.5, rl.BLACK)

// 	text_width := rl.MeasureText("Title", 20)
// 	rl.DrawText("Title", i32(position.x) - text_width / 2, i32(position.y) - CARD_HEIGHT / 2 + 10, 20, rl.WHITE)

// 	// draw_text_boxed(rl.GetFontDefault(), "Here we add some flavour text with maybe a little bit of lorem ipsum. Just kidding, I can't remember lorem ipsum off by heart and I will just type some text to see what happened if it is really long", rl.Rectangle{position.x - CARD_WIDTH / 2 + 7, position.y - CARD_HEIGHT / 4 + CARD_HEIGHT / 2 - 8, CARD_WIDTH - 14, CARD_HEIGHT / 4}, 10, 1.0, true, rl.WHITE)
}

create_card_texture :: proc(card_definition: ^Card_Definition) {
	//TODO: Instead of loading every time, it should use a cached image and use ImageCopy.
	card_layout := rl.LoadImage("assets/card_layout.png")
	defer rl.UnloadImage(card_layout)

	//TODO: Instead of loading every time, it should use a cached font.
	card_font := rl.LoadFont("assets/OLDSH___.TTF")
	defer rl.UnloadFont(card_font)
	rl.GenTextureMipmaps(&card_font.texture)
	rl.SetTextureFilter(card_font.texture, .TRILINEAR)

	image_render_centered_text(&card_layout, card_font, fmt.ctprintf("%s", card_definition.name), {CARD_WIDTH / 2, 273}, 12, rl.WHITE)
	image_render_text_boxed(&card_layout, card_font, card_definition.flavour, {83, 315, 112, 22}, 12, 1, true, rl.BLACK, -10)
	rl.ImageDrawCircle(&card_layout, 38, 44, 20, rl.BLACK)
	image_render_centered_text(&card_layout, card_font, fmt.ctprintf("%d", card_definition.use_cost), {38, 44}, 24, rl.GREEN)

	card_definition.texture = rl.LoadTextureFromImage(card_layout)
	rl.GenTextureMipmaps(&card_definition.texture)
	rl.SetTextureFilter(card_definition.texture, .TRILINEAR)
}