local combinator_recipe = {
  type = "recipe",
  name = "spoilage-scanner",
  enabled = false,
  ingredients =
  {
    {type = "item", name = "copper-cable", amount = 5},
    {type = "item", name = "advanced-circuit", amount = 2}
  },
  results = {{type="item", name="spoilage-scanner", amount=1}}
}

if mods["pyalternativeenergy"] then
  combinator_recipe.ingredients = {
    {type = "item", name = "copper-cable", amount = 5},
    {type = "item", name = "electronic-circuit", amount = 2},
    {type = "item", name = "battery-mk01", amount = 1}
  }
end

data:extend{combinator_recipe}
table.insert(data.raw["technology"]["advanced-combinators"].effects, { type = "unlock-recipe", recipe = "spoilage-scanner" } )