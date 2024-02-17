package main

import SDL "vendor:sdl2"


SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

Game :: struct {
	window:   ^SDL.Window,
	renderer: ^SDL.Renderer,
	state:    struct {
		player: struct {
			position: [2]i32,
			velocity: [2]i32,
		},
	},
}

main :: proc() {
	game := sdl_init()

	defer {
		SDL.DestroyWindow(game.window)
		SDL.DestroyRenderer(game.renderer)
	}

	game.state.player.position = {SCREEN_WIDTH / 2, SCREEN_HEIGHT - 100}
	for {
		handle_input(&game)

		update(&game)

		render(&game)
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

handle_input :: proc(using game: ^Game) {
	event: SDL.Event

	for SDL.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			SDL.Quit()

		case .KEYDOWN:
			#partial switch event.key.keysym.sym {
			case .a:
				state.player.velocity.x = -1
			case .d:
				state.player.velocity.x = 1
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
}

update :: proc(using game: ^Game) {
	state.player.position += state.player.velocity
}

render :: proc(using game: ^Game) {

	SDL.SetRenderDrawColor(renderer, 53, 53, 53, 255)
	SDL.RenderClear(renderer)

	SDL.SetRenderDrawColor(renderer, 45, 73, 69, 255)
	SDL.RenderFillRect(renderer, &{state.player.position.x, state.player.position.y, 60, 60})


	SDL.RenderPresent(renderer)
}
