---@diagnostic disable: undefined-global

local function all_hand_cards()
    local t = {}
    if not (G and G.hand and G.hand.cards) then return t end
    for _, c in ipairs(G.hand.cards) do
        if c and not c.debuff and not c.removed then
        t[#t+1] = c
        end
    end
    return t
end

local function rand_index(n, seed)
    if pseudorandom then
        return math.min(n, math.max(1, math.floor(pseudorandom(seed) * n) + 1))
    end
    return math.random(1, n)
end

SMODS.Atlas {
    key = "haribow_atlas",
    path = "Haribow.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "couldhavebeen_atlas",
    path = "CouldHaveBeen.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "pizzabox_atlas",
    path = "PizzaBox.png",
    px = 71,
    py = 95
}

SMODS.Consumable {
    key = "pizzabox",
    name = "pizzabox",
    atlas = "pizzabox_atlas",
    set = "Spectral",
    pos = { x = 0, y = 0 },

    config = { extra = { seal = 'Blue' } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_SEALS[card.ability.extra.seal]
    end,

    loc_txt = {
        name = "Pizza Box",
        text = {
            "Adds {C:blue}Blue Seal{} to all",
            "cards in hand,",
            "sets money to {C:money}$0"
        },
    },

    use = function(self, card, area, copier)
        local cards_in_hand = all_hand_cards()
        for c, i in ipairs(cards_in_hand) do
            G.E_MANAGER:add_event(Event({
                func = function()
                    play_sound('tarot1')
                    card:juice_up(0.3, 0.5)
                    return true
                end
            }))

            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.1,
                func = function()
                    i:set_seal(card.ability.extra.seal, nil, true)
                    return true
                end
            }))

            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.4,
                func = function()
                    play_sound('timpani')
                    card:juice_up(0.3, 0.5)
                    if G.GAME.dollars ~= 0 then
                        ease_dollars(-G.GAME.dollars, true)
                    end
                    return true
                end
            }))
        end
    end,

    can_use = function(self, card)
        return G and G.hand and G.hand.cards and #G.hand.cards > 0
    end,
}

SMODS.Consumable {
    key = "haribow",
    set = "Spectral",
    atlas = "haribow_atlas",
    pos = { x = 0, y = 0 },
    config = { extra = { destroy = 2, enhancement = "m_steel" } },
    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.destroy, card.ability.extra.enhancement } }
    end,

    loc_txt = {
        name = "Haribow",
        text = {
        "Destroys {C:attention}#1#{} random",
        "cards in hand,",
        "Turn the rest into {C:attention}Steel Cards{}"
        }
    },

    can_use = function(self, card)
        return G and G.hand and G.hand.cards and #G.hand.cards > 0
    end,

    use = function(self, card, area, copier)
        local hand = all_hand_cards()
        if #hand == 0 then return end

        local destroy_n = math.min(card.ability.extra.destroy or 2, #hand)

        -- pick destroy_n distinct cards from hand (without replacement)
        local to_destroy = {}
        for i = 1, destroy_n do
        local idx = rand_index(#hand, "haribow_destroy_" .. i)
        to_destroy[#to_destroy+1] = table.remove(hand, idx)
        end

        -- 1) dissolve destroyed cards with small stagger (looks nicer + avoids timing weirdness)
        for i, c in ipairs(to_destroy) do
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.08 * (i-1),
            func = function()
            if c and c.start_dissolve and not c.removed then
                c:start_dissolve(nil, true)
            elseif c and c.remove then
                c:remove()
            end
            return true
            end
        }))
        end

        -- 2) after dissolves begin, flip+steel+flip the remaining hand cards
        G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0.15 + 0.08 * destroy_n,
        func = function()
            local remaining = all_hand_cards()
            for i, c in ipairs(remaining) do
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.03 * (i-1),
                func = function()
                if not (c and c.set_ability and G.P_CENTERS and G.P_CENTERS.m_steel) then return true end

                -- flip down -> apply -> flip up
                if c.flip then c:flip() end
                
                G.E_MANAGER:add_event(Event({
                    trigger = 'after',
                    delay = 0,
                    func = function()
                    if c and not c.removed then
                        c:set_ability(G.P_CENTERS.m_steel, nil, true)
                        if c.juice_up then c:juice_up(0.2, 0.2) end
                    end
                    G.E_MANAGER:add_event(Event({
                        trigger = 'after',
                        delay = 0.4,
                        func = function()
                        if c and c.flip then c:flip() end
                        return true
                        end
                    }))
                    return true
                    end
                }))

                return true
                end
            }))
            end
            return true
        end
        }))
    end,
}

SMODS.Consumable{
    key = "couldhavebeen",
    name = "couldhavebeen",
    atlas = "couldhavebeen_atlas",
    set = "Spectral",
    pos = { x = 0, y = 0 },

    config = { extra = { max_highlighted = 1, min_highlighted = 1 } },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.max_highlighted } }
    end,

    loc_txt = {
        name = "Could Have Been",
        text = {
            "Select {C:attention}#1#{} card",
            "Turn all other cards in hand",
            "into that card"
        },
    },

    use = function(self, card, area, copier)
        local cards_in_hand = all_hand_cards()

        -- flip all cards (animation)
        for i = 1, #cards_in_hand do
            local percent = 1.15 - (i - 0.999) / (#cards_in_hand - 0.998) * 0.3
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.15,
                func = function()
                    cards_in_hand[i]:flip()
                    play_sound('card1', percent)
                    cards_in_hand[i]:juice_up(0.3, 0.3)
                    return true
                end
            }))
        end

        local selected_card = G.hand.highlighted and G.hand.highlighted[1]
        if not selected_card then return end

        -- copy selected into all others
        for i = 1, #cards_in_hand do
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.1,
                func = function()
                    if cards_in_hand[i] ~= selected_card then
                        copy_card(selected_card, cards_in_hand[i])
                    end
                    return true
                end
            }))
        end

        -- flip back (animation)
        for i = 1, #cards_in_hand do
            local percent = 1.15 - (i - 0.999) / (#cards_in_hand - 0.998) * 0.3
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.15,
                func = function()
                    cards_in_hand[i]:flip()
                    play_sound('card1', percent)
                    cards_in_hand[i]:juice_up(0.3, 0.3)
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

    can_use = function(self, card)
        local hi = (G.hand and G.hand.highlighted) and #G.hand.highlighted or 0
        return G.hand
            and hi >= card.ability.extra.min_highlighted
            and hi <= card.ability.extra.max_highlighted
    end,
}