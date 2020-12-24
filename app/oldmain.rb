# Fair warning, I will be using semi-colons to condense code
class Drawable
  attr_accessor :x, :y, :w, :h, :r, :g, :b, :a
  def primitive_marker; :sprite end

  def initialize(x, y, w, h, r, g, b, a)
    @x, @y, @w, @h = x, y, w, h
    @r, @g, @b, @a = r, g, b, a
  end

  def box; [@x, @y, @w, @h] end

  def draw_override(ffi_draw)
    ffi_draw.draw_solid(@x, @y, @w, @h, @r, @g, @b, @a)
  end
end

class Label < Drawable # Just a label
  def initialize(x:, y:, text:, se: 0, ae: 0, r: 255, g: 255, b: 255, a: 255)
    w, h = $gtk.calcstringbox(text, se)
    super(x, y, w, h, r, g, b, a)
    @text = text
    @se, @ae = se, ae
  end

  def box; [@x, @y - @h, @w, @h] end

  def draw_override(ffi_draw)
    ffi_draw.draw_label(@x, @y, @text, @se, @ae, @r, @g, @b, @a, nil)
  end
end

class LabelBox < Drawable # Used for the description text, basically does text wrapping
  def initialize(x, y, w, h, text, fit: false, se: 0, ae: 0, r: 255, g: 255, b: 255, a: 255)
    super(x, y, w, h, r, g, b, a)
    @se, @ae = se, ae
    set_text(text, fit)
  end

  def set_text(text, fit)
    @text = text
    if fit
      w, _ = $gtk.calcstringbox(' ', @se)
      chars = (@w / w).to_i
      @labels = text.wrapped_lines(chars).map.with_index do |line, i|
        Label.new(x: @x, y: @y + @h - 20*i, text: line,
                  se: @se, ae: @ae,
                  r: @r, g: @g, b: @b, a: @a)
      end
    else
      @labels = [Label.new(x: @x, y: @y + @h, text: @text,
                           se: @se, ae: @ae,
                           r: @r, g: @g, b: @b, a: @a)]
    end
  end

  def draw_override(ffi_draw)
    idx  = 0
    ilen = @labels.length
    while idx < ilen
      @labels.value(idx).draw_override(ffi_draw)
      idx += 1
    end
  end
end

module ButtonInteracts
  def inpt(inputs)
    @hovered = inputs.mouse.point&.inside_rect?(box)
    action if clicked? inputs
  end

  def clicked?(inputs)
    return inputs.mouse.click&.inside_rect?(box)
  end

  def action; end
end

class Button < Drawable
  include ButtonInteracts

  def initialize(x, y, w, h, text, se: 0, ae: 1, r: 255, g: 255, b: 255, a: 255)
    super(x, y, w, h, r, g, b, a)
    @text = text
    @se, @ae = se, ae
    @tw, @th = $gtk.calcstringbox(text, se)
  end

  def draw_override(ffi_draw)
    r, g, b = @hovered ? [@r - 50, @g - 50, @b - 50] : [@r, @g, @b]
    ffi_draw.draw_solid(@x, @y, @w, @h, r, g, b, @a)
    ffi_draw.draw_label(@x + @w.half, @y + @h.half + @th.half, @text, @se, @ae, 0, 0, 0, @a, nil)
  end
end

class Hyperlink < Label
  include ButtonInteracts
  attr :url, :clicked

  def initialize(x, y, title, url)
    super(x: x, y: y, text: title, r: 0, g: 238, b: 238)
    @url = url
  end

  def action; $gtk.openurl @url end

  def draw_override(ffi_draw)
    ffi_draw.draw_solid @x, @y - @h, @w, @h * 0.1, @r, @g, @b, @a if @hovered
    ffi_draw.draw_label @x, @y, @text, @se, @ae, @r, @g, @b, @a, nil
  end
end

class PseudoTarget # :o mfw you want render targets without render targets
  def primitive_marker; :sprite end

  def initialize(*objs)
    @objs = objs
    @x = @y = 0
  end

  def x=(arg)
    x = @x
    for obj in @objs
      ox = obj.x
      obj.x = ox + (arg - x)
    end
    @x = arg
  end

  def y=(arg)
    y = @y
    for obj in @objs
      oy = obj.y
      obj.y = oy + (arg - y)
    end
    @y = arg
  end

  def draw_override(ffi_draw)
    for obj in @objs
      obj.draw_override(ffi_draw)
    end
  end
end

