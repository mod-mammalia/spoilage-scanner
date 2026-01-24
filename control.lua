------------------------------------------------------------------------
-- runtime code
------------------------------------------------------------------------

require('lib.init')

-- setup events
require('scripts.event-setup')

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')

Event.on_init(This.on_init)
Event.on_load(This.on_load)

Player.register_events(true)
Framework.post_runtime_stage()
