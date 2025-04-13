#+feature dynamic-literals

package game

import "core:fmt"
import la "core:math/linalg"
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

	screenWidth: i32 = 1920
	screenHeight: i32 = 1080

	rl.InitWindow(screenWidth, screenHeight, "Deck Builder")
	defer rl.CloseWindow()

	setup_cards()
	defer destroy_cards()

	rl.SetWindowState({rl.ConfigFlag.WINDOW_RESIZABLE})
	// SetTargetFPS(60)

	start_game()
}

drag_card_index : Maybe(int)
reward_toggle := false

use_selected_card :: proc() {
	dragging_index, dragging_ok := drag_card_index.(int)
	if !dragging_ok do return

	player.player_cards.hand[dragging_index].position = 0
	move_card(&player.player_cards.discard, &player.player_cards.hand, dragging_index)
	drag_card_index = nil
}

start_dragging :: proc(proc_data: ^Render_Card_Proc_Data) {
	if proc_data == nil do return

	drag_card_index = proc_data.val
}

start_game :: proc() {
	camera := rl.Camera2D {
		target = rl.Vector2{0, 0},
		zoom   = 1,
	}

	for !rl.WindowShouldClose() {
		// deltaTime := rl.GetFrameTime()

		// mouse coordinates
		mouse_pos := rl.GetMousePosition()

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

			if rl.IsKeyPressed(.A) {
				draw_card(&player.player_cards)
			}

			if rl.IsKeyPressed(.X) {
				reward_toggle = !reward_toggle
			}

			found_hover := false
			dragging_index, dragging_ok := drag_card_index.(int)

			for &hand_card, card_index in player.player_cards.hand {
				card_x_pos := f32(currentScreenWidth - i32(len(player.player_cards.hand) - 1) * 200) / 2 + f32(card_index) * 200
				card_y_pos := f32(currentScreenHeight) - 120 - math.cos((f32(len(player.player_cards.hand) - 1) / 2 - f32(card_index))) * 50
				rotation := -(f32(len(player.player_cards.hand) - 1) / 2 - f32(card_index)) * (60 / f32(len(player.player_cards.hand)))
				card_tint := rl.GRAY

				if !reward_toggle {
					if (!dragging_ok && rl.CheckCollisionPointRec(rl.GetMousePosition(), {card_x_pos - 100, f32(currentScreenHeight - CARD_HEIGHT - 50), 200, CARD_HEIGHT + 50})) || (dragging_ok && dragging_index == card_index) {
						card_y_pos = f32(currentScreenHeight - CARD_HEIGHT / 2 - 50)
						rotation = 0

						card_tint = rl.WHITE
						found_hover = true
					} else {
						if dragging_ok || rl.CheckCollisionPointRec(rl.GetMousePosition(), {f32(currentScreenWidth - i32(len(player.player_cards.hand) - 1) * 200) / 2 - 100, f32(currentScreenHeight - CARD_HEIGHT - 50), f32(len(player.player_cards.hand) * 200), CARD_HEIGHT + 50}) {
							if !found_hover {
								card_x_pos -= 80
							} else {
								card_x_pos += 80
							}
						}
					}
				}

				hand_card.position = la.lerp(hand_card.position, rl.Vector2{card_x_pos, card_y_pos}, rl.GetFrameTime() * 5)
				hand_card.rotation = la.lerp(hand_card.rotation, rotation, rl.GetFrameTime() * 5)

				render_card(hand_card.definition, mouse_pos, {hand_card.position.x, hand_card.position.y}, hand_card.rotation, card_tint, card_tint, start_dragging, nil, &Render_Card_Proc_Data{val = card_index})
			}

			if !reward_toggle {
				render_hover_button(mouse_pos, "GET REWARD (X)", {50, 100, 200, 30}, 20, proc() {reward_toggle = !reward_toggle})
				render_hover_button(mouse_pos, "DRAW CARD (A)", {50, 150, 200, 30}, 20, proc() {draw_card(&player.player_cards)})

				render_hover_button(mouse_pos, "USE CARD HERE", {f32(currentScreenWidth) / 2 - 100, f32(currentScreenHeight) / 2 - 100, 200, 200}, 20, use_selected_card)

				if dragging_ok {
					card_x_pos := f32(currentScreenWidth - i32(len(player.player_cards.hand) - 1) * 200) / 2 + f32(dragging_index) * 200
					card_y_pos := f32(currentScreenHeight - CARD_HEIGHT / 2 - 50)

					source_pos := rl.Vector2{card_x_pos, card_y_pos}
					source_tangent_pos := rl.Vector2{source_pos.x, mouse_pos.y + (source_pos.y - mouse_pos.y) / 8}
					target_tangent_pos := rl.Vector2{source_pos.x + (source_pos.x - mouse_pos.x) / 8, mouse_pos.y}

					render_curve(source_pos, source_tangent_pos, mouse_pos, target_tangent_pos, 20)
				}
			} else {
				render_select_reward(mouse_pos)
			}

			if rl.IsMouseButtonReleased(.LEFT) {
				drag_card_index = nil
			}

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
	player_cards: Player_Cards,

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
		player_cards = Player_Cards {hand_size = 5},
		health = 50,
		energy = 4,
		energy_per_turn = 4,
	}

	append(&player.player_cards.draw, Card{definition = &strike_card_definition})
	append(&player.player_cards.draw, Card{definition = &strike_card_definition})
	append(&player.player_cards.draw, Card{definition = &strike_card_definition})
	append(&player.player_cards.draw, Card{definition = &strike_card_definition})
	append(&player.player_cards.draw, Card{definition = &strike_card_definition})
	append(&player.player_cards.draw, Card{definition = &defend_card_definition})
	append(&player.player_cards.draw, Card{definition = &defend_card_definition})
	append(&player.player_cards.draw, Card{definition = &defend_card_definition})
	append(&player.player_cards.draw, Card{definition = &defend_card_definition})
	append(&player.player_cards.draw, Card{definition = &bash_card_definition})

	//TODO: We don't have a main deck here, this game would more likely have a collection of starting cards and then you acquire more over time
	//So the draw pile should be seeded with the starting cards to begin with

	shuffle_cards(&player.player_cards.draw)

	refill_hand(&player.player_cards)

	fmt.println("Draw Pile:", player.player_cards.draw)
	fmt.println("Hand:", player.player_cards.hand)
}

