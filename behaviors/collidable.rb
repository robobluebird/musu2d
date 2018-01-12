module Collidable
  def collide?
    @collide
  end

  def overlap? a, b
    a.cover?(b.first) || b.cover?(a.first)
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
        overlap?(y...(y + height), object.y...(object.y + object.height)) &&
        object.collide?
    end.first
  end

  def floor_collision? objects
    objects.select do |object|
      next if object == self

      ((object.y - 5)..(object.y + object.height)).include?(y + height) &&
        overlap?(x..(x + width), (object.x)..(object.x + object.width)) &&
        !too_far_down?(object) &&
        object.collide?
    end.first
  end

  def ceiling_collision? objects
    objects.select do |object|
      next if object == self

      ((object.y)..(object.y + object.height)).include?(y) &&
        overlap?(x..(x + width), (object.x)..(object.x + object.width)) &&
        !too_far_up?(object) &&
        object.collide?
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
end
