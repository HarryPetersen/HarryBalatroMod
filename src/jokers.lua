---@diagnostic disable: undefined-global

SMODS.Atlas {
    key = "duo_atlas",
    path = "Duo.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "focus_atlas",
    path = "Focus.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "sneaky_atlas",
    path = "Sneak.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "christmas_atlas",
    path = "Christmas.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "bunk_atlas",
    path = "Bunk.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "lilies_atlas",
    path = "Lilies.png",
    px = 71,
    py = 95
}

SMODS.Atlas {
    key = "sillyboi_atlas",
    path = "SillyBoi.png",
    px = 71, 
    py = 95
}

SMODS.Atlas {
    key = "snoopy_atlas",
    path = "snoopy.png",
    px = 71, 
    py = 95
}

SMODS.Atlas {
    key = "Wans_atlas",
    path = "Wans.png",
    px = 71, 
    py = 95
}

SMODS.Joker {
    key = "awesome_duo",
    name = "Awesome Duo",
    atlas = "duo_atlas",
    pos = { x = 0, y = 0 },
    rarity = 4,
    cost = 20,
    blueprint_compat = false,
    eternal_compat = true,

    loc_txt = {
        name = "Awesome Duo",
        text = {
            "At end of Boss Blind,",
            "Create a {C:dark_edition}Negative{} copy",
            "of a random joker",
            "(Awesome Duo excluded)"
        },
    },

    calculate = function(self, card, context)
        card.ability.extra = card.ability.extra or {}
        card.ability.extra.duplicated = card.ability.extra.duplicated or false

        if context.beat_boss and not card.ability.extra.duplicated then
            local jokers = {}
            for i = 1, #G.jokers.cards do
                if G.jokers.cards[i] ~= card then
                    jokers[#jokers + 1] = G.jokers.cards[i]
                end
            end

            if #jokers > 0 then
                local chosen_joker = pseudorandom_element(jokers, pseudorandom(seed))
                local copied_joker = copy_card(chosen_joker, nil, nil, nil,
                chosen_joker.edition and chosen_joker.edition.negative)
                copied_joker:set_edition("e_negative", true)
                copied_joker:add_to_deck()
                G.jokers:emplace(copied_joker)

                card.ability.extra.duplicated = true
                return { message = localize('k_duplicated_ex') }
            else
                return { message = localize('k_no_other_jokers') }
            end
        end

        if context.setting_blind then
            card.ability.extra.duplicated = false
        end
    end
}

SMODS.Joker {
    key = "focus",
    name = "focus",
    atlas = "focus_atlas",
    pos = { x = 0, y = 0},
    rarity = 1,
    cost = 4,
    blueprint_compat = true,
    eternal_compat = true,

    loc_txt = {
        name = "Focus",
        text = {
            "Gives {C:mult}#1#{} Mult for",
            "each {C:attention}Stone Card",
            "in your {C:attention}full deck",
            "{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)"
        },
    },

    config = { extra = { mult = 9 } },

    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_stone

        local stone_tally = 0
        if G.playing_cards then
            for _, playing_card in ipairs(G.playing_cards) do
                if SMODS.has_enhancement(playing_card, 'm_stone') then stone_tally = stone_tally + 1 end
            end
        end
        return { vars = { card.ability.extra.mult, stone_tally * card.ability.extra.mult } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            local stone_tally = 0
            for _, playing_card in ipairs(G.playing_cards) do
                if SMODS.has_enhancement(playing_card, "m_stone") then stone_tally = stone_tally + 1 end
            end
            return {
                mult = card.ability.extra.mult * stone_tally,
            }
        end
    end,

    in_pool = function(self, args) --equivalent to `enhancement_gate = 'm_stone'`
        for _, playing_card in ipairs(G.playing_cards or {}) do
            if SMODS.has_enhancement(playing_card, 'm_stone') then
                return true
            end
        end
        return false
    end
}

SMODS.Joker {
    key = "sneaky",
    name = "sneaky",
    atlas = "sneaky_atlas",
    pos = { x = 0, y = 0},
    rarity = 2,
    cost = 6,
    blueprint_compat = true,
    eternal_compat = true,

    loc_txt = {
        name = "Sneaky",
        text = {
            "Gives {C:mult}+#1#{} Mult",
        },
    },

    config = { extra = { mult = 400 }, },
    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.mult } }
    end,
    calculate = function(self, card, context)
        if context.joker_main then
            return {
                mult = card.ability.extra.mult
            }
        end
    end
}

SMODS.Joker {
    key = "christmas",
    name = "christmas",
    atlas = "christmas_atlas",
    pos = { x = 0, y = 0 },
    rarity = 3,
    cost = 9,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { dollars = 10 } },

    loc_txt = {
        name = "Christmas",
        text = {
            "Earn {C:money}$#1#{}",
            "for each {C:attention}Steel card{}",
            "held in hand at end of round"
        },
    },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.dollars } }
    end,

    calculate = function(self, card, context)
        if context.end_of_round
            and context.cardarea == G.hand
            and context.individual
            and context.other_card
        then
            local per = (card.ability and card.ability.extra and card.ability.extra.dollars) or 0
            if per <= 0 then return end

            local c = context.other_card
            local center = c.config and c.config.center
            local key = center and center.key

            if key == "m_steel" or key == "c_steel" then
                return { dollars = per }
            end
        end
    end
}

