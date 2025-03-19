package game

import "core:encoding/csv"
import "core:fmt"
import "core:math/rand"
import "core:slice"

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
    use_cost: int,
    kind: Card_Kind,
    data: union {
        Card_Action,
        Card_Upgrade,
    },
}

Card_Upgrade :: struct {

}

Card_Action :: struct {

}

cards := string(#load("card_definitions.csv"))

setup_card_definitions :: proc(definitions: ^[dynamic]Card_Definition) {
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
	shuffle_cards(discard)
	move_cards(draw, discard, len(discard))
	move_cards(hand, draw, remaining_cards)
}
