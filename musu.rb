require 'ruby2d'
require './behaviors/collidable'
require 'csv'

class Person
  include Collidable

  attr_accessor :hitbox_x, :hitbox_y, :hitbox_width, :hitbox_height, :x, :y, :width, :height

  def initialize opts = {}
    @x = opts[:x]
    @y = opts[:y]
    @width = opts[:width]
    @height = opts[:height]
    @hitbox_proportion = 0.75
    @hitbox_offset = opts[:width] * (1 - @hitbox_proportion) / 2
    @hitbox_x = opts[:x] + @hitbox_offset
    @hitbox_y = opts[:y]
    @hitbox_width = opts[:width] * @hitbox_proportion
    @hitbox_height = opts[:height]
    @vx = 0
    @vy = 0
    @backoff = 0.8
    @facing = :right
    @jumping = false
    @jump_direction = nil
    @jump_held = false
    @collide = true
    @grown = false
    @dead = false
    @tiles = %w(stand-right.png stand-left.png jump-right.png jump-left.png
                run-right-1.png run-right-2.png run-right-3.png run-left-1.png run-left-2.png run-left-3.png)

    @running_right_tiles = @tiles[4..6] + [@tiles[5]]
    @running_left_tiles = @tiles[7..9] + [@tiles[8]]

    @image = Image.new x: opts[:x], y: opts[:y], width: opts[:width], height: opts[:height], path: @tiles.first
  end

  def dead?
    @dead
  end

  def remove
    @image.remove
  end

  def grow
    @y = y - 32
    @width = width * 2
    @height = height * 2
    @image.height = height
    @image.width = width
    @image.ext_init @path
    @grown = true

    reset_hitbox
  end

  def shrink
    @y = y + 32
    @width = width / 2
    @height = height / 2
    @image.height = height
    @image.width = width
    @image.ext_init @path
    @grown = false

    reset_hitbox
  end

  def reset_hitbox
    @hitbox_offset = width * (1 - @hitbox_proportion) / 2
    @hitbox_x = x + @hitbox_offset
    @hitbox_y = y
    @hitbox_width = width * @hitbox_proportion
    @hitbox_height = height
  end

  def enemy_collision? objects

  end

  def wall_collision? type, objects
    to_check = case type
               when :left
                 hitbox_x
               when :right
                 hitbox_x + hitbox_width
               end

    objects.select do |object|
      next if object == self

      ((object.x - 1)..(object.x + object.width + 1)).include?(to_check) &&
        overlap?(hitbox_y..(hitbox_y + hitbox_height), object.y..(object.y + object.height)) &&
        reasonable_y_overlap?(object) &&
        object.collide?(self)
    end.first
  end

  def floor_collision? objects
    objects.select do |object|
      next if object == self

      ((object.y - 5)..(object.y + object.height)).include?(hitbox_y + hitbox_height) &&
        overlap?(hitbox_x..(hitbox_x + hitbox_width), (object.x)..(object.x + object.width)) &&
        !too_far_down?(object) &&
        object.collide?(self)
    end.first
  end

  def ceiling_collision? objects
    objects.select do |object|
      next if object == self

      ((object.y)..(object.y + object.height)).include?(hitbox_y) &&
        overlap?(hitbox_x..(hitbox_x + hitbox_width), (object.x)..(object.x + object.width)) &&
        !too_far_up?(object) &&
        object.collide?(self)
    end.first
  end

  def reasonable_y_overlap? object
    ((hitbox_y.to_i..(hitbox_y + hitbox_height).to_i).to_a &
       (object.y.to_i..(object.y + object.height).to_i).to_a).count > 10
  end

  def close_enough? objects
    objects.any? do |object|
      next if object == self

      (hitbox_y + hitbox_height - object.y).abs <= 1 &&
        overlap?(hitbox_x..(hitbox_x + hitbox_width), (object.x)..(object.x + object.width))
    end
  end

  def too_far_down? collided
    hitbox_y + hitbox_height >= collided.y + 5
  end

  def too_far_up? collided
    hitbox_y <= collided.y + collided.height - 5
  end

  def fireball!
    if @facing == :right
      Fireball.new(x: x + width, y: y, direction: @facing)
    else
      Fireball.new(x: x, y: y, direction: @facing)
    end
  end

  def move direction, shift_held = false, jump_held
    direction = direction.to_sym

    if direction == :up
      @jump_held = true

      if @vy >= 0 && !@jumping
        @jumping = true
        @jump_direction = @vx > 0 ? :right : :left
        @vy = (@grown ? -10 : -8)
      end
    else
      @jump_held = jump_held
    end

    if direction == :left
      @facing = :left
      @vx = @jumping && @jump_direction == :right ? -2 : (shift_held ? -5 : -3)
    end

    if direction == :right
      @facing = :right
      @vx = @jumping && @jump_direction == :left ? 2 : (shift_held ? 5 : 3)
    end
  end

  def collide objects = []
    if collided = ceiling_collision?(objects)
      actionable = collide_top collided

      return actionable if actionable
    end

    if collided = floor_collision?(objects)
      actionable = collide_bottom collided

      return actionable if actionable
    else
      @vy += 0.5 unless close_enough?(objects) || @vy >= 10
    end

    if collided = wall_collision?(:left, objects)
      actionable = collide_left collided

      return actionable if actionable
    elsif collided = wall_collision?(:right, objects)
      actionable = collide_right collided

      return actionable if actionable
    end
  end

  def collide_top collided
    @vy = 0

    self.y = collided.y + collided.height + 1

    collide_actor :bottom, collided
  end

  def collide_left collided
    @vx = 0 if @vx < 0

    self.x = collided.x + collided.width - @hitbox_offset + 1

    collide_actor :left, collided
  end

  def collide_right collided
    @vx = 0 if @vx > 0

    self.x = collided.x - width + @hitbox_offset - 1

    collide_actor :right, collided
  end

  def collide_bottom collided
    enemy = collide_actor :top, collided

    if enemy
      @vy = @jump_held ? -8 : -5

      return enemy
    end

    if @vy > 0
      @jumping = false
      @vy = 0
      self.y = collided.y - height
    end

    nil
  end

  def collide_actor direction, object
    return unless [Person, Fireball].include?(self.class) && [Enemy, Platform, Brick].include?(object.class)

    if direction == :top
      object if ![Platform, Brick].include?(object.class) && !object.dead?
    elsif direction == :bottom
      object if object.class == Brick && self.class == Person && !object.dead?
    elsif %i(right left).include?(direction)
      if object.class == Enemy
        if self.class == Fireball && !object.dead?
          object
        else
          self
        end
      end
    end
  end

  def draw frame
    if self.x <= 0 && !(@vx > 0)
      self.x = 0
    else
      self.x = @x + @vx
    end

    self.y = @y + @vy
    self.hitbox_x = x + @hitbox_offset
    self.hitbox_y = y

    @vx *= @backoff unless @jumping

    if @jumping
      if @facing == :right
        @path = @tiles[2]
      else
        @path = @tiles[3]
      end
    else
      if @vx.abs > 1
        anim_speed = @vx.abs > 3 ? 2 : 4

        if @vx > 0
          @facing = :right
          @path = @running_right_tiles[frame / anim_speed % 4]
        elsif @vx < 0
          @facing = :left
          @path = @running_left_tiles[frame / anim_speed % 4]
        end
      else
        if @facing == :right
          @path = @tiles[0]
        else
          @path = @tiles[1]
        end
      end
    end

    @image.x = x
    @image.y = y
    @image.height = height
    @image.width = width
    @image.ext_init @path
  end
