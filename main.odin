#+feature dynamic-literals

package main

import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	test_entities()

	setup_cards()
	destroy_cards()
}

start_game :: proc() {
	screenWidth: i32 = 1280
	screenHeight: i32 = 720

	rl.InitWindow(screenWidth, screenHeight, "Deck Builder")
	defer rl.CloseWindow()

	// cardsTexture := rl.LoadTexture("Cards.png")

	rl.SetWindowState({rl.ConfigFlag.WINDOW_RESIZABLE})

	// SetTargetFPS(60)

	camera := rl.Camera2D {
		target = rl.Vector2{0, 0},
		zoom   = 1,
	}

	for !rl.WindowShouldClose() {
		// deltaTime := rl.GetFrameTime()

		// mouse coordinates
		// mousePos := [2]i32{rl.GetMouseX(), rl.GetMouseY()}

		// mouse buttons
		// @(static) buttons_to_key := [?]struct {
		// 	rl_button: rl.MouseButton,
		// 	mu_button: mu.Mouse,
		// }{{.LEFT, .LEFT}, {.RIGHT, .RIGHT}, {.MIDDLE, .MIDDLE}}
		// for button in buttons_to_key {
		// 	if rl.IsMouseButtonPressed(button.rl_button) {
		// 	} else if rl.IsMouseButtonReleased(button.rl_button) {
		// 	}
		// }

		// keyboard
		// @(static) keys_to_check := [?]struct {
		// 	rl_key: rl.KeyboardKey,
		// 	mu_key: mu.Key,
		// } {
		// 	{.LEFT_SHIFT, .SHIFT},
		// 	{.RIGHT_SHIFT, .SHIFT},
		// 	{.LEFT_CONTROL, .CTRL},
		// 	{.RIGHT_CONTROL, .CTRL},
		// 	{.LEFT_ALT, .ALT},
		// 	{.RIGHT_ALT, .ALT},
		// 	{.ENTER, .RETURN},
		// 	{.KP_ENTER, .RETURN},
		// 	{.BACKSPACE, .BACKSPACE},
		// }
		// for key in keys_to_check {
		// 	if rl.IsKeyPressed(key.rl_key) {
		// 	} else if rl.IsKeyReleased(key.rl_key) {
		// 	}
		// }

		builder := strings.builder_make()
		defer strings.builder_destroy(&builder)

		{
			rl.BeginDrawing()
			defer rl.EndDrawing()
			rl.BeginMode2D(camera)
			defer rl.EndMode2D()

			currentScreenWidth := rl.GetScreenWidth()
			// currentScreenHeight := rl.GetScreenHeight()

			rl.ClearBackground(rl.BEIGE)

			rl.DrawText("Testing", 190, 200, 20, rl.LIGHTGRAY)

			fps := int(rl.GetFPS())

			strings.builder_reset(&builder)
			strings.write_string(&builder, "FPS: ")
			strings.write_int(&builder, fps)
			fpsString := strings.to_cstring(&builder)

			fpsStringLength := rl.MeasureText(fpsString, 20)
			rl.DrawText(fpsString, currentScreenWidth - fpsStringLength - 20, 20, 20, rl.WHITE)
		}
	}
}

Node_Type :: enum u16 {
	Node2D,
	Sprite,
}

Node2D :: struct {
	kind: Node_Type,
	position: rl.Vector2,
	rotation: f32,
	scale: rl.Vector2,
	z_index: int,
	// children: [dynamic]Node2D,
	data: union {
		Sprite,
	},
}

Sprite :: struct {
	more_data: i32,
}

Card :: struct {
	suit: SUIT,
	value: i32,
	randomizer: i32,
	selected: bool,
}

Player :: struct {
	hand : [dynamic]Card,
	draw_pile : [dynamic]Card,
	discard_pile : [dynamic]Card,
}

main_deck : [dynamic]Card
player : Player

SUIT :: enum {
	Diamonds,
	Clubs,
	Hears,
	Spades,
}

setup_cards :: proc() {
	setup_main_deck()
}

destroy_cards :: proc() {
	delete(main_deck)
	delete(player.discard_pile)
	delete(player.draw_pile)
	delete(player.hand)
}

setup_main_deck :: proc() {
	for suit in SUIT {
		for val in 1..=13 {
			add_card := Card{suit = suit, value = i32(val)}
			append(&main_deck, add_card)
		}
	}

	shuffle_deck()
}

//Aquire a card from the deck
aquire_from_deck_to_draw :: proc() {
	card, ok := pop_front_safe(&main_deck)
	if ok {
		append(&player.draw_pile, card)
	}
}

//Shuffle the main deck
shuffle_deck :: proc() {
	for &card in main_deck {
		card.randomizer = rand.int31()
	}
	slice.sort_by_cmp(main_deck[:], card_shuffle_sorter)
}

card_shuffle_sorter := proc(i: Card, j: Card) -> slice.Ordering {
	if i.randomizer < j.randomizer do return .Less
	if i.randomizer > j.randomizer do return .Greater
	return .Less
}

//Shuffle the discard pile back into the draw pile
shuffle_discard_to_draw :: proc() {
	for &card in player.discard_pile {
		card.randomizer = rand.int31()
	}
	slice.sort_by_cmp(player.discard_pile[:], card_shuffle_sorter)
	append(&player.draw_pile, ..player.discard_pile[:])
	clear(&player.discard_pile)
}

//Draw a card from the draw pile
aquire_from_draw :: proc() {
	card, ok := pop_front_safe(&player.draw_pile)

	if !ok {
		shuffle_discard_to_draw()
		card, ok = pop_front_safe(&player.draw_pile)
	}
}

//Discard a card from hand to the discard pile
discard_selected_cards :: proc() {
	run_search := true
	for run_search {
		run_search = false
		for &card, card_index in player.hand {
			if card.selected {
				append(&player.discard_pile, card)
				ordered_remove(&player.hand, card_index)
				run_search = true
				break
			}
		}
	}
}

test_entities :: proc() {
	entities : [dynamic]Node2D
	defer delete(entities)
	// defer {
	// 	for entity in entities {
	// 		delete(entity.children)
	// 	}
	// }

	for _ in 0..<20 {
		new_node := Node2D{kind = .Sprite, z_index = rand.int_max(8), data = Sprite {more_data = rand.int31_max(21) - 10}}
		//Have to append to new_node before appending new_node to entities as it takes a copy on the append
		// for _ in 0..<5 {
		// 	fmt.println(append(&new_node.children, Node2D{kind = .Node2D, z_index = rand.int_max(8)}))
		// }
		fmt.println(append(&entities, new_node))
	}

	// Sort before rendering
	slice.sort_by_cmp(entities[:], entity_sorter)
	for entity in entities {
		fmt.println("Entity: ", entity)
	}
}

entity_sorter :: proc(i: Node2D, j: Node2D) -> slice.Ordering {
	if i.z_index < j.z_index do return slice.Ordering.Less
	if i.z_index > j.z_index do return slice.Ordering.Greater

	if i.position.y < j.position.y do return slice.Ordering.Less
	if i.position.y > j.position.y do return slice.Ordering.Greater

	return slice.Ordering.Equal
}