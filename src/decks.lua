---@diagnostic disable: undefined-global

SMODS.Atlas {
    key = "fun",
    path = "fun.png",
    px = 71,
    py = 95
}

SMODS.Back {
    key = "fun",
    atlas = "fun",
    loc_txt = {
        name = "Fun Deck",
        text = {
            "+#1# Joker Slots",
        },
    },
    pos = { x = 0, y = 0 },
    config = { joker_slots = 5 },
    unlocked = true,

    apply = function(self, back)
        G.GAME.starting_params.joker_slots =
            G.GAME.starting_params.joker_slots + self.config.joker_slots
    end,

    loc_vars = function(self, info_queue, back)
        return { vars = { self.config.joker_slots } }
    end,
}

SMODS.Atlas {
    key = "random_values",
    path = "fun.png",
    px = 71,
    py = 95
}

SMODS.Back {
    key = "random_values",
    atlas = "random_values",
    loc_txt = {
        name = "Random Values Deck",
        text = {
            "Randomizes Joker values",
            "Randomizes Joker cost and sell value",
            "Randomizes Poker Hand chips and mult",
            "Values are randomized from x#1# to x#2#"
        },
    },
    pos = { x = 0, y = 0 },

    config = {
        min = 0.1,
        max = 10
    },

    unlocked = true,

    apply = function(self, back)
        G.GAME.modifiers.gilia_random_values = true
        G.GAME.modifiers.gilia_random_min = self.config.min
        G.GAME.modifiers.gilia_random_max = self.config.max
        G.GAME.modifiers.gilia_random_booster_card_enhance_chance = 1

        -- Try to randomize hands immediately when the run starts
        if Gilia_randomize_poker_hands then
            Gilia_randomize_poker_hands()
        end
    end,

    loc_vars = function(self, info_queue, back)
        return {
            vars = {
                self.config.min,
                self.config.max
            }
        }
    end,
}