end

class Thing < Image
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
      actionable = collide_actor :bottom, collided

      return actionable if actionable
    end

    if collided = floor_collision?(objects)
      actionable = collide_bottom collided

      return actionable if actionable
    else
      @vy += 0.5 unless close_enough?(objects) || @vy >= 10
    end

    if collided = wall_collision?(:left, objects)
      actionable = collide_left collided

      return actionable if actionable
    elsif collided = wall_collision?(:right, objects)
      actionable = collide_right collided

      return actionable if actionable
    end

    nil
  end

  def collide_left collided
    @vx = 0 if @vx < 0
    self.x = collided.x + collided.width - 10

    collide_actor :left, collided
  end

  def collide_right collided
    @vx = 0 if @vx > 0
    self.x = collided.x - width

    collide_actor :right, collided
  end

  def collide_top collided
    if @vy < 0
      @hit_ceiling = true
      @vy = 0
      self.y = collided.y + collided.height
    end
  end

  def collide_bottom collided
    enemy = collide_actor :top, collided

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

    nil
  end

  def collide_actor direction, object
    unless ([Person, Fireball].include?(self.class) && [Enemy, Platform].include?(object.class)) ||
        (self.class == Enemy && object.class == Person)
        return
    end

    if direction == :top
      object if object.class != Platform && !object.dead?
    elsif %i(right left).include?(direction)
      if self.class == Fireball && object.class == Enemy
        object if !object.dead?
      elsif self.class == Enemy && object.class == Person
        object
      end
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
          @facing = :right
          @path = @tiles[4..5][frame / 6 % 2]
        elsif @vx < 0
          @facing = :left
          @path = @tiles[6..7][frame / 6 % 2]
        end
      else
        if @facing == :right
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

  def collide? object = nil
    @collide
  end
end

class BrickPiece < Image
  def initialize opts = {}
    @vx = opts[:direction] == :left ? -2 : 2
    @vy = opts[:go_higher] == true ? -6 : -4
    @dead = false
    opts[:width] = 8
    opts[:height] = 8
    opts[:path] = 'brick-piece.png'

    super opts
  end

  def collide objects
    @vy += 0.5 unless @vy >= 10

    nil
  end

  def collide? object
    true
  end

  def draw frame
    self.x = @x + @vx
    self.y = @y + @vy
  end
end