# List of labels going downwards
def label_list(x, y, strings, min_h: 20, se: 0, ae: 0, r: 255, g: 255, b: 255, a: 255)
  return strings.take_while.with_index { |_, i| y - 20*i > min_h }.map_with_index do |str, i|
    str = y - 20*i > min_h + 20 ? str : '[...]'
    { x: x,
      y: y - 20*i,
      text: str,
      size_enum: se,
      alignment_enum: ae,
      r: r,
      g: g,
      b: b,
      a: a }.label
  end
end

# List of labels going up
def label_list_inv(x, y, strings, max_h: 720, se: 0, ae: 0, r: 255, g: 255, b: 255, a: 255)
  return strings.reverse.take_while.with_index { |_, i| y + 20*i < max_h }.map_with_index do |str, i|
    str = y + 20*i < max_h - 20 ? str : '[...]'
    { x: x,
      y: y + 20*i,
      text: str,
      size_enum: se,
      alignment_enum: ae,
      r: r,
      g: g,
      b: b,
      a: a }.label
  end
end

W, H = 1280, 720
PNG_W, PNG_H = 315, 250

OS   = $gtk.platform
PATH = $gtk.argv.split('/')[0..-3].join('/') # Only used for MacOS

GAMES = $gtk.parse_json_file 'entries.json'
GAMES.each do |g|
  # Set default png if given png does not exist for whatever reason
  g['png'] = 'dragonruby.png' unless g['png']&.end_with? '.png'
  # Create hyperlinks for each entry
  w, h = 640 - PNG_W.half, 330 - PNG_H.half
  g['aut_link'] = Hyperlink.new w, h, 'Visit Author Page!', g['aut_url']    if g['aut_url'] != ''
  g['jam_link'] = Hyperlink.new w, h - 30, 'Visit Game Page!', g['jam_url'] if g['jam_url'] != ''
end

def launch(name) # Give it the JSON's 'run' string
  case OS
  when 'Mac Os X' then $gtk.exec "open \".#{PATH}/Library/#{name}.app\""
  when 'Linux'    then $gtk.exec ".\"/Library/#{name}-linux-amd64.bin\""
  when 'Windows'  then $gtk.exec "cmd /c \"Library\\#{name}-windows-amd64.exe\""
  end
end

def init(args, state)
  state.key = args.inputs.keyboard.key_down

  state.idx     = 0
  state.idx_max = GAMES.length
  state.jdx     = 0
  state.iv      = 0
  state.play    = false

  state.shift    = false
  state.shift_x  = -W
  state.shift_y  = 0
  state.speed    = 100
  state.x_set_to = 0
  state.y_set_to = 0

  state.play_button     = Button.new  870,  20, 410, 80,    'PLAY', r: 144, g: 238, b: 144, se: 16
  state.credits_button  = Button.new 1180, 700, 100, 20, 'CREDITS', r: 144, g: 238, b: 238
  state.exit_credits_bt = Button.new 1255, 695,  25, 25,       '<', r: 238, g: 144, b: 144

  state.main_jam_link = Hyperlink.new(870, 720, 'Visit TeenyTiny Jam Page', 'https://itch.io/jam/teenytiny-dragonruby-minigamejam-2020')
  state.aut_link      = GAMES[state.jdx]['aut_link']
  state.jam_link      = GAMES[state.jdx]['jam_link']

  # state.menu = [ state.play_button,
  #                [870, 700, 410, 20, [0]*3].solid,
  #                state.main_jam_link,
  #                state.credits_button,
  #                Drawable.new(0, 0, 1280, 20, 0, 0, 50, 255),
  #                Label.new(x: 640, y: 20, text: "MOVE: ↑/↓ or Mouse Wheel  PLAY: Enter  EXIT: Esc  CREDITS: c", ae: 1)]

  state.selection_labels = []

  state.menu = PseudoTarget.new(
    state.play_button,
    Drawable.new(870, 700, 410, 20, 0, 0, 0, 255),
    state.main_jam_link,
    state.credits_button,
    Drawable.new(0, 0, 1280, 20, 0, 0, 50, 255),
    Label.new(x: 640, y: 20, text: "MOVE: ↑/↓ or Mouse Wheel  PLAY: Enter  EXIT: Esc  CREDITS: c", ae: 1))

  state.mode = :main
end

