#+feature dynamic-literals

package game

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

DEG_TO_RAD :: 3.141592654 / 180
RAD_TO_DEG :: 180 / 3.141592654

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
	defer destroy_cards()

	start_game()
}

start_game :: proc() {
	screenWidth: i32 = 1920
	screenHeight: i32 = 1080

	rl.InitWindow(screenWidth, screenHeight, "Deck Builder")
	defer rl.CloseWindow()

	card := create_card_texture(Card{definition = &{name = "CARD TITLE", flavour = "Testing adding some flavour text to see how it fills up the text area that has been defined", use_cost = 2}})
	defer rl.UnloadTexture(card)

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
			currentScreenHeight := rl.GetScreenHeight()

			rl.ClearBackground(rl.BEIGE)

			rl.DrawText("Testing", 190, 200, 20, rl.LIGHTGRAY)

			// rotation := f32(rl.GetTime()) * 10

			// card_rect := rl.Rectangle{0, 0, CARD_WIDTH, CARD_HEIGHT}
			// card_rotation_rad := rotation * DEG_TO_RAD
			// tl := rl.Vector2Rotate({card_rect.x - card_rect.width / 2, card_rect.y - card_rect.height / 2}, card_rotation_rad) + {f32(currentScreenWidth) / 2, f32(currentScreenHeight) / 2}
			// tr := rl.Vector2Rotate({card_rect.x + card_rect.width / 2, card_rect.y - card_rect.height / 2}, card_rotation_rad) + {f32(currentScreenWidth) / 2, f32(currentScreenHeight) / 2}
			// bl := rl.Vector2Rotate({card_rect.x - card_rect.width / 2, card_rect.y + card_rect.height / 2}, card_rotation_rad) + {f32(currentScreenWidth) / 2, f32(currentScreenHeight) / 2}
			// br := rl.Vector2Rotate({card_rect.x + card_rect.width / 2, card_rect.y + card_rect.height / 2}, card_rotation_rad) + {f32(currentScreenWidth) / 2, f32(currentScreenHeight) / 2}

			// points : []rl.Vector2 = {tl, tr, br, bl}
			// if rl.CheckCollisionPointPoly(rl.GetMousePosition(), raw_data(points), 4) {
			// 	rl.DrawTexturePro(card, {0, 0, CARD_WIDTH, CARD_HEIGHT}, {f32(currentScreenWidth) / 2, f32(currentScreenHeight) / 2, CARD_WIDTH, CARD_HEIGHT}, {CARD_WIDTH / 2, CARD_HEIGHT / 2}, rotation, rl.WHITE)
			// } else {
			// 	rl.DrawTexturePro(card, {0, 0, CARD_WIDTH, CARD_HEIGHT}, {f32(currentScreenWidth) / 2, f32(currentScreenHeight) / 2, CARD_WIDTH, CARD_HEIGHT}, {CARD_WIDTH / 2, CARD_HEIGHT / 2}, rotation, rl.GRAY)
			// }

			for _, card_index in player.hand {
				card_x_pos := f32(currentScreenWidth - i32(len(player.hand) - 1) * 200) / 2 + f32(card_index) * 200
				card_y_pos := f32(currentScreenHeight) - 120 - math.cos((f32(len(player.hand) / 2) - f32(card_index))) * 50
				rotation := -(f32(len(player.hand) / 2) - f32(card_index)) * 10

				if rl.CheckCollisionPointRec(rl.GetMousePosition(), {card_x_pos - 100, card_y_pos - 200, 200, CARD_HEIGHT}) {
					rl.DrawTexturePro(card, {0, 0, CARD_WIDTH, CARD_HEIGHT}, {card_x_pos, card_y_pos, CARD_WIDTH, CARD_HEIGHT}, {CARD_WIDTH / 2, CARD_HEIGHT / 2}, rotation, rl.WHITE)
				} else {
					rl.DrawTexturePro(card, {0, 0, CARD_WIDTH, CARD_HEIGHT}, {card_x_pos, card_y_pos, CARD_WIDTH, CARD_HEIGHT}, {CARD_WIDTH / 2, CARD_HEIGHT / 2}, rotation, rl.GRAY)
				}
			}

			// for _, card_index in player.hand {
			// 	card_x_pos := f32(currentScreenWidth - i32(len(player.hand) - 1) * 200) / 2 + f32(card_index) * 200
			// 	rl.DrawRectangleLinesEx({card_x_pos - 100, f32(currentScreenHeight) / 2 - 200, 200, CARD_HEIGHT}, 1, rl.RED)
			// }

			// rl.DrawLineV(tl, tr, rl.RED)
			// rl.DrawLineV(tr, br, rl.RED)
			// rl.DrawLineV(br, bl, rl.RED)
			// rl.DrawLineV(bl, tl, rl.RED)
			fps := int(rl.GetFPS())

			strings.builder_reset(&builder)
			strings.write_string(&builder, "FPS: ")
			strings.write_int(&builder, fps)
			if fpsString, err := strings.to_cstring(&builder); err == nil {
				fpsStringLength := rl.MeasureText(fpsString, 20)
				rl.DrawText(fpsString, currentScreenWidth - fpsStringLength - 20, 20, 20, rl.WHITE)
			}
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

Player :: struct {
	hand: [dynamic]Card,
	draw_pile: [dynamic]Card,
	discard_pile: [dynamic]Card,
	hand_size: int,

	health: int,
	energy: int,
	energy_per_turn: int,

	status_effects: Status_Effects,
}

Status_Effects :: struct {
	Vulnerable: int,	//Turns of vulnerability. 50% more damage taken
	Block: int,			//Amount of damage being blocked
	Weak: int,			//Turns of reduced damage output. 25% less attack damage
	Poisoned: int,		//Amount of HP to lose and stacks remaining
}

Enemy :: struct {
	health: int,
	status_effects: Status_Effects,
}

// Effect_Type :: enum {
// 	Poison,		//DOT
// 	Bleeding,	//DOT
// 	Shell,		//Magical Protection
// 	Barrier,	//Physical Protection
// 	Reflect,	//Reflect magical attacks
// 	Regen,		//Regenerate health
// }
// Effect :: struct {
// 	rounds: int,
// 	effect_type: Effect_Type,
// }

player : Player

setup_cards :: proc() {
	setup_card_definitions()

	player = Player{
		hand_size = 5,
		health = 50,
		energy = 4,
		energy_per_turn = 4,
	}

	append(&player.draw_pile, Card{definition = &strike_card_definition})
	append(&player.draw_pile, Card{definition = &strike_card_definition})
	append(&player.draw_pile, Card{definition = &strike_card_definition})
	append(&player.draw_pile, Card{definition = &strike_card_definition})
	append(&player.draw_pile, Card{definition = &strike_card_definition})
	append(&player.draw_pile, Card{definition = &defend_card_definition})
	append(&player.draw_pile, Card{definition = &defend_card_definition})
	append(&player.draw_pile, Card{definition = &defend_card_definition})
	append(&player.draw_pile, Card{definition = &defend_card_definition})
	append(&player.draw_pile, Card{definition = &bash_card_definition})

	//TODO: We don't have a main deck here, this game would more likely have a collection of starting cards and then you acquire more over time
	//So the draw_pile should be seeded with the starting cards to begin with

	shuffle_cards(&player.draw_pile)

	refill_hand(&player.hand, &player.draw_pile, &player.discard_pile, player.hand_size)

	fmt.println("Draw Pile:", player.draw_pile)
	fmt.println("Hand:", player.hand)
}

destroy_cards :: proc() {
	delete(player.discard_pile)
	delete(player.draw_pile)
	delete(player.hand)
	cleanup_card_definitions()
}

//Move the cards marked selected from source to destination and unmarked them
move_selected_cards :: proc(dest: ^[dynamic]Card, source: ^[dynamic]Card) {
	card_index := 0

	for card_index < len(source) {
		if source[card_index].selected {
			source[card_index].selected = false
			append(dest, source[card_index])
			ordered_remove(source, card_index)
		} else {
			card_index += 1
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