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

-- My Misprint Deck
-- Standalone implementation of Cryptid's Misprint Deck core behavior.
-- Do not run this at the same time as Cryptid's own Misprint Deck unless you want stacked effects.

MMIS = MMIS or {}
MMIS.base_values = MMIS.base_values or {}

-- Cryptid-compatible internal modifier names. The hooks below look for these.
MMIS.MIN = 0.1
MMIS.MAX = 10

-- Same core blacklist/caps as Cryptid's misprintize.lua.
MMIS.misprintize_value_blacklist = {
    perish_tally = false,
    id = false,
    suit_nominal = false,
    base_nominal = false,
    face_nominal = false,
    qty = false,
    h_x_chips = false,
    d_size = false,
    h_size = false,
    selected_d6_face = false,
    cry_hook_id = false,
    colour = false,
    suit_nominal_original = false,
    times_played = false,
    extra_slots_used = false,
    card_limit = false,
}

MMIS.misprintize_bignum_blacklist = {
    odds = false,
    cry_prob = false,
    perma_repetitions = false,
    repetitions = false,
    nominal = false,
}

MMIS.misprintize_value_cap = {
    perma_repetitions = 40,
    repetitions = 40,
}

local function has_to_big()
    return type(to_big) == "function"
end

local function b(x)
    if has_to_big() then return to_big(x) end
    return tonumber(x) or 0
end

local function n(x)
    if type(to_number) == "function" then return to_number(x) end
    return tonumber(x) or 0
end

function MMIS.is_big(v)
    if type(is_big) == "function" then return is_big(v) end
    return type(v) == "table" and v.array and v.tetrate
end

function MMIS.is_number(v)
    if type(is_number) == "function" then return is_number(v) end
    return type(v) == "number" or MMIS.is_big(v)
end

function MMIS.deep_copy(obj, seen)
    if type(copy_table) == "function" then return copy_table(obj) end
    if type(obj) ~= "table" then return obj end
    if MMIS.is_big(obj) then return obj end
    seen = seen or {}
    if seen[obj] then return seen[obj] end
    local res = {}
    seen[obj] = res
    for k, v in pairs(obj) do
        res[MMIS.deep_copy(k, seen)] = MMIS.deep_copy(v, seen)
    end
    return res
end

function MMIS.no(card, flag)
    if Card and type(Card.no) == "function" then
        return Card.no(card, flag, true)
    end
    return (card and card.ability and card.ability[flag])
        or (card and card.config and card.config.center and card.config.center[flag])
        or false
end

function MMIS.is_card_big(card)
    -- Cryptid has a whitelist/blacklist system here. For a standalone multiplayer-safe deck,
    -- keep values as normal numbers unless Talisman/another bignum mod is already handling them.
    if not card or not card.config or not card.config.center then return false end
    if card.config.center.immutable then return false end
    return false
end

function MMIS.sanity_check(val, is_big_value)
    if not Talisman then return val end
    if is_big_value then
        if not val or (type(val) == "number" and (val ~= val or val > 1e300 or val < -1e300)) then
            val = 1e300
        end
        if MMIS.is_big(val) then return val end
        if type(val) == "number" and (val > 1e100 or val < -1e100) and has_to_big() then
            return to_big(val)
        end
    end
    if not val or (type(val) == "number" and (val ~= val or val > 1e300 or val < -1e300)) then
        return 1e300
    end
    if MMIS.is_big(val) then
        if b(val) > b(1e300) then return 1e300 end
        if b(val) < b(-1e300) then return -1e300 end
        return n(val)
    end
    return val
end

function MMIS.log_random(seed, min, max)
    min = n(min)
    max = n(max)
    if min <= 0 then min = 0.01 end
    if max <= 0 then max = 1 end
    if max < min then min, max = max, min end
    math.randomseed(seed)
    local lmin = math.log(min, 2.718281828459045)
    local lmax = math.log(max, 2.718281828459045)
    local poll = math.random() * (lmax - lmin) + lmin
    return math.exp(poll)
end

function MMIS.format_number(number, fmt)
    if math.abs(n(b(number))) >= 1e300 then return number end
    return tonumber(fmt:format(n(b(number))))
end

function MMIS.calculate_misprint(initial, min, max, grow_type, pow_level)
    local grow = MMIS.log_random(pseudoseed("cry_misprint" .. G.GAME.round_resets.ante), min, max)
    local calc = b(initial)

    if not grow_type then
        calc = calc * grow
    elseif grow_type == "+" then
        calc = calc + grow
    elseif grow_type == "-" then
        calc = calc - grow
    elseif grow_type == "/" then
        calc = calc / grow
    elseif grow_type == "^" then
        calc = calc ^ grow
    end

    if b(calc) > b(-1e100) and b(calc) < b(1e100) then
        calc = n(calc)
    end
    return calc