def updt(args, state)
  case state.mode
  when :main
    state.play_button.inpt(args.inputs)
    state.credits_button.inpt(args.inputs)

    if !state.play && state.xsnap && state.ysnap
      if state.key.enter || state.play_button.clicked?(args.inputs)
        state.play     = true
        state.x_set_to = -W
      end

      if state.key.c || state.credits_button.clicked?(args.inputs)
        state.mode     = :credits
        state.x_set_to = W
      end

      state.main_jam_link.inpt args.inputs
      state.aut_link.inpt      args.inputs
      state.jam_link.inpt      args.inputs
    end

    if state.key.up_down != 0
      args.outputs.sounds << 'sounds/rollover2.wav'
      state.iv   = state.key.up_down
      state.idx -= state.iv
      state.idx  = state.idx % state.idx_max

      state.shift    = true
      state.y_set_to = state.iv < 0 ? H : -H
    end

    wheel = args.inputs.mouse.wheel
    if wheel
      args.outputs.sounds << 'sounds/rollover2.wav'
      state.iv   = wheel[:y]
      state.idx -= state.iv
      state.idx  = state.idx % state.idx_max

      state.shift    = true
      state.y_set_to = state.iv < 0 ? H : -H
    end

    state.shift_x = state.shift_x.towards(state.x_set_to, state.speed)
    state.shift_y = state.shift_y.towards(state.y_set_to, state.speed)
    state.xsnap   = state.shift_x == state.x_set_to
    state.ysnap   = state.shift_y == state.y_set_to

    if state.shift && state.ysnap
      state.jdx      = state.idx
      state.shift    = false
      state.shift_y  = 0
      state.y_set_to = 0
      state.aut_link = GAMES[state.jdx]['aut_link']
      state.jam_link = GAMES[state.jdx]['jam_link']
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

  when :credits
    state.exit_credits_bt.inpt(args.inputs)
    if state.xsnap and state.key.c || state.exit_credits_bt.clicked?(args.inputs)
      state.mode = :main
      state.x_set_to = 0
    end

    state.shift_x = state.shift_x.towards(state.x_set_to, state.speed)
    state.shift_y = state.shift_y.towards(state.y_set_to, state.speed)
    state.xsnap   = state.shift_x == state.x_set_to
    state.ysnap   = state.shift_y == state.y_set_to
  end

  $gtk.exit if state.key.escape
end

# Render Target 'Cards'... makes it easier to do a slide animation
def card_rndr(args, name, game)
  card = args.render_target name
  card.sprites << [640 - PNG_W.half, 360 - PNG_H.half, PNG_W, PNG_H, 'shots/' + game['png']]
  card.labels  << [640 - PNG_W.half, 360 - PNG_H.half, "Author: #{game['author']}", [255]*3]

  if game['aut_link']
    card.labels << [
      game['aut_link'],
      game['jam_link'],
      [640 - PNG_W.half, 270 - PNG_H.half, 'Support/Check out this author!', [255]*3].label
    ]
  end

  description = game['description']
  card.labels << LabelBox.new(870, 360 - PNG_H.half, 400, PNG_H, description, fit: true) if description
end

def rndr(args, state)
  case state.mode
  when :main
    tw, th = args.gtk.calcstringbox(GAMES[state.idx]['title'], 8)
    mth = th
    s = 8
    while tw > 480
      s /= 2
      tw, mth = args.gtk.calcstringbox(GAMES[state.idx]['title'], s)
    end

    menu = args.render_target(:menu)
    menu.primitives << [
      label_list_inv(20, 360 + th + 20, GAMES[0...state.idx].map { |g| g['title'] }, r: 80, g: 80, b: 80),
      [(640 - PNG_W.half).half, 360 + mth.half, GAMES[state.idx]['title'], s, 1, [255]*3].label,
      label_list(20, 360 - th, GAMES[state.idx+1..-1].map { |g| g['title'] }, min_h: 40, r: 80, g: 80, b: 80),
      # state.menu
    ]

    card_rndr(args, :card, GAMES[state.jdx])
    card_rndr(args, :nextcard, GAMES[(state.jdx - state.iv) % state.idx_max])

    args.outputs.background_color = [0]*3
    args.outputs.sprites << [state.shift_x - W, 0, W, H, :next_card] if state.shift_x > 0
    args.outputs.sprites << [
      [state.shift_x, state.shift_y, W, H, :card],
      [state.shift_x, (state.iv < 0 ? -H : H) + state.shift_y, W, H, :nextcard],
      [state.shift_x, 0, W, H, :menu],
      [state.shift_x + W, 0, W, H, 'tiny_jam_logo.png']
    ]

  when :credits
    # lol
    credit_card = args.render_target(:next_card)
    credit_card.sprites << [
      [0, 0, 1280, 720, 'credits.png'],
      state.exit_credits_bt
    ]

    args.outputs.background_color = [0]*3
    args.outputs.sprites << [
      [state.shift_x - W, 0, W, H, :next_card],
      [state.shift_x, 0, W, H, :card],
      [state.shift_x, 0, W, H, :menu],
    ]
  end

  state.menu.x = state.shift_x
  args.outputs.primitives << state.menu
end

def tick(args)
  state = args.state
  init args, state if args.tick_count < 1
  updt args, state if args.tick_count > 30
  rndr args, state
end
