class Label # Just a label
  def initialize x:, y:, text:, se: 0, ae: 0, r: 255, g: 255, b: 255, a: 255
    @x = x
    @y = y
    @text = text
    @se = se
    @ae = ae
    @r = r
    @g = g
    @b = b
    @a = a

    @w, @h = $gtk.calcstringbox(text, se)
  end

  def box
    return [@x, @y - @h, @w, @h]
  end

  def draw_override ffi_draw
    ffi_draw.draw_label @x, @y, @text, @se, @ae, @r, @g, @b, @a, nil
  end
end

class LabelBox # Used for the description text, basically does text wrapping
  def initialize x, y, w, h, text, fit: false, se: 0, ae: 0, r: 255, g: 255, b: 255, a: 255
    @x = x
    @y = y
    @w = w
    @h = h
    @labels = []
    @se = se
    @ae = ae
    @r = r
    @g = g
    @b = b
    @a = a

    set_text text, fit
  end

  def box
    return [@x, @y, @w, @h]
  end

  def set_text text, fit = false
    @text = text
    unless fit
      @labels = [
        Label.new(x: @x, y: @y + @h, text: @text,
                  se: @se, ae: @ae,
                  r: @r, g: @g, b: @b, a: @a)
      ]
    else
      text = text.split
      idx = 0
      until text.empty?
        break if @y + @h - 20*idx <= @y
        store = text.each_with_object([]) do |s, o|
          w, _ = $gtk.calcstringbox((o+[s]).join(' '), @se)
          break o if w > @w
          o << s
        end
        text = text[store.length..-1]
        @labels << Label.new(x: @x, y: @y + @h - 20*idx, text: store.join(' '),
                             se: @se, ae: @ae,
                             r: @r, g: @g, b: @b, a: @a)
        idx += 1
      end
    end
  end

  def draw_override ffi_draw
    idx  = 0
    ilen = @labels.length
    while idx < ilen
      (@labels.value idx).draw_override ffi_draw
      idx += 1
    end
  end
end

class Hyperlink < Label
  attr :url, :clicked

  def initialize x, y, title, url
    super(x: x, y: y, text: title, r: 0, g: 238, b: 238)
    @title   = title
    @url     = url
    @hovered = false
    @clicked = false
  end

  def inpt inputs
    m  = inputs.mouse
    p1 = m.point
    p2 = m.click
    @hovered = p1.inside_rect?(self.box) ? true : false
    @clicked &&= false
    @clicked = true if p2&.inside_rect?(self.box)
    return
  end

  def draw_override ffi_draw
    ffi_draw.draw_solid @x, @y - @h, @w, @h * 0.1, @r, @g, @b, @a if @hovered
    ffi_draw.draw_label @x, @y, @text, @se, @ae, @r, @g, @b, @a, nil
    return
  end

  def primitive_marker
    return :sprite
  end
end

class Button
  def initialize x, y, w, h, text, se: 0, ae: 1, r: 144, g: 238, b: 144, a: 255
    @x = x
    @y = y
    @w = w
    @h = h
    @text = text
    @se = se
    @ae = ae
    @r = r
    @g = g
    @b = b
    @a = a
    @tw, @th = $gtk.calcstringbox text, se
    @hovered = false
  end

  def box
    return [@x, @y, @w, @h]
  end

  def inpt inputs
    p1 = inputs.mouse.point
    @hovered = p1&.inside_rect?(self.box)
    return
  end

  def clicked? inputs
    p1 = inputs.mouse.click
    return p1&.inside_rect?(self.box)
  end

  def draw_override ffi_draw
    if @hovered
      r, g, b = @r - 50, @g - 50, @b - 50
    else
      r, g, b = @r, @g, @b
    end
    ffi_draw.draw_solid @x, @y, @w, @h, r, g, b, @a
    ffi_draw.draw_label @x + @w.half, @y + @h.half + @th.half, @text, @se, @ae, 0, 0, 0, @a, nil
    return
  end

  def primitive_marker
    return :sprite
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

def launch name # Give it the JSON's 'run' string
  $gtk.exec("open \".#{PATH}/Library/#{name}.app\"")         if OS == 'Mac Os X'
  $gtk.exec(".\"/Library/#{name}-linux-amd64.bin\"")         if OS == 'Linux'
  $gtk.exec("cmd /c \"Library\\#{name}-windows-amd64.exe\"") if OS == 'Windows'
  return
end

