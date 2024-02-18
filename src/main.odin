package main

import "core:math/rand"
import "core:os"
import SDL "vendor:sdl2"

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

FPS :: 60
FRAME_DELAY :: 1000 / FPS
FRAME_DELAY_SECS :: 1 / FPS


SHIP_SPEED :: 10

ALIEN_SIZE :: 30

ALIEN_GRID_COLS :: 6
ALIEN_GRID_ROWS :: 6
ALIEN_GRID_GAP :: 60
ALIEN_GRID_VOFF :: 50
ALIEN_GRID_HOFF :: 512
ALIEN_GRID_WIDTH :: ALIEN_GRID_COLS * (ALIEN_GRID_GAP + ALIEN_SIZE)
ALIEN_MOVE_TIME :: 500

NUM_SHIELDS :: 5

Entity :: struct {
	position: [2]i32,
	velocity: [2]i32,
	size:     [2]i32,
	destroy:  bool,
}

Shield :: struct {
	blocks: [dynamic]Entity,
}

Player :: distinct Entity
Projectile :: distinct Entity
Alien :: distinct Entity

Game :: struct {
	window:   ^SDL.Window,
	renderer: ^SDL.Renderer,
	state:    struct {
		player:               Player,
		projectiles:          [dynamic]Projectile,
		aliens:               [dynamic]Alien,
		alien_move_timer:     u32,
		alien_move_direction: i32,
		alien_move_down:      bool,
		shields:              [dynamic]Shield,
		lives:                u8,
	},
}

main :: proc() {
	game := sdl_init()

	defer {
		delete(game.state.projectiles)
		delete(game.state.aliens)
		SDL.DestroyWindow(game.window)
		SDL.DestroyRenderer(game.renderer)
	}

	game.state.player.position = {SCREEN_WIDTH / 2, SCREEN_HEIGHT - 100}

	game.state.player.size = {60, 60}

	game.state.alien_move_direction = 1
	game.state.lives = 3
	for i: i32 = 0; i < 6; i += 1 {
		for j: i32 = 0; j < 6; j += 1 {
			append(
				&game.state.aliens,
				Alien {
					 {
						ALIEN_GRID_HOFF + (ALIEN_GRID_GAP * i),
						ALIEN_GRID_VOFF + (ALIEN_GRID_GAP * j),
					},
					{0, 0},
					{ALIEN_SIZE, ALIEN_SIZE},
					false,
				},
			)
		}
	}

	for i: i32 = 0; i < NUM_SHIELDS; i += 1 {

		shield: Shield

		for j: i32 = 0; j < 6; j += 1 {
			for k: i32 = 0; k < 6; k += 1 {
				idx := j + k * 6
				append(
					&shield.blocks,
					Entity {
						{(15 * j) + 100 + (260 * i), SCREEN_HEIGHT - 211 + (15 * k)},
						{0, 0},
						{15, 15},
						false,
					},
				)
			}
		}

		append(&game.state.shields, shield)
	}


	frame_start, frame_time: u32

	for !SDL.QuitRequested() {
		frame_start = SDL.GetTicks()

		handle_input(&game)

		update(&game)

		render(&game)

		frame_time = SDL.GetTicks() - frame_start

		if frame_time < FRAME_DELAY {
			SDL.Delay(FRAME_DELAY - frame_time)
		}
	}
}

sdl_init :: proc() -> (game: Game) {

	sdl_init_err := SDL.Init(SDL.INIT_VIDEO)

	assert(sdl_init_err == 0, SDL.GetErrorString())

	game.window = SDL.CreateWindow(
		"Space Invaders",
		SDL.WINDOWPOS_CENTERED,
		SDL.WINDOWPOS_CENTERED,
		SCREEN_WIDTH,
		SCREEN_HEIGHT,
		nil,
	)

	assert(game.window != nil, SDL.GetErrorString())

	game.renderer = SDL.CreateRenderer(game.window, -1, SDL.RENDERER_ACCELERATED)

	assert(game.renderer != nil, SDL.GetErrorString())

	return game
}


handle_input :: proc(using game: ^Game) {
	event: SDL.Event

	for SDL.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			SDL.Quit()

		case .KEYDOWN:
			#partial switch event.key.keysym.sym {
			case .a:
				state.player.velocity.x = -SHIP_SPEED
			case .d:
				state.player.velocity.x = SHIP_SPEED
			case .SPACE:
				player_shoot(game)
			}
		case .KEYUP:
			#partial switch event.key.keysym.sym {
			case .a:
				if state.player.velocity.x < 0 do state.player.velocity.x = 0
			case .d:
				if state.player.velocity.x > 0 do state.player.velocity.x = 0
			}
		}
	}

	player_shoot :: proc(using game: ^Game) {
		projectile: Projectile =  {
			{state.player.position.x + state.player.size.x / 2, state.player.position.y - 1},
			{0, -30},
			{5, 20},
			false,
		}
		append(&state.projectiles, projectile)
	}
}