end

function MMIS.manipulate_value(num, args, is_big_value, name)
    if args.func then
        num = args.func(num, args, is_big_value, name)
    else
        if args.min and args.max then
            local new_value = MMIS.log_random(
                pseudoseed(args.seed or ("cry_misprint" .. G.GAME.round_resets.ante)),
                args.min,
                args.max
            )
            if args.type == "+" then
                if b(num) ~= b(0) and b(num) ~= b(1) then num = b(num) + new_value end
            elseif args.type == "X" then
                if b(num) ~= b(0) and (b(num) ~= b(1) or (name ~= "x_chips" and name ~= "x_mult")) then
                    num = b(num) * new_value
                end
            elseif args.type == "^" then
                num = b(num) ^ new_value
            end
        elseif args.value then
            if args.type == "+" then
                if b(num) ~= b(0) and b(num) ~= b(1) then num = b(num) + b(args.value) end
            elseif args.type == "X" then
                if b(num) ~= b(0) and (b(num) ~= b(1) or (name ~= "x_chips" and name ~= "x_mult")) then
                    num = b(num) * b(args.value)
                end
            elseif args.type == "^" then
                num = b(num) ^ b(args.value)
            end
        end
    end

    if MMIS.misprintize_value_cap[name] and b(num) > b(MMIS.misprintize_value_cap[name]) then
        num = MMIS.misprintize_value_cap[name]
    end

    if MMIS.misprintize_bignum_blacklist[name] == false then
        return n(MMIS.sanity_check(n(num), false))
    end

    local val = MMIS.sanity_check(num, is_big_value)
    if b(val) > b(-1e100) and b(val) < b(1e100) then return n(val) end
    return val
end

function MMIS.manipulate_table(card, ref_table, ref_value, args)
    if not ref_table or not ref_table[ref_value] or ref_value == "consumeable" then return end

    for i, v in pairs(ref_table[ref_value]) do
        if MMIS.is_number(v) and MMIS.misprintize_value_blacklist[i] ~= false then
            local num = v
            if args.dont_stack then
                local base = MMIS.base_values[card.config.center.key]
                if base and (base[i .. ref_value] or (ref_value == "ability" and base[i .. "consumeable"])) then
                    num = base[i .. ref_value] or base[i .. "consumeable"]
                end
            end

            ref_table[ref_value][i] = MMIS.manipulate_value(
                num,
                args,
                args.big ~= nil and args.big or MMIS.is_card_big(card),
                i
            )
        elseif i ~= "immutable" and type(v) == "table" and not MMIS.is_big(v) and MMIS.misprintize_value_blacklist[i] ~= false then
            MMIS.manipulate_table(card, ref_table[ref_value], i, args)
        end
    end
end

function MMIS.manipulate(card, args)
    if not card or not card.config or not card.config.center or not card.ability then return end
    if MMIS.no(card, "immutable") and not (args and args.bypass_checks) then return end

    if not args then
        return MMIS.manipulate(card, {
            min = (G.GAME.modifiers.cry_misprint_min or 1),
            max = (G.GAME.modifiers.cry_misprint_max or 1),
            type = "X",
            dont_stack = true,
            no_deck_effects = true,
        })
    end

    if not args.type then args.type = "X" end
    if card.config.center.set == "Booster" then args.big = false end

    local center_key = card.config.center.key or card.config.center_key or "unknown"
    local center_config = MMIS.deep_copy(card.config.center.config or {})
    MMIS.base_values[center_key] = MMIS.base_values[center_key] or {}

    for i, v in pairs(center_config) do
        if MMIS.is_number(v) and b(v) ~= b(0) then
            MMIS.base_values[center_key][i .. "ability"] = MMIS.base_values[center_key][i .. "ability"] or v
        elseif type(v) == "table" and not MMIS.is_big(v) then
            for i2, v2 in pairs(v) do
                MMIS.base_values[center_key][i2 .. i] = MMIS.base_values[center_key][i2 .. i] or v2
            end
        end
    end

    MMIS.manipulate_table(card, card, "ability", args)
    if card.base then MMIS.manipulate_table(card, card, "base", args) end

    if G.GAME.modifiers.cry_misprint_min then
        card.misprint_cost_fac = 1 / MMIS.log_random(
            pseudoseed("cry_misprint" .. G.GAME.round_resets.ante),
            G.GAME.modifiers.cry_misprint_min,
            G.GAME.modifiers.cry_misprint_max
        )
        if card.set_cost then card:set_cost() end
    end

    local caps = card.config.center.misprintize_caps or {}
    for i, v in pairs(caps) do
        if type(v) == "table" and not MMIS.is_big(v) then
            for i2, v2 in pairs(v) do
                if card.ability[i] and card.ability[i][i2] and b(card.ability[i][i2]) > b(v2) then
                    card.ability[i][i2] = MMIS.sanity_check(v2, MMIS.is_card_big(card))
                end
            end
        elseif MMIS.is_number(v) and card.ability[i] and b(card.ability[i]) > b(v) then
            card.ability[i] = MMIS.sanity_check(v, MMIS.is_card_big(card))
        end
    end

    if card.ability.consumeable then
        for k, _ in pairs(card.ability.consumeable) do
            card.ability.consumeable[k] = MMIS.deep_copy(card.ability[k])
        end
    end

    -- Restore the center config so the next card can be misprinted from original values.
    if G.P_CENTERS and G.P_CENTERS[center_key] then
        G.P_CENTERS[center_key].config = center_config
    end

    return true