SMODS.Joker{
    key = "bunk",
    name = "Bunk",
    atlas = "bunk_atlas",
    pos = { x = 0, y = 0 },
    rarity = 2,
    cost = 6,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { chips = 20 } },

    loc_txt = {
        name = "Bunk",
        text = {
            "Earn {C:chips}+#1#{} Chips",
            "for each High Card played",
            "{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)"
        },
    },

    loc_vars = function(self, info_queue, card)
        local game = G.GAME or G.Game
        local highcards_played = 0

        if game and game.hands and game.hands["High Card"] and game.hands["High Card"].played then
            highcards_played = game.hands["High Card"].played
        end

        local per = (card.ability and card.ability.extra and card.ability.extra.chips) or 0
        return { vars = { per, per * highcards_played } }
    end,

    calculate = function(self, card, context)
        if context.joker_main then
            local game = G.GAME or G.Game
            local highcards_played = 0

            if game and game.hands and game.hands["High Card"] and game.hands["High Card"].played then
                highcards_played = game.hands["High Card"].played
            end

            return {
                chips = highcards_played * (card.ability.extra.chips or 0)
            }
        end
    end
}

SMODS.Joker {
    key = "lilies",
    name = "lilies",
    atlas = "lilies_atlas",
    pos = { x = 0, y = 0 },
    rarity = 1,
    cost = 12,
    blueprint_compat = true,
    eternal_compat = true,

    config = { extra = { x_chips = 6, type = 'Three of a Kind' } },

    loc_txt = {
        name = "Lilies",
        text = {
            "{C:chips}x#1#{} Chips if played",
            "hand contains",
            "a {C:attention}#2#"
        },
    },

    loc_vars = function(self, info_queue, card)
        return { vars = { card.ability.extra.x_chips, localize(card.ability.extra.type, 'poker_hands') } }
    end,

    calculate = function(self, card, context)
        if context.joker_main and next(context.poker_hands[card.ability.extra.type]) then
            return {
                xchips = card.ability.extra.x_chips
            }
        end
    end
}

SMODS.Joker{
  key = "sillyboi",
  name = "Silly Boi",
  atlas = "sillyboi_atlas",
  pos = { x = 0, y = 0 },
  rarity = 2,
  cost = 10,
  blueprint_compat = false,
  eternal_compat = true,

  config = { extra = { hands = 5 } },
  loc_vars = function(self, info_queue, card)
    return { vars = { card.ability.extra.hands } }
  end,

  loc_txt = {
    name = "Silly Boi",
    text = {
      "Gain +#1# hands",
    },
  },

  add_to_deck = function(self, card, from_debuff)
        G.GAME.round_resets.hands = G.GAME.round_resets.hands + card.ability.extra.hands
        ease_hands_played(card.ability.extra.hands)
    end,
    remove_from_deck = function(self, card, from_debuff)
        G.GAME.round_resets.hands = G.GAME.round_resets.hands - card.ability.extra.hands
        ease_hands_played(-card.ability.extra.hands)
    end
}

SMODS.Joker{
    key = "snoopy",
    name = "Snoopy",
    atlas = "snoopy_atlas",
    pos = { x = 0, y = 0 },
    rarity = 2,
    cost = 5,
    blueprint_compat = false,
    eternal_compat = true,

    config = { extra = {odds = 2, repetitions = 2}},

    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, 'snoopy')
        return { vars = { numerator, denominator, card.ability.extra.repetitions } }
    end,

    loc_txt = {
        name = "Snoopy",
        text = {
        "{C:green}#1# in #2#{} chance for",
        "played cards to retrigger",
        "{C:attention} #3# {} Times when scored",
        },
    },

    calculate = function(self, card, context)
        if context.repetition
            and context.cardarea == G.play
            and SMODS.pseudorandom_probability(card, 'snoopy', 1, card.ability.extra.odds)
        then
            return {
                repetitions = card.ability.extra.repetitions
            }
        end
    end,
}

SMODS.Joker{
    key = "wans",
    name = "Wans",
    atlas = "Wans_atlas",
    pos = { x = 0, y = 0 },
    rarity = 3,
    cost = 10,
    blueprint_compat = false,
    eternal_compat = true,

    config = { extra = { dollars = 5 } },
    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS.m_lucky
        return { vars = { card.ability.extra.dollars} }
    end,

    loc_txt = {
        name = "Cheeky Cat",
        text = {
            "Played {C:attention}Lucky{} cards",
            "earn {C:money}$#1#{} when scored",
        },
    },

    calculate = function(self, card, context)
        if context.individual and context.cardarea == G.play and
            SMODS.has_enhancement(context.other_card, 'm_lucky') then
            G.GAME.dollar_buffer = (G.GAME.dollar_buffer or 0) + card.ability.extra.dollars
            return {
                dollars = card.ability.extra.dollars,
                func = function() -- This is for timing purposes, it runs after the dollar manipulation
                    G.E_MANAGER:add_event(Event({
                        func = function()
                            G.GAME.dollar_buffer = 0
                            return true
                        end
                    }))
                end
            }
        end
    end,

    in_pool = function(self, args) --equivalent to `enhancement_gate = 'm_lucky'`
        for _, playing_card in ipairs(G.playing_cards or {}) do
            if SMODS.has_enhancement(playing_card, 'm_lucky') then
                return true
            end
        end
        return false
    end,
}