def to_title(game)
  return game.split('_').map(&:capitalize).join(' ')
end

def game_png(game)
  return "screenshots/#{game}.png"
end

def label_list(x, y, strings, se = 0, ae = 0, r = 255, g = 255, b = 255, a = 255)
  return strings.map_with_index { |str, i| [x, y - 20*i, str, se, ae, r, g, b, a].label }
end

def label_list_inv(x, y, strings, se = 0, ae = 0, r = 255, g = 255, b = 255, a = 255)
  return strings.reverse.map_with_index { |str, i| [x, y + 20*i, str, se, ae, r, g, b, a].label }
end

os     = $gtk.exec('uname -s')
OS     = os != '' && os.chomp || 'Windows'
PATH   = File.expand_path File.dirname(__FILE__)
GAMES  = $gtk.read_file('game_list.txt').split("\n").sort
TITLES = GAMES.map { |game| to_title game }
W, H   = 1280, 720

def launch(game)
  $gtk.exec("open .#{PATH}/Library/#{game}.app") if OS == 'Darwin'
  $gtk.exec("./Library/#{game}.bin")             if OS == 'Linux'
  $gtk.exec("cmd /c Library\\#{game}.exe")       if OS == 'Windows'
  return
end

def init args, state
  state.key = args.inputs.keyboard.key_down

  state.idx     = 0
  state.idx_max = GAMES.length
  state.jdx     = 0
  state.iv      = 0
  state.play    = false

  state.png_w   = 315
  state.png_h   = 250

  state.shift    = false
  state.shift_x  = -W
  state.shift_y  = 0
  state.speed    = 100
  state.x_set_to = 0
  state.y_set_to = 0
end

def updt args, state
  if !state.play && state.xsnap && state.ysnap
    if state.key.up_down != 0
      state.iv    = state.key.up_down
      state.idx  -= state.iv
      state.idx   = state.idx % state.idx_max

      state.shift    = true
      state.y_set_to = state.iv < 0 ? H : -H
    end

    if state.key.enter
      state.play   = true
      state.x_set_to = -W
    end
  end

  state.shift_x = state.shift_x.towards(state.x_set_to, state.speed)
  state.shift_y = state.shift_y.towards(state.y_set_to, state.speed)
  state.xsnap = state.shift_x == state.x_set_to
  state.ysnap = state.shift_y == state.y_set_to

  if state.shift && state.ysnap
    state.jdx      = state.idx
    state.shift    = false
    state.shift_y  = 0
    state.y_set_to = 0
  end

  if state.play && state.xsnap
    state.wait_a_tick ||= args.tick_count
    if state.wait_a_tick.elapsed?(1)
      launch(GAMES[state.idx])
      state.play = false
      state.x_set_to = 0
      state.wait_a_tick = nil
    end
  end
end

def rend args, state
  menu = args.render_target(:menu)
  menu.primitives << label_list_inv(20, 390, TITLES[0...state.idx], 0, 0, *[100]*3)
  menu.primitives << [20, 360, TITLES[state.idx], 16, 0, [255]*3].label
  menu.primitives << label_list(20, 300, TITLES[state.idx+1..-1], 0, 0, *[100]*3)

  card = args.render_target(:card)
  card.sprites << [640 - state.png_w.half, 360 - state.png_h.half, state.png_w, state.png_h, game_png(GAMES[state.jdx])]

  nextcard = args.render_target(:nextcard)
  nextcard.sprites << [640 - state.png_w.half, 360 - state.png_h.half, state.png_w, state.png_h, game_png(GAMES[(state.jdx-state.iv)%state.idx_max])]

  args.outputs.background_color = [25]*3
  args.outputs.sprites << [state.shift_x, 0, W, H, :menu]
  args.outputs.sprites << [state.shift_x + W, 0, W, H, 'tiny_jam_logo.png']

  args.outputs.sprites << [state.shift_x, state.shift_y, W, H, :card]
  args.outputs.sprites << [state.shift_x, (state.iv < 0 ? -H : H) + state.shift_y, W, H, :nextcard]
end

def tick args
  state = args.state
  init args, state if args.tick_count < 1
  updt args, state if args.tick_count > 30
  rend args, state
end