end

function MMIS.randomize_poker_hands()
    if not G or not G.GAME or not G.GAME.hands or not G.GAME.modifiers.cry_misprint_min then return end
    if G.GAME.mmis_misprinted_hands then return end

    for _, hand in pairs(G.GAME.hands) do
        hand.chips = b(MMIS.format_number(n(hand.chips) * MMIS.log_random(pseudoseed("cry_misprint"), G.GAME.modifiers.cry_misprint_min, G.GAME.modifiers.cry_misprint_max), "%.2g"))
        hand.mult = b(MMIS.format_number(n(hand.mult) * MMIS.log_random(pseudoseed("cry_misprint"), G.GAME.modifiers.cry_misprint_min, G.GAME.modifiers.cry_misprint_max), "%.2g"))
        hand.l_chips = MMIS.format_number(n(hand.l_chips) * MMIS.log_random(pseudoseed("cry_misprint"), G.GAME.modifiers.cry_misprint_min, G.GAME.modifiers.cry_misprint_max), "%.2g")
        hand.l_mult = MMIS.format_number(n(hand.l_mult) * MMIS.log_random(pseudoseed("cry_misprint"), G.GAME.modifiers.cry_misprint_min, G.GAME.modifiers.cry_misprint_max), "%.2g")
        hand.s_chips = hand.chips
        hand.s_mult = hand.mult
    end

    G.GAME.mmis_misprinted_hands = true
end

function MMIS.manipulate_existing_cards()
    if not G or not G.GAME or not G.GAME.modifiers.cry_misprint_min then return end
    local areas = { G.deck, G.hand, G.jokers, G.consumeables, G.shop_jokers, G.shop_vouchers, G.shop_booster, G.pack_cards }
    for _, area in ipairs(areas) do
        if area and area.cards then
            for _, card in ipairs(area.cards) do
                MMIS.manipulate(card)
            end
        end
    end
end

function MMIS.apply_vanilla_caps()
    if not G or not G.P_CENTERS then return end
    local immutable = {
        "j_stencil", "j_four_fingers", "j_mime", "j_ceremonial", "j_marble", "j_dusk",
        "j_raised_fist", "j_chaos", "j_hack", "j_pareidolia", "j_supernova", "j_space",
        "j_dna", "j_splash", "j_sixth_sense", "j_superposition", "j_seance", "j_riff_raff",
        "j_shortcut", "j_midas_mask", "j_luchador", "j_fortune_teller", "j_diet_cola",
        "j_mr_bones", "j_sock_and_buskin", "j_swashbuckler", "j_certificate", "j_smeared",
        "j_ring_master", "j_blueprint", "j_oops", "j_invisible", "j_brainstorm",
        "j_shoot_the_moon", "j_cartomancer", "j_astronomer", "j_burnt", "j_chicot", "j_perkeo"
    }
    for _, key in ipairs(immutable) do
        if G.P_CENTERS[key] then G.P_CENTERS[key].immutable = true end
    end

    if G.P_CENTERS.j_hanging_chad then G.P_CENTERS.j_hanging_chad.misprintize_caps = { extra = 40 } end
    if G.P_CENTERS.c_high_priestess then G.P_CENTERS.c_high_priestess.misprintize_caps = { planets = 100 } end
    if G.P_CENTERS.c_emperor then G.P_CENTERS.c_emperor.misprintize_caps = { tarots = 100 } end
    if G.P_CENTERS.c_familiar then G.P_CENTERS.c_familiar.misprintize_caps = { extra = 100 } end
    if G.P_CENTERS.c_grim then G.P_CENTERS.c_grim.misprintize_caps = { extra = 100 } end
    if G.P_CENTERS.c_incantation then G.P_CENTERS.c_incantation.misprintize_caps = { extra = 100 } end
    if G.P_CENTERS.c_immolate then G.P_CENTERS.c_immolate.misprintize_caps = { destroy = 1e300 } end
    if G.P_CENTERS.c_cryptid then G.P_CENTERS.c_cryptid.misprintize_caps = { extra = 100, max_highlighted = 100 } end
