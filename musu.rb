require 'ruby2d'
require './behaviors/collidable'

class Man < Image
  include Collidable

  def initialize opts = {}
    @vx = 0
    @vy = 0
    @backoff = 0.8
    @facing = :right
    @jumping = false
    @jump_direction = nil
    @jump_held = false
    @hit_ceiling = false
    @collide = true
    @tiles = %w(stand-right.png stand-left.png jump-right.png jump-left.png
                run-right-1.png run-right-2.png run-left-1.png run-left-2.png)

    opts[:path] = @tiles.first

    super opts
  end

  def fireball!
    Fireball.new(x: x + width + 1, y: y, width: 16, height: 16, direction: @facing)
  end

  def move direction
    case direction.to_sym
    when :up
      @jump_held = true

      if @vy >= 0 && !@jumping
        @jumping = true
        @jump_direction = @vx > 0 ? :right : :left
        @vy = -8
      end
    when :left
      @facing = :left
      @jump_held = false
      @vx = @jumping && @jump_direction == :right ? -2 : -3
    when :right
      @facing = :right
      @jump_held = false
      @vx = @jumping && @jump_direction == :left ? 2 : 3
    else
      @jump_held = false
    end
  end

  def collide objects = []
    if collided = ceiling_collision?(objects)
      collide_actor :bottom, collided

      if @vy < 0
        @hit_ceiling = true
        @vy = 0
        self.y = collided.y + collided.height
      end
    end

    if collided = floor_collision?(objects)
      potential_enemy = collide_bottom collided

      return potential_enemy if potential_enemy
    else
      @platform_difference = nil
      @vy += 0.5 unless close_enough?(objects) || @vy >= 10
    end

    if collided = wall_collision?(:left, objects)
      collide_actor :side, collided
      collide_left collided
    elsif collided = wall_collision?(:right, objects)
      collide_actor :side, collided
      collide_right collided
    end

    nil
  end

  def collide_left collided
    @vx = 0 if @vx < 0
    self.x = collided.x + collided.width
  end

  def collide_right collided
    @vx = 0 if @vx > 0
    self.x = collided.x - width
  end

  def collide_bottom collided
    enemy = collide_actor :top, collided

    if enemy && !enemy.dead?
      @vy = @jump_held ? -8 : -5
      return enemy
    end

    if @vy > 0 || @hit_ceiling
      @hit_ceiling = false
      @jumping = false
      @vy = 0
      self.y = collided.y - height
    end

    nil
  end

  def collide_actor direction, object
    return unless self.class == Man && [Enemy, Platform].include?(object.class)

    if direction == :top
      if object.class == Platform
        if @platform_difference
          if @vx.abs < 1
            self.x = object.x - @platform_difference
          else
            @platform_difference = object.x - x
          end
        else
          @platform_difference = object.x - x if @vx.abs < 1
        end

        nil
      else
        object
      end
    else
      @platform_difference = nil
    end
  end

  def draw frame
    self.x = @x + @vx
    self.y = @y + @vy

    @vx *= @backoff unless @jumping

    if @jumping
      if @vx > 0
        @path = @tiles[2]
      elsif @vx < 0
        @path = @tiles[3]
      end
    else
      if @vx.abs > 1
        if @vx > 0
          @last_direction = :right
          @path = @tiles[4..5][frame / 6 % 2]
        elsif @vx < 0
          @last_direction = :left
          @path = @tiles[6..7][frame / 6 % 2]
        end
      else
        if @last_direction == :right || @last_direction.nil?
          @path = @tiles[0]
        else
          @path = @tiles[1]
        end
      end
    end

    ext_init @path
  end
end

class Platform < Image
  def initialize opts = {}
    @collide = true

    super opts
  end

  def collide?
    @collide
  end
end

class Fireball < Man
  def initialize opts = {}
    tiles = %w(fire-1.png fire-2.png fire-3.png fire-4.png)

    opts[:path] = tiles.first

    super opts

    @tiles = tiles
    @vx = opts[:direction] == :left ? -4 : 4
  end

  def collide_bottom collided
    @vy = -8

    nil
  end

  def collide_left collided
    vx = @vx

    @vx = 0

    @vx = -vx
  end

  def collide_right collided
    vx = @vx

    @vx = 0

    @vx = -vx
  end

  def draw frame
    self.x = @x + @vx
    self.y = @y + @vy

    @path = @tiles[frame / 4 % 4]

    ext_init @path
  end
