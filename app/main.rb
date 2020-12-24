W, H = 1280, 720
PNG_W, PNG_H = 315, 250

OS   = $gtk.platform
PATH = $gtk.argv.split('/')[0..-3].join('/') # Only used for MacOS

GAMES = $gtk.parse_json_file 'entries.json'
BLACK = [0, 0, 0]
JAM_URL = 'https://itch.io/jam/teenytiny-dragonruby-minigamejam-2020'

class Primitive
  attr_accessor :x, :y, :w, :h, :r, :g, :b, :a
  def primitive_marker; :sprite end

  def initialize x, y, w, h, r, g, b, a
    @x, @y, @w, @h = x, y, w, h
    @r, @g, @b, @a = r, g, b, a
  end

  def box; [@x, @y, @w, @h] end
end

class Solid < Primitive
  def initialize x:, y:, w:, h:, r: 255, g: 255, b: 255, a: 255
    super(x, y, w, h, r, g, b, a)
  end

  def set_rect(x:, y:, w:, h:)
    @x, @y, @w, @h = x, y, w, h
  end

  def draw_override ffi_draw
    ffi_draw.draw_solid @x, @y, @w, @h, @r, @g, @b, @a
  end
end

class Border < Solid
  def draw_override ffi_draw
    ffi_draw.draw_border @x, @y, @w, @h, @r, @g, @b, @a
  end
end

class Sprite < Primitive
  attr_accessor :path

  def initialize x:, y:, w:, h:, path:, a: 255
    super(x, y, w, h, 0, 0, 0, a)
    @path = path
  end

  def draw_override ffi_draw
    ffi_draw.draw_sprite_2 @x, @y, @w, @h, @path, nil, @a
  end
end

class Label < Primitive
  attr_accessor :text, :se, :ae

  def initialize x:, y:, text:, se: 0, ae: 0, r: 255, g: 255, b: 255, a: 255
    @text = text
    @se = se
    @ae = ae

    w, h = $gtk.calcstringbox text, se
    super(x, y, w, h, r, g, b, a)
  end

  def text= str
    @text = str
    @w, @h = $gtk.calcstringbox str, se
  end

  def box
    return [@x, @y - @h, @w, @h]           if @ae == 0
    return [@x - @w.half, @y - @h, @w, @h] if @ae == 1
    return [@x - @w, @y - @h, @w, @h]
  end

  def draw_override ffi_draw
    ffi_draw.draw_label @x, @y, @text, @se, @ae, @r, @g, @b, @a, nil
  end
end

class MultiLabel < Primitive
  attr_reader :text
  def initialize x:, y:, text:, se: 0, ae: 0, r: 255, g: 255, b: 255, a: 255
    @se = se
    @ae = ae
    @sw, @sh = $gtk.calcstringbox ' ', se
    super(x, y, 0, 0, r, g, b, a)
    send :text=, text
  end

  def x= x
    @x = x
    @labels.each { |l| l.x = x }
  end

  def y= y
    @y = y
    @labels.each_with_index { |l, i| l.y = y - @sh * i }
  end

  def a= a
    @a = a
    @labels.each { |l| l.a = a }
  end

  def text= str
    @text = str
    @labels = str.split("\n").map_with_index do |line, i|
      Label.new x: @x, y: @y - @sh * i, text: line, se: @se, ae: @ae, r: @r, g: @g, b: @b, a: @a
    end
    __wh
  end

  def wrap count
    @labels = @text.wrapped_lines(count).map_with_index do |line, i|
      Label.new x: @x, y: @y - @sh * i, text: line, se: @se, ae: @ae, r: @r, g: @g, b: @b, a: @a
    end
    __wh
  end

  def __wh
    @w = (@labels.map &:w).max
    @h = @sh * @labels.length
  end

  def draw_override ffi_draw
    i = 0
    l = @labels.length
    while i < l
      (@labels.at i).draw_override ffi_draw
      i += 1
    end
  end
end

