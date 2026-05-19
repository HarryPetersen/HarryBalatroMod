---@diagnostic disable: undefined-global


local function gilia_random_values_enabled()
    return G
        and G.GAME
        and G.GAME.modifiers
        and G.GAME.modifiers.gilia_random_values
end

local function gilia_deep_copy(t)
    if type(t) ~= "table" then return t end

    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = gilia_deep_copy(v)
        else
            copy[k] = v
        end
    end

    return copy
end

local function gilia_get_run_seed()
    if G and G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed then
        return tostring(G.GAME.pseudorandom.seed)
    end

    if G and G.GAME and G.GAME.seed then
        return tostring(G.GAME.seed)
    end

    return tostring(os.time())
end

local function gilia_get_card_seed(card)
    if not card then return "no_card" end

    return tostring(
        card.sort_id
        or card.ID
        or card.unique_val
        or card.creation_seed
        or "card"
    )
end


local function gilia_get_curve_power()
    if G and G.GAME and G.GAME.modifiers and G.GAME.modifiers.gilia_random_curve_power then
        return G.GAME.modifiers.gilia_random_curve_power
    end

    -- Higher = values stay closer to x1 more often.
    -- Lower = more chaotic.
    return 2.4
end

local function gilia_random_float(seed, min, max)
    -- Curved random multiplier.
    -- 1 is the most common result.
    -- 50% chance below 1, 50% chance above 1.
    -- High values are possible but rarer.

    if min > max then
        min, max = max, min
    end

    min = math.max(0, min)
    max = math.max(min, max)

    local curve_power = gilia_get_curve_power()

    local side = pseudorandom(seed .. "_side")
    local distance = pseudorandom(seed .. "_distance") ^ curve_power

    if side < 0.5 then
        return 1 - ((1 - min) * distance)
    else
        return 1 + ((max - 1) * distance)
    end
end

local function gilia_get_global_min_max()
    local min = G.GAME.modifiers.gilia_random_min or 0.1
    local max = G.GAME.modifiers.gilia_random_max or 10
    return min, max
end

local function gilia_get_range_for_set(center_set, purpose)
    local global_min, global_max = gilia_get_global_min_max()
    local m = G.GAME.modifiers

    -- Costs are kept calmer by default.
    if purpose == "cost" then
        return m.gilia_random_cost_min or 0.5,
            m.gilia_random_cost_max or math.min(global_max, 3)
    end

    -- Playing cards found in booster packs.
    if purpose == "playing_card" then
        return m.gilia_random_playing_card_min or 0.1,
            m.gilia_random_playing_card_max or math.min(global_max, 5)
    end

    -- Poker hand starting chips/mult and planet upgrades.
    if purpose == "hand" then
        return m.gilia_random_hand_min or 0.5,
            m.gilia_random_hand_max or math.min(global_max, 3)
    end

    if center_set == "Joker" then
        return m.gilia_random_joker_min or global_min,
            m.gilia_random_joker_max or global_max
    end

    if center_set == "Tarot" or center_set == "Spectral" or center_set == "Planet" then
        return m.gilia_random_consumable_min or global_min,
            m.gilia_random_consumable_max or math.min(global_max, 5)
    end

    if center_set == "Booster" then
        return m.gilia_random_booster_min or 0.5,
            m.gilia_random_booster_max or math.min(global_max, 3)
    end

    if center_set == "Voucher" then
        return m.gilia_random_voucher_min or 0.5,
            m.gilia_random_voucher_max or math.min(global_max, 4)
    end

    if center_set == "Enhanced" then
        return m.gilia_random_enhancement_min or global_min,
            m.gilia_random_enhancement_max or math.min(global_max, 5)
    end

    return global_min, global_max
end

local function gilia_get_original_center_config(center)
    if not center then return nil end

    -- Save the card center's original config once.
    -- This prevents a Tarot value like 2 becoming 23, then 232, etc.
    if not center.gilia_original_config then
        center.gilia_original_config = gilia_deep_copy(center.config or {})
    end

    return center.gilia_original_config
end

local function gilia_get_base_from_original_config(center, path, fallback)
    local original_config = gilia_get_original_center_config(center)
    if type(original_config) ~= "table" then return fallback end

    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(parts, part)
    end

    -- ability.extra maps to config.extra
    if parts[1] == "ability" then
        table.remove(parts, 1)
    end

    local current = original_config
    for _, part in ipairs(parts) do
        if type(current) ~= "table" then
            return fallback
        end

        current = current[part]
    end

    if type(current) == "number" then
        return current
    end

    return fallback
