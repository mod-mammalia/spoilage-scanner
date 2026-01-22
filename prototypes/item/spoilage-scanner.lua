local combinator_item = table.deepcopy(data.raw["item"]["constant-combinator"])
combinator_item.name = "spoilage-scanner"
combinator_item.place_result = "spoilage-scanner"
combinator_item.icon = "__spoilage-scanner__/graphics/icons/spoilage-scanner.png"

data:extend{combinator_item}