require 'ruby2d'

class Man < Image
  def initialize opts = {}
    @vx = 0
    @vy = 0
    @backoff = 0.8
    @jumping = false
    @jump_direction = nil
    @jump_held = false
    @hit_ceiling = false
    @tiles = %w(stand-right.png stand-left.png jump-right.png jump-left.png run-right-1.png
                run-right-2.png run-left-1.png run-left-2.png)

    super opts
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
      @jump_held = false
      @vx = @jumping && @jump_direction == :right ? -2 : -3
    when :right
      @jump_held = false
      @vx = @jumping && @jump_direction == :left ? 2 : 3
    else
      @jump_held = false
    end
  end

  def overlap? a, b
    a.cover?(b.first) || b.cover?(a.first)
  end

  def collide objects = []
    if collided = ceiling_collision?(objects)
      collide_enemy :bottom, collided

      if @vy < 0
        @hit_ceiling = true
        @vy = 0
        self.y = collided.y + collided.height
      end
    end

    if collided = floor_collision?(objects)
      enemy = collide_enemy :top, collided

      if enemy
        @vy = @jump_held ? -8 : -5
        return enemy
      end

      if @vy > 0 || @hit_ceiling
        @hit_ceiling = false
        @jumping = false
        @vy = 0
        self.y = collided.y - height
      end
    else
      @platform_difference = nil
      @vy += 0.5 unless close_enough?(objects) || @vy >= 10
    end

    if collided = wall_collision?(:left, objects)
      collide_enemy :side, collided
      collide_left collided
    elsif collided = wall_collision?(:right, objects)
      collide_enemy :side, collided
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

  def collide_enemy direction, object
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

  def wall_collision? type, objects
    to_check = case type
               when :left
                 x
               when :right
                 x + width
               end

    objects.select do |object|
      next if object == self

      (object.x..(object.x + object.width)).include?(to_check) &&
        overlap?(y...(y + height), object.y...(object.y + object.height))
    end.first
  end

  def floor_collision? objects
    objects.select do |object|
      next if object == self

      ((object.y - 5)..(object.y + object.height)).include?(y + height) &&
        overlap?(x..(x + width), (object.x)..(object.x + object.width)) &&
        !too_far_down?(object)
    end.first
  end

  def ceiling_collision? objects
    objects.select do |object|
      next if object == self

      ((object.y)..(object.y + object.height)).include?(y) &&
        overlap?(x..(x + width), (object.x)..(object.x + object.width)) &&
        !too_far_up?(object)
    end.first
  end

  def close_enough? objects
    objects.any? do |object|
      next if object == self

      (y + height - object.y).abs <= 1 &&
        overlap?(x..(x + width), (object.x)..(object.x + object.width))
    end
  end

  def too_far_down? collided
    y + height >= collided.y + 5
  end

  def too_far_up? collided
    y <= collided.y + collided.height - 5
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
          @path = @tiles[4..5][frame / 4 % 2]
        elsif @vx < 0
          @last_direction = :left
          @path = @tiles[6..7][frame / 4 % 2]
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

class Platform; end

class Enemy < Man
  def initialize opts = {}
    super opts

    @vx = -1
  end

  def move; end

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

@man = Man.new x: (@width / 2 - 12.5), y: 0, width: 64, height: 64, path: 'stand-right.png'
@enemy1 = Enemy.new x: @width - 50, y: 0, width: 32, height: 32, path: 'enemy.png'
@enemy2 = Enemy.new x: 50, y: 0, width: 32, height: 32, path: 'enemy.png'
# @floor = Rectangle.new x: 0, y: @height - 20, width: 960, height: 10, color: 'blue'
@floortiles = []

60.times do |i|
  tile = Image.new x: i * 32, y: @height - 32, height: 32, width: 32, path: 'block.png'
  @floortiles << tile
end

@platform1 = Image.new x: 400, y: @height - 110, width: 32, height: 32, path: 'brick.png'
@platform2 = Image.new x: 360, y: @height - 70, width: 32, height: 32, path: 'brick.png'

@scene = [@platform1, @platform2] + @floortiles
@enemies = [@enemy1, @enemy2]
@actors = @enemies + [@man]
@tick = 0

update do
  @pressed_keys.each do |key|
    @man.move key
  end

  @actors.each do |actor|
    collided = actor.collide @scene + @enemies

    if collided
      @enemies.delete collided
      collided.remove
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
  @pressed_keys.push(event.key) unless @pressed_keys.include? event.key
end

on :key_held do |event|
  @pressed_keys.push(event.key) unless @pressed_keys.include? event.key
end

on :key_up do |event|
  if event.key.to_sym == :e
    @enemies << Enemy.new(x: @width - 50, y: 0, width: 32, height: 32, path: 'enemy.png')
    @actors = @enemies + [@man]
  else
    @pressed_keys.delete event.key
  end
end

def man_control event
  @man.move event.key
end

def load scene
end

def unload
end

show