end

local function gilia_is_randomizable_set(set)
    return set == "Joker"
        or set == "Tarot"
        or set == "Planet"
        or set == "Spectral"
        or set == "Voucher"
        or set == "Booster"
        or set == "Enhanced"
end

local function gilia_should_skip_number_key(k)
    if type(k) == "string" and string.sub(k, 1, 6) == "gilia_" then
        return true
    end

    return k == "id"
        or k == "order"
        or k == "sort_id"

        -- Never randomize slot/area values.
        or k == "card_limit"
        or k == "extra_slots_used"
        or k == "consumeable_limit"
        or k == "consumable_slots"
        or k == "joker_slots"
        or k == "slots"

        -- min_highlighted often makes cards unusable if randomized.
        or k == "min_highlighted"

        -- Visual/metadata values.
        or k == "x"
        or k == "y"
        or k == "h"
        or k == "w"
        or k == "played"
        or k == "visible"
        or k == "discovered"
        or k == "unlocked"
        or k == "alerted"
        or k == "bypass_discovery_center"
        or k == "bypass_discovery_ui"
end

local function gilia_is_allowed_joker_key(k)
    -- Do NOT include x_mult/xmult/Xmult here.
    -- Some Jokers have hidden/default x_mult = 1 even when they are not
    -- meant to give X Mult.

    return k == "extra"
        or k == "mult"
        or k == "chips"
        or k == "money"
        or k == "dollars"
        or k == "h_size"
        or k == "hands"
        or k == "discards"
        or k == "odds"
        or k == "prob"
        or k == "probability"
        or k == "retriggers"
        or k == "repetitions"
        or k == "s_mult"
        or k == "s_chips"
end

local function gilia_must_be_integer_key(k, center_set)
    -- Counts must stay whole numbers.
    -- Normal values like mult, chips, cost, sell value, etc. can keep decimals.

    if k == "choose"
        or k == "max_highlighted"
        or k == "rank_change"
        or k == "hand_size"
        or k == "hands"
        or k == "discards"
    then
        return true
    end

    -- For consumables and booster packs, "extra" is often a count.
    -- Example: High Priestess creating 2 Planet cards.
    if k == "extra" and (
        center_set == "Tarot"
        or center_set == "Spectral"
        or center_set == "Booster"
    ) then
        return true
    end

    return false
end

local function gilia_integer_min_for_key(k, center_set)
    -- Booster packs should never show 0 cards or let you choose 0 cards.
    if center_set == "Booster" then
        return 1
    end

    -- Tarot/Spectral creation counts can become 0.
    if center_set == "Tarot" or center_set == "Spectral" then
        if k == "extra" then
            return 0
        end
    end

    return 1
end

local function gilia_integer_max_for_key(k, center_set)
    -- Safety caps to prevent UI explosions.

    if center_set == "Tarot" or center_set == "Spectral" then
        if k == "extra" then
            return 20
        end

        if k == "max_highlighted" then
            return 30
        end
    end

    if center_set == "Booster" then
        if k == "extra" then
            return 12
        end

        if k == "choose" then
            return 6
        end
    end

    return nil
end

local function gilia_clamp_randomized_value(base_value, randomized_value, min, max)
    if type(base_value) ~= "number" then return randomized_value end

    local low = base_value * min
    local high = base_value * max

    if low > high then
        low, high = high, low
    end

    if randomized_value < low then randomized_value = low end
    if randomized_value > high then randomized_value = high end

    return randomized_value
end