update :: proc(using game: ^Game) {

	if state.player.destroy == true {
		SDL.Quit()
	}

	state.player.position += state.player.velocity


	if state.player.position.x - 30 < 0 {
		state.player.position.x = 30
	}

	if state.player.position.x > SCREEN_WIDTH - state.player.size.x - 15 {
		state.player.position.x = SCREEN_WIDTH - state.player.size.x - 15
	}
	rect_collison :: proc(rect1: SDL.Rect, rect2: SDL.Rect) -> bool {
		if rect1.x <= rect2.x + rect2.w &&
		   rect1.x + rect1.w >= rect2.x &&
		   rect1.y <= rect2.y + rect2.h &&
		   rect1.y + rect1.h >= rect2.y {
			return true
		}

		return false
	}

	for projectile in &state.projectiles {
		if projectile.destroy == true {
			continue
		}

		if projectile.position.y < 0 || projectile.position.y > SCREEN_HEIGHT {
			projectile.destroy = true
		}


		projectile.position += projectile.velocity

		if rect_collison(
			    {
				   projectile.position.x,
				   projectile.position.y,
				   projectile.size.x,
				   projectile.size.y,
			   },
			    {
				   state.player.position.x,
				   state.player.position.y,
				   state.player.size.x,
				   state.player.size.y,
			   },
		   ) {
			projectile.destroy = true
			state.lives -= 1
			if state.lives == 0 {
				SDL.Quit()
				os.exit(1)
			}
		}

		for alien in &state.aliens {

			if projectile.velocity.y > 0 {
				continue
			}
			if rect_collison(
				    {
					   projectile.position.x,
					   projectile.position.y,
					   projectile.size.x,
					   projectile.size.y,
				   },
				   {alien.position.x, alien.position.y, alien.size.x, alien.size.y},
			   ) {
				alien.destroy = true
				projectile.destroy = true
			}
		}

		for shield in &state.shields {

			for block in &shield.blocks {
				if rect_collison(
					    {
						   projectile.position.x,
						   projectile.position.y,
						   projectile.size.x,
						   projectile.size.y,
					   },
					   {block.position.x, block.position.y, block.size.x, block.size.y},
				   ) {
					block.destroy = true
					projectile.destroy = true
				}
			}
		}


	}


	alien_shoot :: proc(using game: ^Game, alien: Alien) {
		projectile: Projectile =  {
			{alien.position.x + alien.size.x / 2, alien.position.y + 10},
			{0, 10},
			{5, 20},
			false,
		}
		append(&state.projectiles, projectile)
	}

	outer_alien: ^Alien

	for &alien in &state.aliens {

		if outer_alien == nil {
			outer_alien = &alien
			continue
		}

		if state.alien_move_direction < 0 {
			if alien.position.x < outer_alien.position.x {
				outer_alien = &alien
				continue
			}
		} else if alien.position.x > outer_alien.position.x {
			outer_alien = &alien
		}
	}

	alien_move := state.alien_move_timer > ALIEN_MOVE_TIME

	if outer_alien.position.x > SCREEN_WIDTH - (ALIEN_SIZE + 30) ||
	   outer_alien.position.x - ALIEN_SIZE - 30 < 0 {
		state.alien_move_direction = -state.alien_move_direction
		state.alien_move_down = true
	}
	for alien in &state.aliens {

		if alien.destroy == true {
			continue
		}
		if alien_move {
			if state.alien_move_down {
				alien.position.y += ALIEN_SIZE
			} else {
				alien.position.x += ALIEN_SIZE * state.alien_move_direction
			}
		}
		if rand.float32() < 0.0005 {
			alien_shoot(game, alien)
		}
		if rand.float32() < 0.005 && abs(alien.position.x - state.player.position.x) < 50 {
			alien_shoot(game, alien)
		}
	}

	if alien_move {
		state.alien_move_timer = 0
		alien_move = false

		if state.alien_move_down {
			state.alien_move_down = false
		}

	} else {

		state.alien_move_timer += FRAME_DELAY
	}

	if len(state.projectiles) <= 0 {
		return
	}
	for i := len(state.projectiles) - 1; i >= 0; i -= 1 {
		if state.projectiles[i].destroy == true {
			unordered_remove(&state.projectiles, i)
		}
	}
	if len(state.aliens) <= 0 {
		return
	}
	for i := len(state.aliens) - 1; i >= 0; i -= 1 {
		if state.aliens[i].destroy == true {
			unordered_remove(&state.aliens, i)
		}
	}


	if len(state.shields) <= 0 {
		return
	}
	for shield in &state.shields {
		for i := len(shield.blocks) - 1; i >= 0; i -= 1 {
			if shield.blocks[i].destroy == true {
				unordered_remove(&shield.blocks, i)
			}
		}
	}
}

render :: proc(using game: ^Game) {

	SDL.SetRenderDrawColor(renderer, 53, 53, 53, 255)
	SDL.RenderClear(renderer)

	SDL.SetRenderDrawColor(renderer, 45, 73, 69, 255)
	SDL.RenderFillRect(
		renderer,
		& {
			state.player.position.x,
			state.player.position.y,
			state.player.size.x,
			state.player.size.y,
		},
	)

	for projectile in state.projectiles {
		SDL.SetRenderDrawColor(renderer, 45, 150, 69, 255)
		SDL.RenderFillRect(
			renderer,
			&{projectile.position.x, projectile.position.y, projectile.size.x, projectile.size.y},
		)
	}

	for alien in state.aliens {
		SDL.SetRenderDrawColor(renderer, 145, 55, 50, 255)
		SDL.RenderFillRect(
			renderer,
			&{alien.position.x, alien.position.y, alien.size.x, alien.size.y},
		)
	}
	for shield in state.shields {
		SDL.SetRenderDrawColor(renderer, 10, 10, 10, 255)

		for block in shield.blocks {
			SDL.RenderFillRect(
				renderer,
				&{block.position.x, block.position.y, block.size.x, block.size.y},
			)
		}
	}

	SDL.RenderPresent(renderer)
}
