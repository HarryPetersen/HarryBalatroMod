---@diagnostic disable: undefined-global


SMODS.Atlas {
    key = "takeaway_atlas",
    path = "TakeAway.png",
    px = 71,
    py = 95
}

SMODS.Atlas{
    key = "doubletrouble_atlas",
    path = "DoubleTrouble.png",
    px=71,
    py = 95
}

SMODS.Consumable {
    key = "takeaway",
    set = "Tarot",
    atlas = "takeaway_atlas",
    pos = { x = 0, y = 0 },

    config = {
        max_highlighted = 2,
        rank_change = 1
    },

    cost = 3,

    loc_txt = {
        name = "Take Away",
        text = {
            "Decrease the rank of up to",
            "{C:attention}#1#{} selected cards by {C:attention}#2#{}",
        }
    },

    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                card.ability.max_highlighted or self.config.max_highlighted,
                card.ability.rank_change or self.config.rank_change
            }
        }
    end,

    can_use = function(self, card)
        local h = G.hand and G.hand.highlighted or {}
        local max_highlighted = card.ability.max_highlighted or self.config.max_highlighted or 2

        return #h > 0 and #h <= max_highlighted
    end,

    use = function(self, card, area, copier)
        local rank_change = card.ability.rank_change or self.config.rank_change or 1

        -- Ranks cannot safely change by decimals.
        -- Example: rank change of 2.7 becomes 3.
        rank_change = math.max(1, math.floor(rank_change + 0.5))

        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.4,
            func = function()
                play_sound('tarot1')
                card:juice_up(0.3, 0.5)
                return true
            end
        }))

        for i = 1, #G.hand.highlighted do
            local percent = 1.15 - (i - 0.999) / (#G.hand.highlighted - 0.998) * 0.3
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.15,
                func = function()
                    G.hand.highlighted[i]:flip()
                    play_sound('card1', percent)
                    G.hand.highlighted[i]:juice_up(0.3, 0.3)
                    return true
                end
            }))
        end

        delay(0.2)

        for i = 1, #G.hand.highlighted do
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.1,
                func = function()
                    assert(SMODS.modify_rank(G.hand.highlighted[i], -rank_change))
                    return true
                end
            }))
        end

        for i = 1, #G.hand.highlighted do
            local percent = 0.85 + (i - 0.999) / (#G.hand.highlighted - 0.998) * 0.3
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.15,
                func = function()
                    G.hand.highlighted[i]:flip()
                    play_sound('tarot2', percent, 0.6)
                    G.hand.highlighted[i]:juice_up(0.3, 0.3)
                    return true
                end
            }))
        end

        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.2,
            func = function()
                G.hand:unhighlight_all()
                return true
            end
        }))

        delay(0.5)
    end,
}

SMODS.Consumable {
    key = 'doubletrouble',
    set = "Tarot",
    atlas = "doubletrouble_atlas",
    pos = { x = 0, y = 0 },
    cost = 5,

    config = { max_highlighted = 3, min_highlighted = 2 },

    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                card.ability.min_highlighted or self.config.min_highlighted,
                card.ability.max_highlighted or self.config.max_highlighted
            }
        }
    end,

    can_use = function(self, card)
        local h = G.hand and G.hand.highlighted or {}
        local min_highlighted = card.ability.min_highlighted or self.config.min_highlighted or 2
        local max_highlighted = card.ability.max_highlighted or self.config.max_highlighted or 3

        return #h >= min_highlighted and #h <= max_highlighted
    end,

    loc_txt = {
        name = "Double Trouble",
        text = {
            "Select {C:attention}#1#{} to {C:attention}#2#{} cards,",
            "convert the {C:attention}left{} card(s)",
            "into the {C:attention}right{} card",
            "{C:inactive}(Drag to rearrange)",
        },
    },

    use = function(self, card, area, copier)
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.4,
            func = function()
                play_sound('tarot1')
                card:juice_up(0.3, 0.5)
                return true
            end
        }))
        for i = 1, #G.hand.highlighted do
            local percent = 1.15 - (i - 0.999) / (#G.hand.highlighted - 0.998) * 0.3
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.15,
                func = function()
                    G.hand.highlighted[i]:flip()
                    play_sound('card1', percent)
                    G.hand.highlighted[i]:juice_up(0.3, 0.3)
                    return true
                end
            }))
        end
        delay(0.2)
        local rightmost = G.hand.highlighted[1]
        for i = 1, #G.hand.highlighted do
            if G.hand.highlighted[i].T.x > rightmost.T.x then
                rightmost = G.hand.highlighted[i]
            end
        end
        for i = 1, #G.hand.highlighted do
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.1,
                func = function()
                    if G.hand.highlighted[i] ~= rightmost then
                        copy_card(rightmost, G.hand.highlighted[i])
                    end
                    return true
                end
            }))
        end
        for i = 1, #G.hand.highlighted do
            local percent = 0.85 + (i - 0.999) / (#G.hand.highlighted - 0.998) * 0.3
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.15,
                func = function()
                    G.hand.highlighted[i]:flip()
                    play_sound('tarot2', percent, 0.6)
                    G.hand.highlighted[i]:juice_up(0.3, 0.3)
                    return true
                end
            }))
        end
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.2,
            func = function()
                G.hand:unhighlight_all()
                return true
            end
        }))
        delay(0.5)
    end,
}