local Constants = require 'constants'
local combinator = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
combinator.name = "spoilage-scanner"
combinator.sprites = make_4way_animation_from_spritesheet({ 
  layers ={
    {
      scale = 0.5,
      filename = Constants.png("entity/spoilage-scanner"),
      width = 114,
      height = 102,
      shift = util.by_pixel(0, 5)
    },
    {
      scale = 0.5,
      filename = Constants.png("entity/spoilage-scanner-shadow"),
      width = 98,
      height = 66,
      shift = util.by_pixel(8.5, 5.5),
      draw_as_shadow = true
    }
  }
})
combinator.sprites.north, combinator.sprites.south = combinator.sprites.south, combinator.sprites.north
combinator.sprites.east, combinator.sprites.west = combinator.sprites.west, combinator.sprites.east
combinator.activity_led_sprites.north, combinator.activity_led_sprites.south = combinator.activity_led_sprites.south, combinator.activity_led_sprites.north
combinator.activity_led_sprites.east, combinator.activity_led_sprites.west = combinator.activity_led_sprites.west, combinator.activity_led_sprites.east
combinator.circuit_wire_connection_points[1], combinator.circuit_wire_connection_points[3] = combinator.circuit_wire_connection_points[3], combinator.circuit_wire_connection_points[1]
combinator.circuit_wire_connection_points[2], combinator.circuit_wire_connection_points[4] = combinator.circuit_wire_connection_points[4], combinator.circuit_wire_connection_points[2]
combinator.minable.result = "spoilage-scanner"



data:extend{combinator}