class BoxLabel < Primitive
  attr_accessor :text, :se, :ve, :ae
  def initialize x:, y:, w:, h:, text:, se: 0, ve: 0, ae: 0, r: 255, g: 255, b: 255, a: 255
    super(x, y, w, h, r, g, b, a)
    @text = text
    @se = se
    @ve = ve
    @ae = ae

    @ml = MultiLabel.new x: x, y: y, text: text, se: se, ae: ae, r: r, g: g, b: b, a: a
    __mxy
  end

  def x= x
    @x = x
    @ml.x = __mx
  end

  def y= y
    @y = y
    @ml.y = __my
  end

  def w= w
    @w = w
    @ml.x = __mx
  end

  def h= h
    @h = h
    @ml.y = __my
  end

  def a= a
    @a = a
    @ml.a = a
  end

  def set_rect(x:, y:, w:, h:)
    send(:x=, x)
    send(:y=, y)
    send(:w=, w)
    send(:h=, h)
  end

  def text= str
    @text = text
    @ml.text = str
    @ml.wrap 40
    __mxy
  end

  def __mxy
    @ml.x = __mx
    @ml.y = __my
  end

  def __mx
    return @mx = @x + 2       if @ae == 0
    return @mx = @x + @w.half if @ae == 1
    return @mx = @x + @w
  end

  def __my
    return @my = @y + @h                   if @ve == 0
    return @my = @y + @h.half + @ml.h.half if @ve == 1
    return @my = @y + @ml.h
  end

  def draw_override ffi_draw
    @ml.draw_override ffi_draw
  end
end

class LerpVar
  attr_accessor :at, :a, :b
  def initialize time, a: 0, b: 1
    @time = time
    @a    = a
    @b    = b
    @at   = a
    @spd  = (b - a) / time
  end

  def on
    @at = @at.towards(@b, @spd)
  end

  def off
    @at = @at.towards(@a, @spd)
  end

  def * other
    @at * other
  end
end

module DrawOverride
  def primitive_marker; :sprite end
  def draw_override ffi_draw
    i = 0
    l = @primitives.length
    while i < l
      (@primitives.at i).draw_override ffi_draw
      i += 1
    end
  end
end

class PngBox
  include DrawOverride

  def initialize args, layout, opts = nil
    @layout = layout
    @opts = { path: '',
              w: PNG_W,
              h: PNG_H,
              fc: { r: 255, g:   0, b:   0, a: 255 } }
    @opts.merge! opts if opts

    @rect   = args.layout.rect @layout
    x, y = @rect.x + @rect.w.half - @opts.w.half, @rect.y + @rect.h.half - @opts.h.half
    @sprite = Sprite.new(x: x, y: y, w: @opts.w, h: @opts.h, path: @opts.path)
    @border = Border.new(**@opts[:fc], x: x, y: y, w: @opts.w, h: @opts.h)

    @primitives = [@sprite, @border]
  end

  def path= str
    @opts.path = str
    @sprite.path = str
  end
end

class TextBox
  include DrawOverride

  def initialize args, layout, opts = nil
    @layout = layout
    @opts = { text: '',
              bc: { r:   0, g:   0, b:   0, a: 255 },
              fc: { r: 255, g:   0, b:   0, a: 255 },
              tc: { r: 255, g: 255, b: 255, a: 255 },
              ae: 1 }
    @opts.merge! opts if opts

    @rect   = args.layout.rect @layout
    @solid  = Solid.new(**@opts[:bc], **@rect)
    @border = Border.new(**@opts[:fc], **@rect)
    @label  = BoxLabel.new(text: text, ve: 1, ae: @opts[:ae], **@opts[:tc], **@rect)

    @primitives = [@solid, @border, @label]
  end

  def text
    @opts[:text]
  end

  def text= str
    @opts[:text] = str
    @label.text  = str
  end

  def __lerp mult, v1, v2
    return v1 + (v2 - v1) * mult
  end

  def lerp_by_layout mult, layout
    rect = $args.layout.rect layout
    r = {
      x: (__lerp mult, @rect.x, rect.x),
      y: (__lerp mult, @rect.y, rect.y),
      w: (__lerp mult, @rect.w, rect.w),
      h: (__lerp mult, @rect.h, rect.h),
    }
    @solid.set_rect(**r)
    @border.set_rect(**r)
    @label.set_rect(**r)
  end

  def set_a a
    @solid.a  = a
    @border.a = a
    @label.a  = a
  end
end