destroy_cards :: proc() {
	delete(player.player_cards.discard)
	delete(player.player_cards.draw)
	delete(player.player_cards.hand)
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

CURVED_SEGMENTS :: 24

// Draw curve using Spline Cubic Bezier
// TODO: add uniform distance between points by working out the length while iterating through the curve and interpolating the points
render_curve :: proc(curve_start_position: rl.Vector2, curve_start_position_tangent: rl.Vector2, curve_end_position: rl.Vector2, curve_end_position_tangent: rl.Vector2, curve_segments: int, point_distance: f32 = 50.0) {
    step : f32 = 1.0 / f32(curve_segments)
	current_length : f32 = 0.0
	next_point_length : f32 = 0.0
	current_segment_point : rl.Vector2 = curve_start_position
	last_segment_point : rl.Vector2

    for i := 1; i <= curve_segments; i += 1 {
        t := step * f32(i)

        a := math.pow(1.0 - t, 3)
        b := 3.0 * math.pow(1.0 - t, 2) * t
        c := 3.0 * (1.0 - t) * math.pow(t, 2)
        d := math.pow(t, 3)

		last_segment_point = current_segment_point
		current_segment_point = a * curve_start_position + b * curve_start_position_tangent + c * curve_end_position_tangent + d * curve_end_position
		segment_length := rl.Vector2Length(current_segment_point - last_segment_point)

		for current_length + segment_length >= next_point_length {
			point := la.lerp(last_segment_point, current_segment_point, (next_point_length - current_length) / segment_length)
			rl.DrawCircleV(point, 20, rl.BLUE)

			next_point_length += point_distance
		}

		current_length += segment_length
    }
}

select_card :: proc(proc_data: ^Render_Card_Proc_Data) {
	reward_toggle = false

	append(&player.player_cards.discard, Card{definition = proc_data.card_definition})
}

next_wave :: proc() {
	reward_toggle = false
}

return_to_title :: proc() {
	reward_toggle = false
}

render_select_reward :: proc(mouse_pos: rl.Vector2) {
	current_screen_width := f32(rl.GetScreenWidth())
	current_screen_height := f32(rl.GetScreenHeight())

	rl.DrawRectangleV({current_screen_width / 2 - CARD_WIDTH * 1.5 - 40, current_screen_height / 2 - CARD_HEIGHT / 2 - 60}, {CARD_WIDTH * 3 + 80, CARD_HEIGHT + 120}, rl.ColorAlpha(rl.BLACK, 0.5))
	render_card(&card_definitions[0], mouse_pos, {current_screen_width / 2, current_screen_height / 2 - 30}, 0, rl.GRAY, rl.WHITE, nil, select_card, &Render_Card_Proc_Data{pass_definition = true})
	render_card(&card_definitions[0], mouse_pos, {current_screen_width / 2 - CARD_WIDTH - 20, current_screen_height / 2 - 30}, 0, rl.GRAY, rl.WHITE, nil, select_card, &Render_Card_Proc_Data{pass_definition = true})
	render_card(&card_definitions[0], mouse_pos, {current_screen_width / 2 + CARD_WIDTH + 20, current_screen_height / 2 - 30}, 0, rl.GRAY, rl.WHITE, nil, select_card, &Render_Card_Proc_Data{pass_definition = true})

	// rl.DrawRectanglePro({current_screen_width / 2, current_screen_height / 2 - 40, 600, 40}, {300,20}, -20, rl.RED)
	// rl.DrawTextPro(rl.GetFontDefault(), "NOT IMPLEMENTED", {current_screen_width / 2, current_screen_height / 2 - 40}, {f32(rl.MeasureText("NOT IMPLEMENTED", 40) / 2),20}, -20, 40, 4, rl.WHITE)
	render_hover_button(mouse_pos, "Skip Reward", {current_screen_width / 2 - 70 - 100, current_screen_height / 2 + 180, 140, 40}, 20, next_wave)
	render_hover_button(mouse_pos, "Quit", {current_screen_width / 2 - 70 + 100, current_screen_height / 2 + 180, 140, 40}, 20, return_to_title)
}