local function gilia_randomize_numbers_in_table(t, card, center, seed_prefix, min, max, path, center_set)
    if type(t) ~= "table" then return end
    if not card then return end
    if not center then return end

    card.gilia_random_base_numbers = card.gilia_random_base_numbers or {}

    for k, v in pairs(t) do
        local current_path = path .. "." .. tostring(k)

        if type(v) == "number" then
            if not gilia_should_skip_number_key(k) then

                local base_value = gilia_get_base_from_original_config(center, current_path, nil)

                if center_set == "Joker" then
                    -- For Jokers, only randomize values that:
                    -- 1. use an allowed effect-style key
                    -- 2. actually exist in the Joker's original config
                    --
                    -- This stops hidden/default x_mult = 1 from becoming accidental x4 Mult.
                    if not gilia_is_allowed_joker_key(k) then
                        goto continue
                    end

                    if base_value == nil then
                        goto continue
                    end
                else
                    -- For non-Jokers, fallback to the first seen value if not found in center.config.
                    if base_value == nil then
                        if card.gilia_random_base_numbers[current_path] == nil then
                            card.gilia_random_base_numbers[current_path] = v
                        end
                        base_value = card.gilia_random_base_numbers[current_path]
                    end
                end

                local mult = gilia_random_float(seed_prefix .. "_" .. current_path, min, max)
                local new_value = base_value * mult

                new_value = gilia_clamp_randomized_value(base_value, new_value, min, max)

                if gilia_must_be_integer_key(k, center_set) then
                    local min_integer = gilia_integer_min_for_key(k, center_set)
                    local max_integer = gilia_integer_max_for_key(k, center_set)

                    new_value = math.max(min_integer, math.floor(new_value + 0.5))

                    if max_integer then
                        new_value = math.min(new_value, max_integer)
                    end
                end

                t[k] = new_value
            end
        elseif type(v) == "table" then
            gilia_randomize_numbers_in_table(v, card, center, seed_prefix, min, max, current_path, center_set)
        end

        ::continue::
    end
end


local function gilia_fix_booster_values(card)
    if not card or not card.ability then return end

    local ability = card.ability

    if type(ability.extra) == "number" then
        ability.extra = math.max(1, math.floor(ability.extra + 0.5))
        ability.extra = math.min(ability.extra, 12)
    end

    if type(ability.choose) == "number" then
        ability.choose = math.max(1, math.floor(ability.choose + 0.5))
        ability.choose = math.min(ability.choose, 6)
    end

    if type(ability.extra) == "number" and type(ability.choose) == "number" then
        ability.choose = math.min(ability.choose, ability.extra)
    end
end


local function gilia_wrap_consumable_can_use(center)
    if not center then return end
    if center.gilia_wrapped_can_use then return end
    if type(center.can_use) ~= "function" then return end

    center.gilia_wrapped_can_use = true
    center.gilia_original_can_use = center.can_use

    center.can_use = function(self, card)
        if not gilia_random_values_enabled() then
            return self.gilia_original_can_use(self, card)
        end

        if not card or not card.ability then
            return self.gilia_original_can_use(self, card)
        end

        self.config = self.config or {}

        local old_max_highlighted = self.config.max_highlighted
        local old_min_highlighted = self.config.min_highlighted
        local old_extra = self.config.extra
        local old_choose = self.config.choose

        if type(card.ability.max_highlighted) == "number" then
            self.config.max_highlighted = card.ability.max_highlighted
        end

        if type(card.ability.min_highlighted) == "number" then
            self.config.min_highlighted = card.ability.min_highlighted
        end

        if type(card.ability.extra) == "number" then
            self.config.extra = card.ability.extra
        end

        if type(card.ability.choose) == "number" then
            self.config.choose = card.ability.choose
        end

        local result = self.gilia_original_can_use(self, card)

        self.config.max_highlighted = old_max_highlighted
        self.config.min_highlighted = old_min_highlighted
        self.config.extra = old_extra
        self.config.choose = old_choose

        return result
    end
end


function Gilia_randomize_poker_hands()
    if not gilia_random_values_enabled() then return end
    if not G.GAME.hands then return end
    if G.GAME.gilia_randomized_poker_hands then return end

    local min, max = gilia_get_range_for_set(nil, "hand")
    local run_seed = gilia_get_run_seed()

    G.GAME.gilia_base_poker_hands = G.GAME.gilia_base_poker_hands or {}

    for hand_name, hand in pairs(G.GAME.hands) do
        if type(hand) == "table" then
            G.GAME.gilia_base_poker_hands[hand_name] = G.GAME.gilia_base_poker_hands[hand_name] or {
                chips = hand.chips,
                mult = hand.mult
            }

            local base_chips = G.GAME.gilia_base_poker_hands[hand_name].chips
            local base_mult = G.GAME.gilia_base_poker_hands[hand_name].mult

            if type(base_chips) == "number" then
                local chips_mult = gilia_random_float(
                    "gilia_" .. run_seed .. "_hand_chips_" .. tostring(hand_name),
                    min,
                    max
                )

                hand.chips = gilia_clamp_randomized_value(
                    base_chips,
                    base_chips * chips_mult,
                    min,
                    max
                )
            end

            if type(base_mult) == "number" then
                local mult_mult = gilia_random_float(
                    "gilia_" .. run_seed .. "_hand_mult_" .. tostring(hand_name),
                    min,
                    max
                )

                hand.mult = gilia_clamp_randomized_value(
                    base_mult,
                    base_mult * mult_mult,
                    min,
                    max
                )
            end
        end
    end

    G.GAME.gilia_randomized_poker_hands = true