def hyperlink_inpt(args, hyperlink) # if hyperlink, if clicked, open url
  return unless hyperlink
  hyperlink.inpt(args.inputs)
  if hyperlink.clicked
    $gtk.openurl(hyperlink.url)
  end
end

# Render Target 'Cards'... makes it easier to do a slide animation
def card_rndr args, name, game
  card = args.render_target(name)
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

W, H = 1280, 720
PNG_W, PNG_H = 315, 250

OS   = $gtk.platform
PATH = $gtk.argv.split('/')[0..-3].join('/') # Only used for MacOS

GAMES  = $gtk.parse_json_file('entries.json')
# DEBUG: Fake Entries
# GAMES += [*('A'..'Z')].map do |c|
#   { "title"   => "Fake #{c}",
#     "png"     => "dragonruby.png",
#     "run"     => "",
#     "author"  => "Fake #{c}",
#     "aut_url" => "",
#     "jam_url" => "",
#     "description" => "blah bla bla blah " * 15 }
# end

GAMES.each do |g| # Set default png if given png does not exist for whatever reason
  g['png'] = 'dragonruby.png' unless g['png']&.end_with? '.png'
end

GAMES.each do |g| # Create hyperlinks for each entry
  g['aut_link'] = Hyperlink.new(640 - PNG_W.half, 330 - PNG_H.half, 'Visit Author Page!', g['aut_url']) if g['aut_url'] != ''
  g['jam_link'] = Hyperlink.new(640 - PNG_W.half, 300 - PNG_H.half, 'Visit Jam Page!', g['jam_url'])    if g['jam_url'] != ''
end

def init args, state
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

  state.play_button     = Button.new(870, 20, 410, 80, 'PLAY', se: 16)
  state.credits_button  = Button.new(1180, 700, 100, 20, 'CREDITS', r: 144, g: 238, b: 238)
  state.exit_credits_bt = Button.new(1255, 695, 25, 25, '<', r: 238, g: 144, b: 144)

  state.main_jam_link = Hyperlink.new(870, 720, 'Visit TeenyTiny Jam Page', 'https://itch.io/jam/teenytiny-dragonruby-minigamejam-2020')
  state.aut_link      = GAMES[state.jdx]['aut_link']
  state.jam_link      = GAMES[state.jdx]['jam_link']

  state.mode = :main
end

def updt args, state
  case state.mode
  when :main
    if !state.play && state.xsnap && state.ysnap
      if state.key.enter || state.play_button.clicked?(args.inputs)
        state.play     = true
        state.x_set_to = -W
      end

      hyperlink_inpt args, state.main_jam_link
      hyperlink_inpt args, state.aut_link
      hyperlink_inpt args, state.jam_link

      if state.key.c || state.credits_button.clicked?(args.inputs)
        state.mode     = :credits
        state.x_set_to = W
      end
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

    state.play_button.inpt(args.inputs)
    state.credits_button.inpt(args.inputs)

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

def rndr args, state
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
      state.play_button,
      [870, 700, 410, 20, [0]*3].solid,
      state.main_jam_link,
      state.credits_button
    ]

    card_rndr(args, :card, GAMES[state.jdx])
    card_rndr(args, :nextcard, GAMES[(state.jdx - state.iv) % state.idx_max])

    args.outputs.background_color = [0]*3
    args.outputs.sprites << [
      [state.shift_x - W, 0, W, H, :credit_card],
      [state.shift_x, state.shift_y, W, H, :card],
      [state.shift_x, (state.iv < 0 ? -H : H) + state.shift_y, W, H, :nextcard],
      [state.shift_x, 0, W, H, :menu],
      [state.shift_x + W, 0, W, H, 'tiny_jam_logo.png']
    ]

  when :credits
    # lol
    credit_card = args.render_target(:credit_card)
    credit_card.sprites << [
      [0, 0, 1280, 720, 'credits.png'],
      state.exit_credits_bt
    ]

    args.outputs.background_color = [0]*3
    args.outputs.sprites << [
      [state.shift_x - W, 0, W, H, :credit_card],
      [state.shift_x, 0, W, H, :card],
      [state.shift_x, 0, W, H, :menu],
    ]
  end

  args.outputs.primitives << [
    [state.shift_x, 0, 1280, 20, 0, 0, 50].solid,
    [state.shift_x + 640, 20, "MOVE: ↑/↓ or Mouse Wheel  PLAY: Enter  EXIT: Esc  CREDITS: c", 0, 1, [255]*3].label
  ]
end

def tick args
  state = args.state
  init args, state if args.tick_count < 1
  updt args, state if args.tick_count > 30
  rndr args, state
end