class Button < TextBox
  def initialize args, layout, opts
    super
    @hovered_at = LerpVar.new 0.3.seconds, a: 0, b: 50
  end

  def updt
    if hovered?
      @hovered_at.on
      e = @hovered_at.at
      @solid.r = @opts[:bc].r + e
      @solid.g = @opts[:bc].g + e
      @solid.b = @opts[:bc].b + e
    else
      @hovered_at.off
      e = @hovered_at.at
      @solid.r = @opts[:bc].r + e
      @solid.g = @opts[:bc].g + e
      @solid.b = @opts[:bc].b + e
    end

    if clicked?
      @hovered_at.at = 150
      if @opts[:action]
        case @opts[:args]
        when Proc
          @opts[:action].call @opts[:args].call
        when Array
          @opts[:action].call(*@opts[:args])
        when NilClass
          @opts[:action].call
        else
          @opts[:action].call @opts[:args]
        end
      end
    end
  end

  def hovered?
    return $args.inputs.mouse.point.intersect_rect? @rect
  end

  def clicked?
    c = $args.inputs.mouse.click
    return c.intersect_rect? @rect if c
  end
end

class ScrollBoxes
  include DrawOverride

  def initialize args, list
    @list = list
    @len  = list.length

    @snaps = [
      { layout: { row: 0, col: 4, w: 0, h: 1 } },
      (1..4).map do |i| { layout: { row: i, col: 0, w: 8, h: 1 } } end,
      { layout: { row: 5, col: 0.5, w: 8, h: 2 } },
      (7..10).map do |i| { layout: { row: i, col: 0, w: 8, h: 1 } } end,
      { layout: { row: 11, col: 4, w: 0, h: 1 } }
    ].flatten

    @boxes = 11.times.map { |i| TextBox.new args, @snaps[i][:layout], { text: "Hello #{i}"} }
    @boxes[0].set_a 0
    @boxes[10].set_a 0

    @primitives = @boxes

    @time = 0.3.seconds
    @at = 0
    @move_to = 0
    set_text 0

    @snapped = true
  end

  def updt
    if @at != @move_to || !@snapped
      unless @shift_at
        @shift_at = $args.tick_count
        $args.outputs.sounds << "sounds/rollover2.wav"
      end
      if @snapped
        set_text @at
        @snapped = false
      end
      d = dist
      dir = d < 0 ? -1 : 1
      shift_lerp 0, dir if @olddir != dir
      @olddir = dir
      t = @time * (0.7 - 0.1 * d.abs)
      e = @shift_at.ease t, :identity
      shift_lerp e, -dir
      if @shift_at.elapsed? t
        @at += dir
        @at = @at % @len
        @snapped = true
        @shift_at = nil #$args.tick_count
        if @at == @move_to
          set_text @at
          shift_lerp 0, -dir
        end
      end
    end
  end

  def move_to n
    @move_to = n
  end

  def dist
    a = @at
    b = @move_to
    if a > b
      c = b - a
      d = (a - @len) - b
      return c.abs < d.abs ? c : -d
    else
      c = b - a
      d = (b - @len) - a
      return c.abs < d.abs ? c : d
    end
  end

  def set_text n
    @boxes.each_with_index do |b, i|
      v = (-5 + n + i - @len) % @len
      b.text = @list[v]
    end
  end

  def shift_lerp mult, n
    @boxes.each_with_index do |b, i|
      v = (i + n) % 11
      b.lerp_by_layout mult, @snaps[v][:layout]
      if n > 0
        b.set_a mult * 255 if i == 0
        b.set_a 255 - mult * 255 if i == 9
      else
        b.set_a 255 - mult * 255 if i == 1
        b.set_a mult * 255 if i == 10
      end
    end
  end
end