end

function Gilia_randomise_poker_hands()
    return Gilia_randomize_poker_hands()
end


local function gilia_is_playing_card(card)
    return card
        and card.base
        and card.config
        and card.config.card
end

local function gilia_get_random_base_card(seed)
    if not G or not G.P_CARDS then return nil end

    local possible = {}

    for _, base_card in pairs(G.P_CARDS) do
        if type(base_card) == "table"
            and base_card.suit
            and base_card.value
            and not base_card.no_rank
        then
            possible[#possible + 1] = base_card
        end
    end

    if #possible == 0 then return nil end

    local index = math.floor(pseudorandom(seed) * #possible) + 1
    index = math.max(1, math.min(index, #possible))

    return possible[index]
end

local function gilia_get_random_enhancement(seed)
    if not G or not G.P_CENTERS then return nil end

    local enhancements = {
        "m_bonus",
        "m_mult",
        "m_wild",
        "m_glass",
        "m_steel",
        "m_stone",
        "m_gold",
        "m_lucky"
    }

    local possible = {}

    for _, key in ipairs(enhancements) do
        if G.P_CENTERS[key] then
            possible[#possible + 1] = G.P_CENTERS[key]
        end
    end

    if #possible == 0 then return nil end

    local index = math.floor(pseudorandom(seed) * #possible) + 1
    index = math.max(1, math.min(index, #possible))

    return possible[index]
end

local function gilia_randomize_playing_card_from_booster(card)
    if not gilia_random_values_enabled() then return end
    if not gilia_is_playing_card(card) then return end
    if card.gilia_randomized_booster_playing_card then return end

    card.gilia_randomized_booster_playing_card = true

    local run_seed = gilia_get_run_seed()
    local card_seed = gilia_get_card_seed(card)

    -- Randomize the actual playing card rank/suit.
    local random_base = gilia_get_random_base_card(
        "gilia_" .. run_seed .. "_booster_playing_base_" .. card_seed
    )

    if random_base and card.set_base then
        card:set_base(random_base)
    end

    -- Chance for a random enhancement.
    -- Change 0.5 to 1 if you want every booster card to be enhanced.
    local enhance_chance = G.GAME.modifiers.gilia_random_booster_card_enhance_chance or 0.5

    if pseudorandom("gilia_" .. run_seed .. "_booster_enhance_chance_" .. card_seed) < enhance_chance then
        local enhancement = gilia_get_random_enhancement(
            "gilia_" .. run_seed .. "_booster_enhancement_" .. card_seed
        )

        if enhancement and card.set_ability then
            card:set_ability(enhancement)
        end
    end
end

local old_card_set_ability = Card.set_ability

function Card:set_ability(center, initial, delay_sprites)
    old_card_set_ability(self, center, initial, delay_sprites)

    if not gilia_random_values_enabled() then return end
    if not center or not gilia_is_randomizable_set(center.set) then return end
    if not self.ability then return end

    gilia_get_original_center_config(center)

    if center.set == "Tarot" or center.set == "Spectral" then
        gilia_wrap_consumable_can_use(center)
    end

    local center_key = tostring(center.set or "unknown_set") .. "_" .. tostring(center.key or center.name or "unknown_card")

    if self.gilia_random_center_key ~= center_key then
        self.gilia_random_center_key = center_key
        self.gilia_random_base_numbers = {}
    end

    local min, max = gilia_get_range_for_set(center.set, nil)
    local run_seed = gilia_get_run_seed()
    local card_seed = gilia_get_card_seed(self)

    local seed_prefix =
        "gilia_"
        .. run_seed
        .. "_"
        .. center_key
        .. "_"
        .. card_seed

    gilia_randomize_numbers_in_table(
        self.ability,
        self,
        center,
        seed_prefix,
        min,
        max,
        "ability",
        center.set
    )

    if center.set == "Booster" then
        gilia_fix_booster_values(self)
    end
end

local old_card_set_cost = Card.set_cost

function Card:set_cost()
    old_card_set_cost(self)

    if not gilia_random_values_enabled() then return end
    if not self.config or not self.config.center then return end
    if not gilia_is_randomizable_set(self.config.center.set) then return end

    local center = self.config.center
    local min, max = gilia_get_range_for_set(center.set, "cost")
    local run_seed = gilia_get_run_seed()
    local card_seed = gilia_get_card_seed(self)

    if self.gilia_random_base_cost == nil and type(self.cost) == "number" then
        self.gilia_random_base_cost = self.cost
    end

    if self.gilia_random_base_sell_cost == nil and type(self.sell_cost) == "number" then
        self.gilia_random_base_sell_cost = self.sell_cost
    end

    if not self.gilia_random_cost_mult then
        self.gilia_random_cost_mult = gilia_random_float(
            "gilia_"
                .. run_seed
                .. "_cost_"
                .. tostring(center.set or "unknown_set")
                .. "_"
                .. tostring(center.key or center.name or "unknown_card")
                .. "_"
                .. card_seed,
            min,
            max
        )
    end

    if not self.gilia_random_sell_mult then
        self.gilia_random_sell_mult = gilia_random_float(
            "gilia_"
                .. run_seed
                .. "_sell_"
                .. tostring(center.set or "unknown_set")
                .. "_"
                .. tostring(center.key or center.name or "unknown_card")
                .. "_"
                .. card_seed,
            min,
            max
        )
    end

    if type(self.gilia_random_base_cost) == "number" then
        self.cost = math.max(
            0,
            self.gilia_random_base_cost * self.gilia_random_cost_mult
        )
    end

    if type(self.gilia_random_base_sell_cost) == "number" then
        self.sell_cost = math.max(
            0,
            self.gilia_random_base_sell_cost * self.gilia_random_sell_mult
        )
    end
end

local old_level_up_hand = level_up_hand

function level_up_hand(card, hand, instant, amount)
    if not gilia_random_values_enabled() then
        return old_level_up_hand(card, hand, instant, amount)
    end

    if not G.GAME or not G.GAME.hands or not hand or not G.GAME.hands[hand] then
        return old_level_up_hand(card, hand, instant, amount)
    end

    local hand_data = G.GAME.hands[hand]
    local old_chips = hand_data.chips or 0
    local old_mult = hand_data.mult or 0

    local result = old_level_up_hand(card, hand, instant, amount)

    local new_chips = hand_data.chips or old_chips
    local new_mult = hand_data.mult or old_mult

    local chips_gained = new_chips - old_chips
    local mult_gained = new_mult - old_mult

    if chips_gained ~= 0 or mult_gained ~= 0 then
        local min, max = gilia_get_range_for_set(nil, "hand")
        local run_seed = gilia_get_run_seed()
        local card_seed = gilia_get_card_seed(card)

        local chips_mult = gilia_random_float(
            "gilia_"
                .. run_seed
                .. "_planet_chips_"
                .. tostring(hand)
                .. "_"
                .. card_seed,
            min,
            max
        )

        local mult_mult = gilia_random_float(
            "gilia_"
                .. run_seed
                .. "_planet_mult_"
                .. tostring(hand)
                .. "_"
                .. card_seed,
            min,
            max
        )

        hand_data.chips = math.max(0, old_chips + chips_gained * chips_mult)
        hand_data.mult = math.max(0, old_mult + mult_gained * mult_mult)
    end

    return result
end

local old_cardarea_emplace = CardArea.emplace

function CardArea:emplace(card, location, stay_flipped)
    local result = old_cardarea_emplace(self, card, location, stay_flipped)

    if gilia_random_values_enabled()
        and G
        and G.pack_cards
        and self == G.pack_cards
        and card
    then
        gilia_randomize_playing_card_from_booster(card)
    end

    return result
end

local old_game_start_run = Game.start_run

function Game:start_run(args)
    old_game_start_run(self, args)

    if gilia_random_values_enabled() then
        G.GAME.gilia_randomized_poker_hands = nil
        G.GAME.gilia_base_poker_hands = nil
        Gilia_randomize_poker_hands()
    end
end