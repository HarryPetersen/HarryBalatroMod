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

    -- path examples:
    -- ability.extra
    -- ability.max_highlighted
    -- ability.extra.mult
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(parts, part)
    end

    -- Remove the first "ability" part so ability.extra maps to config.extra.
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

    local curve_power = 1.8

    local side = pseudorandom(seed .. "_side")
    local distance = pseudorandom(seed .. "_distance") ^ curve_power

    if side < 0.5 then
        return 1 - ((1 - min) * distance)
    else
        return 1 + ((max - 1) * distance)
    end
end

local function gilia_get_min_max()
    local min = G.GAME.modifiers.gilia_random_min or 0.1
    local max = G.GAME.modifiers.gilia_random_max or 10
    return min, max
end

local function gilia_is_randomizable_set(set)
    return set == "Joker"
        or set == "Tarot"
        or set == "Planet"
        or set == "Spectral"
        or set == "Voucher"
        or set == "Booster"
end

local function gilia_should_skip_number_key(k)
    if type(k) == "string" and string.sub(k, 1, 6) == "gilia_" then
        return true
    end

    return k == "id"
        or k == "order"
        or k == "sort_id"
        or k == "card_limit"
        or k == "extra_slots_used"
        or k == "consumeable_limit"
        or k == "consumable_slots"
        or k == "joker_slots"
        or k == "slots"
        or k == "min_highlighted"
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

local function gilia_must_be_integer_key(k, center_set)
    -- Counts must stay whole numbers.
    -- Normal values like mult, chips, xmult, money, cost, etc. can keep decimals.

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
    -- Example: High Priestess can create 0 Planet cards.
    if center_set == "Tarot" or center_set == "Spectral" then
        if k == "extra" then
            return 0
        end
    end

    return 1
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

local function gilia_is_allowed_joker_key(k)
    return k == "extra"
        or k == "mult"
        or k == "chips"
        or k == "x_mult"
        or k == "xmult"
        or k == "Xmult"
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

local function gilia_randomize_numbers_in_table(t, card, center, seed_prefix, min, max, path, center_set)
    if type(t) ~= "table" then return end
    if not card then return end
    if not center then return end

    card.gilia_random_base_numbers = card.gilia_random_base_numbers or {}

    for k, v in pairs(t) do
        local current_path = path .. "." .. tostring(k)

        if type(v) == "number" then
            if not gilia_should_skip_number_key(k) then
                -- For Jokers, do NOT randomize every random number.
                -- Only randomize known effect-style keys.
                if center_set == "Joker" and not gilia_is_allowed_joker_key(k) then
                    goto continue
                end

                local base_value = gilia_get_base_from_original_config(center, current_path, nil)

                if base_value == nil then
                    if card.gilia_random_base_numbers[current_path] == nil then
                        card.gilia_random_base_numbers[current_path] = v
                    end
                    base_value = card.gilia_random_base_numbers[current_path]
                end

                local mult = gilia_random_float(seed_prefix .. "_" .. current_path, min, max)
                local new_value = base_value * mult

                new_value = gilia_clamp_randomized_value(base_value, new_value, min, max)

                if gilia_must_be_integer_key(k, center_set) then
                    local min_integer = gilia_integer_min_for_key(k, center_set)
                    new_value = math.max(min_integer, math.floor(new_value + 0.5))
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
    end

    if type(ability.choose) == "number" then
        ability.choose = math.max(1, math.floor(ability.choose + 0.5))
    end

    if type(ability.extra) == "number" and type(ability.choose) == "number" then
        ability.choose = math.min(ability.choose, ability.extra)
    end
end

function Gilia_randomize_poker_hands()
    if not gilia_random_values_enabled() then return end
    if not G.GAME.hands then return end
    if G.GAME.gilia_randomized_poker_hands then return end

    local min, max = gilia_get_min_max()
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

-- British spelling alias, in case anything else in your mod calls this version.
function Gilia_randomise_poker_hands()
    return Gilia_randomize_poker_hands()
end

local old_card_set_ability = Card.set_ability

function Card:set_ability(center, initial, delay_sprites)
    old_card_set_ability(self, center, initial, delay_sprites)

    if not gilia_random_values_enabled() then return end
    if not center or not gilia_is_randomizable_set(center.set) then return end
    if not self.ability then return end

    gilia_get_original_center_config(center)

    local center_key = tostring(center.set or "unknown_set") .. "_" .. tostring(center.key or center.name or "unknown_card")

    if self.gilia_random_center_key ~= center_key then
        self.gilia_random_center_key = center_key
        self.gilia_random_base_numbers = {}
    end

    local min, max = gilia_get_min_max()
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
    local min, max = gilia_get_min_max()
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
        local min, max = gilia_get_min_max()
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

local old_game_start_run = Game.start_run

function Game:start_run(args)
    old_game_start_run(self, args)

    if gilia_random_values_enabled() then
        G.GAME.gilia_randomized_poker_hands = nil
        G.GAME.gilia_base_poker_hands = nil
        Gilia_randomize_poker_hands()
    end
end