class Brick < Platform
  def dead?
    @dead
  end

  def die
    @dead = true
    @collide = false

    starting_x = x
    starting_y = y
    brick_pieces = []

    brick_pieces.push BrickPiece.new x: x, y: y, go_higher: true, direction: :left
    brick_pieces.push BrickPiece.new x: x, y: y + 8, direction: :left
    brick_pieces.push BrickPiece.new x: x + 8, y: y, go_higher: true, direction: :right
    brick_pieces.push BrickPiece.new x: x + 8, y: y + 8, direction: :right

    brick_pieces
  end
end

class Fireball < Thing 
  def initialize opts = {}
    tiles = %w(fire-1.png fire-2.png fire-3.png fire-4.png)

    opts[:width] = 16
    opts[:height] = 16
    opts[:path] = tiles.first

    super opts

    @tiles = tiles
    @vx = opts[:direction] == :left ? -4 : 4
  end

  def collide_bottom collided
    @vy = -6

    collide_actor :top, collided
  end

  def collide_left collided
    vx = @vx

    @vx = 0

    @vx = -vx

    collide_actor :left, collided
  end

  def collide_right collided
    vx = @vx

    @vx = 0

    @vx = -vx

    collide_actor :right, collided
  end

  def draw frame
    self.x = @x + @vx
    self.y = @y + @vy

    @path = @tiles[frame / 4 % 4]

    ext_init @path
  end
end

class Enemy < Thing 
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

    collide_actor :right, collided
  end

  def collide_right collided
    vx = @vx

    @vx = 0

    @vx = -vx

    collide_actor :left, collided
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
@loaded = false

update do
  next unless @loaded

  @cull.each_pair do |time, obj|
    if Time.now > time
      @actors.delete obj
      obj.remove
      @cull.delete time

      load if obj.class == Person
    end
  end

  @pressed_keys.each do |key|
    @person.move key, @shift_held, @pressed_keys.include?('up')
  end

  @actors.each do |actor|
    collided = actor.collide @scene + @actors

    if collided
      if collided == @person
        @cull[Time.now] = collided
      elsif actor.class == Person && collided.class == Brick
        remains = collided.die
        @actors.concat(remains) if remains
        @cull[Time.now] = collided
      elsif actor.class == Fireball
        collided.die
        @cull[Time.now + 0.25] = collided
        @cull[Time.now] = actor
        increment_score
      else
        collided.die
        @cull[Time.now + 0.25] = collided
        increment_score
      end
    elsif actor.y > @height || (actor.class == Fireball && (actor.x + actor.width < 0 || actor.x > @width))
      @cull[Time.now] = actor
    end

    actor.draw @tick
  end

  @tx = if @person.x > @width * 0.75
          @person.x - @width * 0.75
        # elsif @person.x < @width * 0.25
        #   @person.x - @width * 0.25
        else
          0
        end

  (@scene + @actors).each do |element|
    element.x = element.x - @tx
  end

  @tick += 1
end

def increment_score
  current_score = @score.text.to_i

  if current_score < 999999
    current_score += 100
  end

  @score.text = current_score.to_s.rjust(9, '0')
end

@shift_held = false
@attract_mode = false

on :key_down do |event|
  return if @attract_mode

  @shift_held = true if event.key.to_s.include?('shift')

  if event.key.to_sym == :f
    @actors << @person.fireball! if @actors.select { |actor| actor.class == Fireball }.count < 3
  else
    @pressed_keys.push(event.key) unless @pressed_keys.include? event.key
  end
end

on :key_held do |event|
  return if @attract_mode

  @pressed_keys.push(event.key) unless @pressed_keys.include?(event.key)
end

on :key_up do |event|
  return if @attract_mode

  @shift_held = false if event.key.to_s.include?('shift')

  if event.key.to_sym == :e
    @actors << Enemy.new(x: @width - 50, y: 0, width: 32, height: 32)
  elsif event.key.to_sym == :r
    @person.grow
  elsif event.key.to_sym == :t
    @person.shrink
  elsif event.key.to_sym == :n
    load
  elsif event.key.to_sym == :m
    unload
  else
    @pressed_keys.delete event.key
  end
end

def load
  unload

  stage = CSV.read 'stage1.csv'
  row_number = 0
  width = 32
  height = 32
  @scene = []
  @actors = []

  stage.each do |row|
    y = row_number * 32
    column_number = 0

    row.each do |elem|
      x = column_number * 32

      case elem
      when 'M'
        @person = Person.new x: x, y: y, width: 32, height: 32
        @actors << @person
      when 'B'
        @scene << Brick.new(x: x, y: y, width: width, height: height, path: 'brick.png')
      when 'G'
        @scene << Platform.new(x: x, y: y, width: width, height: height, path: 'block.png')
      when 'E'
        @actors << Enemy.new(x: x, y: y, width: width, height: height)
      else
      end

      column_number += 1
    end

    row_number += 1
  end

  @score = Text.new(x: 0, y: 0, text: "000000000", size: 20, font: 'font.ttf', z: 0, color: 'black')
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

  @score.remove if @score
  @loaded = false
end

load

show