end

class Enemy < Man
  def initialize opts = {}
    tiles = %w(enemy-1.png enemy-2.png)
    opts[:path] = tiles.first

    super opts

    @dead = false
    @death = 'enemy-dead.png'
    @tiles = tiles
    @vx = -1
  end

  def move; end

  def dead?
    @dead
  end

  def collide_left collided
    vx = @vx

    @vx = 0

    @vx = -vx
  end

  def collide_right collided
    vx = @vx

    @vx = 0

    @vx = -vx
  end

  def die
    @vx = 0
    @dead = true
    @collide = false
    @path = @death

    ext_init @path
  end

  def draw frame
    self.x = @x + @vx
    self.y = @y + @vy

    if @vx > 0
      @path = @tiles[frame / 8 % 2]
    elsif @vx < 0
      @path = @tiles[frame / 8 % 2]
    end

    ext_init @path
  end
end

set background: 'white'

@tick = 0
@actors = []
@pressed_keys = []
@width = get :width
@height = get :height
@tx = 0
@ty = 0
@cull = {}
@tick = 0
@loaded

update do
  next unless @loaded

  @cull.each_pair do |time, obj|
    if Time.now > time
      @actors.delete obj
      obj.remove
      @cull.delete time
    end
  end

  @pressed_keys.each do |key|
    @man.move key
  end

  @actors.each do |actor|
    collided = actor.collide @scene + @actors

    if collided
      if actor.is_a? Fireball
        @cull[Time.now] = collided
      else
        collided.die
        current_score = @score.text.to_i

        if current_score < 999999
          current_score += 100
        end

        @score.text = current_score.to_s.rjust(9, '0')
        @cull[Time.now + 0.25] = collided
      end
    end

    actor.draw @tick
  end

  @tx = if @man.x > @width * 0.75
          @man.x - @width * 0.75
        elsif @man.x < @width * 0.25
          @man.x - @width * 0.25
        else
          0
        end

  (@scene + @actors).each do |element|
    element.x = element.x - @tx
  end

  @tick += 1
end

on :key_down do |event|
  if event.key.to_sym == :f
    @actors << @man.fireball!
  else
    @pressed_keys.push(event.key) unless @pressed_keys.include? event.key
  end
end

on :key_held do |event|
  @pressed_keys.push(event.key) unless @pressed_keys.include? event.key
end

on :key_up do |event|
  if event.key.to_sym == :e
    @actors << Enemy.new(x: @width - 50, y: 0, width: 32, height: 32)
  elsif event.key.to_sym == :n
    unload
    load
  elsif event.key.to_sym == :m
    unload
  else
    @pressed_keys.delete event.key
  end
end

def man_control event
  @man.move event.key
end

def load
  @score = Text.new(x: 0, y: 0, text: "000000000", size: 20, font: 'font.ttf', z: 0, color: 'black')
  @man = Man.new x: (@width / 2 - 12.5), y: 0, width: 64, height: 64
  @enemy1 = Enemy.new x: @width - 50, y: 0, width: 32, height: 32
  @enemy2 = Enemy.new x: 50, y: 0, width: 32, height: 32
  @floortiles = []

  60.times do |i|
    tile = Platform.new x: i * 32, y: @height - 32, height: 32, width: 32, path: 'block.png'
    @floortiles << tile
  end

  @platform1 = Platform.new x: 400, y: @height - 110, width: 32, height: 32, path: 'brick.png'
  @platform2 = Platform.new x: 360, y: @height - 70, width: 32, height: 32, path: 'brick.png'

  @scene = [@platform1, @platform2] + @floortiles
  @actors = [@enemy1, @enemy2, @man]
  @loaded = true
end

def unload
  if @scene
    @scene.each(&:remove)
    @scene = []
  end

  if @actors
    @actors.each(&:remove)
    @actors = []
  end

  @loaded = false
end

def die
end

show
