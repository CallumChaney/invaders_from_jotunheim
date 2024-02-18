package main

import "core:fmt"
import "core:math/rand"
import SDL "vendor:sdl2"

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

FPS :: 60
FRAME_TIME :: 1000 / 60


SHIP_SPEED :: 10

ALIEN_SIZE :: 30

ALIEN_GRID_COLS :: 6
ALIEN_GRID_ROWS :: 6
ALIEN_GRID_GAP :: 30
ALIEN_GRID_VOFF :: SCREEN_WIDTH / 3
ALIEN_GRID_HOFF :: 50
ALIEN_GRID_WIDTH :: ALIEN_GRID_COLS * (ALIEN_GRID_GAP + ALIEN_SIZE)


NUM_SHIELDS :: 5

Entity :: struct {
	position: [2]i32,
	velocity: [2]i32,
	size:     [2]i32,
	destroy:  bool,
}

Shield :: struct {
	blocks: [36]Entity,
}

Player :: distinct Entity
Projectile :: distinct Entity
Alien :: distinct Entity

Game :: struct {
	window:   ^SDL.Window,
	renderer: ^SDL.Renderer,
	state:    struct {
		player:      Player,
		projectiles: [dynamic]Projectile,
		aliens:      [dynamic]Alien,
		shields:     [dynamic]Shield,
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

	for i: i32 = 0; i < 6; i += 1 {
		for j: i32 = 0; j < 6; j += 1 {
			append(
				&game.state.aliens,
				Alien{{512 + (60 * i), 50 + (60 * j)}, {0, 0}, {30, 30}, false},
			)
		}
	}

	for i: i32 = 0; i < NUM_SHIELDS; i += 1 {

		shield: Shield

		for j: i32 = 0; j < 6; j += 1 {
			for k: i32 = 0; k < 6; k += 1 {
				idx := j + k * 6
				shield.blocks[idx] =  {
					{(10 * j) + 100 + (260 * i), SCREEN_HEIGHT - 200 + (10 * k)},
					{0, 0},
					{10, 10},
					false,
				}
			}
		}

		append(&game.state.shields, shield)
	}


	frame_start, frame_length: u32

	for {
		frame_start = SDL.GetTicks()

		handle_input(&game)

		update(&game)

		render(&game)

		frame_length = SDL.GetTicks() - frame_start

		if frame_length < FRAME_TIME {
			SDL.Delay(FRAME_TIME - frame_length)
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
			{state.player.position.x + state.player.size.x / 2, state.player.position.y - 10},
			{0, -50},
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
		projectile.position += projectile.velocity

		if projectile.position.y < 0 || projectile.position.y > SCREEN_HEIGHT {
			projectile.destroy = true
		}

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
			//state.player.destroy = true
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
	}

	alien_shoot :: proc(using game: ^Game, alien: Alien) {
		projectile: Projectile =  {
			{alien.position.x + alien.size.x / 2, alien.position.y + 10},
			{0, 50},
			{5, 20},
			false,
		}
		append(&state.projectiles, projectile)
	}


	for alien in &state.aliens {
		if rand.float32() < 0.0005 {
			alien_shoot(game, alien)
		}
		if rand.float32() < 0.005 && abs(alien.position.x - state.player.position.x) < 50 {
			alien_shoot(game, alien)
		}
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
		SDL.SetRenderDrawColor(renderer, 45, 150, 69, 255)
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