module Launcher
  attr_gtk

  def self.tick
    init if args.tick_count.zero?
    updt
    rndr
  end

  def self.init
    @selection = 0

    @boxes = ScrollBoxes.new args, GAMES.map { |h| h['title'] }

    @info_author = TextBox.new args, { row: 1, col: 16, w: 8, h: 1 }, { text: "AUTHOR: #{GAMES[@selection]['author']}" }
    @info_game   = TextBox.new args, { row: 2, col: 16, w: 8, h: 8 }, { text: GAMES[@selection]['description'] }

    @menu_buttons = [
      (Button.new args, { row:  0, col: 16, w: 2, h: 1 }, { text: "DEV PAGE", action: lambda { open_author_page } }),
      (Button.new args, { row:  0, col: 18, w: 2, h: 1 }, { text: "GAME PAGE", action: lambda { open_game_page } }),
      (Button.new args, { row:  0, col: 20, w: 2, h: 1 }, { text: "JAM PAGE", action: lambda { $gtk.openurl JAM_URL } }),
      (Button.new args, { row:  0, col: 22, w: 2, h: 1 }, { text: "CREDITS", action: lambda { set_state :credits } }),
      (Button.new args, { row: 10, col: 16, w: 8, h: 2 }, { text: "PLAY", action: lambda { set_state :play } })
    ]

    @png_box = PngBox.new args, { row: 3, col: 9, w: 6, h: 6 }, { path: '/shots/' + GAMES[@selection]['png'] }

    @primitives = [
      @boxes,
      @info_author,
      @info_game,
      @menu_buttons,
      @png_box
    ]

    menu = args.render_target(:menu)
    menu.primitives << @primitives

    @menu = [0, 0, 1280, 720, :menu]

    @credits = [0, 720, 1280, 720, 'credits.png']
    @credits_close_bt = Button.new args, { row: 0, col: 22, w: 2, h: 1 }, { text: "^", action: lambda { set_state :menu } }

    @logo = [1280, 0, 1280, 720, 'tiny_jam_logo.png']

    @shift_y = LerpVar.new 0.3.seconds
    @shift_x = LerpVar.new 0.3.seconds

    @state = :menu
  end

  def self.updt
    kd = keyboard.key_down
    m  = inputs.mouse

    $gtk.exit if kd.escape

    case @state
    when :menu
      @boxes.updt
      @menu_buttons.map &:updt

      scroll m.wheel.y if m.wheel
      scroll kd.up_down if kd.up_down != 0
      scroll 1 if keyboard.key_held.r

      set_state :play if kd.enter
      set_state :credits if kd.c

      @shift_x.off
      @shift_y.off

      @menu.x = @shift_x * -1280
      @menu.y = @shift_y * -720
      @credits.y = 720 - @shift_y * 720
      @logo.x = 1280 - @shift_x * 1280
    when :credits
      @credits_close_bt.updt

      set_state :menu if kd.c

      @shift_x.off
      @shift_y.on

      @menu.y = @shift_y * -720
      @credits.y = 720 - @shift_y * 720
    when :play
      @shift_x.on

      @menu.x = @shift_x * -1280
      @logo.x = 1280 - @shift_x * 1280

      play if @shift_x.at == 1
    end
  end

  def self.rndr
    args.outputs.background_color = BLACK
    case @state
    when :menu
      menu = args.render_target(:menu)
      menu.primitives << @primitives
      args.outputs.sprites << @menu

      args.outputs.sprites << @credits if @shift_y.at > 0
      args.outputs.sprites << @logo if @shift_x.at > 0
    when :credits
      args.outputs.sprites << @menu if @shift_y.at < 1
      args.outputs.sprites << @credits
      args.outputs.sprites << @credits_close_bt
    when :play
      args.outputs.sprites << @menu if @shift_x.at < 1
      args.outputs.sprites << @logo
    end
    # args.outputs.debug << $gtk.current_framerate_primitives
  end

  def self.set_state state
    @state = state
  end

  def self.scroll i
    @selection = (@selection + i) % GAMES.length
    @boxes.move_to @selection

    @info_author.text = "AUTHOR: #{GAMES[@selection]['author']}"
    @info_game.text   = GAMES[@selection]['description']
    @png_box.path = '/shots/' + GAMES[@selection]['png']
  end

  def self.open_author_page
    $gtk.openurl GAMES[@selection]['aut_url']
  end

  def self.open_game_page
    $gtk.openurl GAMES[@selection]['jam_url']
  end

  def self.launch name # Give it the JSON's 'run' string
    case OS
    when 'Mac Os X' then $gtk.exec "open \".#{PATH}/Library/#{name}.app\""
    when 'Linux'    then $gtk.exec ".\"/Library/#{name}-linux-amd64.bin\""
    when 'Windows'  then $gtk.exec "cmd /c \"Library\\#{name}-windows-amd64.exe\""
    end
  end

  def self.play
    @wait ||= args.tick_count
    if @wait.elapsed?(5)
      launch(GAMES[@selection]['run'])
      @wait = nil
      @state = :menu
    end
  end
end

def tick args
  Launcher.args = args
  Launcher.tick
end
