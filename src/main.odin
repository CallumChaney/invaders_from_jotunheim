package main

import "core:fmt"
import SDL "vendor:sdl2"


SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

FPS :: 60
FRAME_TIME :: 1000 / 60


Entity :: struct {
	position: [2]i32,
	velocity: [2]i32,
	size:     [2]i32,
	destroy:  bool,
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
	},
}

main :: proc() {
	game := sdl_init()

	assert(&game != nil, "Failed to create game")
	defer {
		delete(game.state.projectiles)
		delete(game.state.aliens)
		SDL.DestroyWindow(game.window)
		SDL.DestroyRenderer(game.renderer)
	}

	game.state.player.position = {SCREEN_WIDTH / 2, SCREEN_HEIGHT - 100}

	game.state.player.size = {60, 60}

	append(&game.state.aliens, Alien{{SCREEN_WIDTH / 2, 150}, {0, 0}, {30, 30}, false})

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

	return game
}


SHIP_SPEED :: 10

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
			{state.player.position.x + 30, state.player.position.y - 10},
			{0, -50},
			{5, 20},
			false,
		}
		append(&state.projectiles, projectile)
	}
}

update :: proc(using game: ^Game) {

	state.player.position += state.player.velocity


	rect_collison :: proc(rect1: SDL.Rect, rect2: SDL.Rect) -> bool {
		if rect1.x < rect2.x + rect2.w &&
		   rect1.x + rect1.w > rect2.x &&
		   rect1.y < rect2.y + rect2.h &&
		   rect1.y + rect1.h > rect2.y {
			fmt.println("Collide")
			return true
		}

		return false
	}

	for projectile in &state.projectiles {
		projectile.position += projectile.velocity

		for alien in &state.aliens {
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

	if len(state.projectiles) <= 0 {
		return
	}
	for i in len(state.projectiles) - 1 ..= 0 {
		if state.projectiles[i].destroy == true {
			unordered_remove(&state.projectiles, i)
		}
	}
	if len(state.aliens) <= 0 {
		return
	}
	for i in len(state.aliens) - 1 ..= 0 {
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
	SDL.RenderPresent(renderer)
}
