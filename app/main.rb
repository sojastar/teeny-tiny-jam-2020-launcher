# https://itch.io/jam/teenytiny-dragonruby-minigamejam-2020

class Hyperlink
  attr :url, :clicked

  def initialize(title, url)
    @title   = title
    @url     = url
    @w, @h   = $gtk.calcstringbox(title)
    @hovered = false
    @clicked = false
  end

  def box
    return [@x, @y - @h, @w, @h]
  end

  def inpt inputs
    m  = inputs.mouse
    p1 = m.point
    p2 = m.click
    @hovered = p1.inside_rect?(self.box) ? true : false
    @clicked = true if p2&.inside_rect?(self.box)
    return
  end

  def rndr x, y
    @x = x
    @y = y
    a = { x: @x, y: @y, text: @title, r: 10, g: 238, b: 238}.label
    b = { x: @x, y: @y - @h, w: @w + @w * 0.1, h: 2, r: 10, g: 238, b: 238}.solid if @hovered
    return [a, b]
  end
end

def label_list(x, y, strings, se = 0, ae = 0, r = 255, g = 255, b = 255, a = 255)
  return strings.map_with_index { |str, i| [x, y - 20*i, str, se, ae, r, g, b, a].label }
end

def label_list_inv(x, y, strings, se = 0, ae = 0, r = 255, g = 255, b = 255, a = 255)
  return strings.reverse.map_with_index { |str, i| [x, y + 20*i, str, se, ae, r, g, b, a].label }
end

os     = $gtk.exec('uname -s')
OS     = os != '' && os.chomp || 'Windows'
PATH   = $gtk.argv.split('/')[0..-3].join('/')
GAMES  = $gtk.parse_json_file('entries.json')
GAMES.each do |g|
  g['aut_link'] = Hyperlink.new('Visit Author Page!', g['aut_url'])
  g['jam_link'] = Hyperlink.new('Visit Jam Page!', g['jam_url'])
end
W, H   = 1280, 720

def launch game
  $gtk.exec("open \".#{PATH}/Library/#{game}.app\"")         if OS == 'Darwin'
  $gtk.exec(".\"/Library/#{game}-linux-amd64.bin\"")         if OS == 'Linux'
  $gtk.exec("cmd /c \"Library\\#{game}-windows-amd64.exe\"") if OS == 'Windows'
  return
end

def openurl url
  $gtk.exec("open \"#{url}\"")                              if OS == 'Darwin'  # TODO: Detatch process
  $gtk.exec("xdg-open \"#{url}\" </dev/null &>/dev/null &") if OS == 'Linux'
  $gtk.exec("cmd /c start \"#{url}\"")                      if OS == 'Windows'
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

    link1 = GAMES[state.jdx]['aut_link']
    link2 = GAMES[state.jdx]['jam_link']

    link1.inpt(args.inputs)
    link2.inpt(args.inputs)

    if link1.clicked
      link1.clicked = false
      openurl(link1.url)
    end
    if link2.clicked
      link2.clicked = false
      openurl(link2.url)
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
      launch(GAMES[state.idx]['run'])
      state.play = false
      state.x_set_to = 0
      state.wait_a_tick = nil
    end
  end
end

def rndr args, state
  menu = args.render_target(:menu)
  menu.primitives << label_list_inv(20, 390, GAMES[0...state.idx].map { |g| g['title'] }, 0, 0, *[100]*3)
  menu.primitives << [20, 360, GAMES[state.idx]['title'], 16, 0, [255]*3].label
  menu.primitives << label_list(20, 300, GAMES[state.idx+1..-1].map { |g| g['title'] }, 0, 0, *[100]*3)

  card = args.render_target(:card)
  card.sprites << [640 - state.png_w.half, 360 - state.png_h.half, state.png_w, state.png_h, GAMES[state.jdx]['png']]
  card.labels  << [640 - state.png_w.half, 360 - state.png_h.half, "Author: #{GAMES[state.jdx]['author']}", [255]*3]
  card.primitives  << GAMES[state.jdx]['aut_link'].rndr(640 - state.png_w.half, 330 - state.png_h.half)
  card.primitives  << GAMES[state.jdx]['jam_link'].rndr(640 - state.png_w.half, 300 - state.png_h.half)

  jdx = (state.jdx - state.iv) % state.idx_max
  nextcard = args.render_target(:nextcard)
  nextcard.sprites << [640 - state.png_w.half, 360 - state.png_h.half, state.png_w, state.png_h, GAMES[jdx]['png']]
  nextcard.labels  << [640 - state.png_w.half, 360 - state.png_h.half, "Author: #{GAMES[jdx]['author']}", [255]*3]

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
  rndr args, state
end