end

-- Keep card ordering stable even if base.nominal is misprinted.
if Card and Card.get_nominal then
    local get_nominal_ref = Card.get_nominal
    function Card:get_nominal(mod)
        if G and G.GAME and G.GAME.modifiers and G.GAME.modifiers.cry_misprint_min and self.base and self.config and self.config.center then
            local mult = 1
            local rank_mult = 1
            if mod == "suit" then mult = 1000000 end
            if self.ability.effect == "Stone Card" or (self.config.center.no_suit and self.config.center.no_rank) then
                mult = -10000
            elseif self.config.center.no_suit then
                mult = 0
            elseif self.config.center.no_rank then
                rank_mult = 0
            end
            return 10 * (self.base.id or 0.1) * rank_mult
                + self.base.suit_nominal * mult
                + (self.base.suit_nominal_original or 0) * 0.0001 * mult
                + 10 * self.base.face_nominal * rank_mult
                + 0.000001 * self.unique_val
        end
        return n(get_nominal_ref(self, mod))
    end
end

-- Apply fractional misprint prices after Balatro's normal Card:set_cost.
if Card and Card.set_cost then
    local set_cost_ref = Card.set_cost
    function Card:set_cost()
        set_cost_ref(self)
        if self.misprint_cost_fac then
            self.cost = MMIS.format_number(self.cost * self.misprint_cost_fac, "%.2f")
            if not (G and G.GAME and G.GAME.modifiers and G.GAME.modifiers.cry_misprint_min) then
                self.cost = math.floor(self.cost)
            end
            self.sell_cost = math.max(1, math.floor(self.cost / 2)) + (self.ability.extra_value or 0)
            self.sell_cost_label = self.facing == "back" and "?" or self.sell_cost
        end
    end
end

-- Create-card hook: this is the main place Cryptid applies misprinting to newly created cards.
if type(create_card) == "function" then
    local create_card_ref = create_card
    function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
        local card = create_card_ref(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
        if G and G.GAME and G.GAME.modifiers and G.GAME.modifiers.cry_misprint_min then
            if not (card.edition and (card.edition.cry_oversat or card.edition.cry_glitched)) then
                MMIS.manipulate(card)
            end
        end
        return card
    end
end

-- Extra safety: some shop objects are created outside create_card in certain versions/mod setups.
if type(create_shop_card_ui) == "function" then
    local create_shop_card_ui_ref = create_shop_card_ui
    function create_shop_card_ui(card, card_type, area)
        if G and G.GAME and G.GAME.modifiers and G.GAME.modifiers.cry_misprint_min then
            MMIS.manipulate(card)
        end
        return create_shop_card_ui_ref(card, card_type, area)
    end
end

-- Initialise run fields and randomize poker hands once the run is live.
if Game and Game.init_game_object then
    local init_game_object_ref = Game.init_game_object
    function Game:init_game_object()
        local g = init_game_object_ref(self)
        g.events = g.events or {}
        g.cry_shop_joker_price_modifier = g.cry_shop_joker_price_modifier or 1
        return g
    end
end

if Game and Game.start_run then
    local start_run_ref = Game.start_run
    function Game:start_run(args)
        start_run_ref(self, args)
        MMIS.apply_vanilla_caps()
        MMIS.randomize_poker_hands()
        MMIS.manipulate_existing_cards()
    end
end

if SMODS and SMODS.injectItems then
    local inject_items_ref = SMODS.injectItems
    function SMODS.injectItems(...)
        inject_items_ref(...)
        MMIS.apply_vanilla_caps()
    end
end

SMODS.Back({
    key = "random_values",
    atlas = "random_values",
    loc_txt = {
        name = "Random Valuees Deck",
        text = {
            "Randomizes most numeric values",
            "between {C:attention}#1#x{} and {C:attention}#2#x{}",
        },
    },
    config = {
        cry_misprint_min = MMIS.MIN,
        cry_misprint_max = MMIS.MAX,
    },
    loc_vars = function(self, info_queue, card)
        return { vars = { self.config.cry_misprint_min, self.config.cry_misprint_max } }
    end,
    -- Add your own atlas/pos here later. Leaving them out should use Steamodded's fallback art.
    unlocked = true,
    discovered = true,
    apply = function(self)
        G.GAME.modifiers.cry_misprint_min = (G.GAME.modifiers.cry_misprint_min or 1) * self.config.cry_misprint_min
        G.GAME.modifiers.cry_misprint_max = (G.GAME.modifiers.cry_misprint_max or 1) * self.config.cry_misprint_max
    end,
})
