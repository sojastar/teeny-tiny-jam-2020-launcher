os = $gtk.exec('uname -s')
OS = os != '' && os || 'Windows'
GAMES = $gtk.read_file('game_list.txt').split("\n").sort

def launch(game)
  return $gtk.exec("") if OS == 'Darwin'
  return $gtk.exec("./Library/#{game}.bin") if OS == 'Linux'
  return $gtk.exec("cmd /c Library\\#{game}.exe") if OS == 'Windows'
end

def to_title(game)
  return game.split('_').map(&:capitalize).join(' ')
end

def game_png(game)
  return "screenshots/#{game}.png"
end

def label_list(x, y, strings, se = 0, ae = 0, r = 255, g = 255, b = 255, a = 255)
  strings.map_with_index { |str, i| [x, y - 20*i, str, se, ae, r, g, b, a].label }
end

def label_list_inv(x, y, strings, se = 0, ae = 0, r = 255, g = 255, b = 255, a = 255)
  strings.reverse.map_with_index { |str, i| [x, y + 20*i, str, se, ae, r, g, b, a].label }
end

def tick(args)
  state           = args.state
  state.key     ||= args.inputs.keyboard.key_down
  state.opac    ||= 0
  state.fade    ||= 0
  state.fade_to ||= 0
  state.idx     ||= 0
  state.png_w   ||= 315
  state.png_h   ||= 250

  state.idx  += 1 if state.key.down
  state.idx  -= 1 if state.key.up
  state.idx   = state.idx % GAMES.length
  state.game  = GAMES[state.idx]

  if state.key.enter
    state.play    = true
    state.fade    = 20
    state.fade_to = 255
  end
  state.opac = state.opac.towards(state.fade_to, state.fade)

  if state.play && state.opac == state.fade_to
    launch(state.game)
    state.play = false
    state.fade_to = 0
  end

  args.outputs.background_color = [25]*3
  args.outputs.primitives << label_list_inv(20, 390, GAMES[0...state.idx].map { |g| to_title(g) }, 0, 0, *[100]*3)
  args.outputs.primitives << [20, 360, to_title(state.game), 16, 0, [255]*3].label
  args.outputs.primitives << label_list(20, 300, GAMES[state.idx+1..-1].map { |g| to_title(g) }, 0, 0, *[100]*3)
  args.outputs.primitives << [640 - state.png_w.half, 360 - state.png_h.half, state.png_w, state.png_h, game_png(state.game)].sprite
  args.outputs.primitives << [0, 0, 1280, 720, 'tiny_jam_logo.png', 0, state.opac].sprite
end
