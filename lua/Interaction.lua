if string.lower(RequiredScript) == "lib/units/beings/player/states/playerstandard" then
	PlayerStandard.NADE_TIMEOUT = 0.25																	--Timeout for 2 NadeKey pushes, to prevent accidents in stealth

	local _update_interaction_timers_original = PlayerStandard._update_interaction_timers
	local _check_action_interact_original = PlayerStandard._check_action_interact
	local _start_action_reload_original = PlayerStandard._start_action_reload
	local _update_reload_timers_original = PlayerStandard._update_reload_timers
	local _interupt_action_reload_original = PlayerStandard._interupt_action_reload
	local _check_action_throw_grenade_original = PlayerStandard._check_action_throw_grenade
	
	function PlayerStandard:_update_interaction_timers(t, ...)
		self:_check_interaction_locked(t)
		return _update_interaction_timers_original(self, t, ...)
	end
	
	function PlayerStandard:_check_action_interact(t, input, ...)
		if not self:_check_interact_toggle(t, input) then
			return _check_action_interact_original(self, t, input, ...)
		end
	end
	
	
	function PlayerStandard:_check_interaction_locked(t) 
		PlayerStandard.LOCK_MODE = WolfHUD:getSetting("LOCK_MODE", "number")						--Lock interaction, if MIN_TIMER_DURATION is longer then total interaction time, or current interaction time
		PlayerStandard.MIN_TIMER_DURATION = WolfHUD:getSetting("MIN_TIMER_DURATION", "number")		--Min interaction duration (in seconds) for the toggle behavior to activate	
		local is_locked = false
		if PlayerStandard.LOCK_MODE == 1 then
			is_locked = self._interact_expire_t and (t - (self._interact_expire_t - self._interact_params.timer) >= PlayerStandard.MIN_TIMER_DURATION) --lock interaction, when interacting longer then given time
		elseif PlayerStandard.LOCK_MODE == 2 then
			is_locked = self._interact_params and (self._interact_params.timer >= PlayerStandard.MIN_TIMER_DURATION) -- lock interaction, when total timer time is longer then given time
		end
		
		if self._interaction_locked ~= is_locked then
			managers.hud:set_interaction_bar_locked(is_locked)
			self._interaction_locked = is_locked
		end
	end
	
	function PlayerStandard:_check_interact_toggle(t, input)
		PlayerStandard.EQUIPMENT_PRESS_INTERRUPT = WolfHUD:getSetting("EQUIPMENT_PRESS_INTERRUPT", "boolean") 	--Use the equipment key ('G') to toggle off active interactions
		local interrupt_key_press = input.btn_interact_press
		if PlayerStandard.EQUIPMENT_PRESS_INTERRUPT then
			interrupt_key_press = input.btn_use_item_press
		end
		
		if interrupt_key_press and self:_interacting() then
			self:_interupt_action_interact()
			return true
		elseif input.btn_interact_release and self._interact_params then
			if self._interaction_locked then
				return true
			end
		end
	end
	
	function PlayerStandard:_start_action_reload(t)
		_start_action_reload_original(self, t)
		if WolfHUD:getSetting("SHOW_RELOAD", "boolean") then
			if self._equipped_unit and not self._equipped_unit:base():clip_full() and managers.player:current_state() ~= "bleed_out" then
				self._state_data._reload = true
				managers.hud:show_interaction_bar(0, self._state_data.reload_expire_t or 0)
				self._state_data.reload_offset = t
			end
		end
	end

	function PlayerStandard:_update_reload_timers(t, dt, input)
		_update_reload_timers_original(self, t, dt, input)
		if WolfHUD:getSetting("SHOW_RELOAD", "boolean") then
			if not self._state_data.reload_expire_t and self._state_data._reload then
				managers.hud:hide_interaction_bar(true)
				self._state_data._reload = false
			elseif self._state_data._reload and managers.player:current_state() ~= "bleed_out" then
				managers.hud:set_interaction_bar_width(	t and t - self._state_data.reload_offset or 0, self._state_data.reload_expire_t and self._state_data.reload_expire_t - self._state_data.reload_offset or 0 )
			end
		end
	end

	function PlayerStandard:_interupt_action_reload(t)
		local val = _interupt_action_reload_original(self, t)
		if self._state_data._reload and managers.player:current_state() ~= "bleed_out" and WolfHUD:getSetting("SHOW_RELOAD", "boolean") then
			managers.hud:hide_interaction_bar(false)
			self._state_data._reload = false
		end
		return val
	end
	
	function PlayerStandard:_check_action_throw_grenade(t, input, ...)
		if input.btn_throw_grenade_press and WolfHUD:getSetting("SUPRESS_NADES_STEALTH", "boolean") then
			if managers.groupai:state():whisper_mode() and (t - (self._last_grenade_t or 0) >= PlayerStandard.NADE_TIMEOUT) then
				self._last_grenade_t = t
				return
			end
		end
		
		return _check_action_throw_grenade_original(self, t, input, ...)
	end

elseif string.lower(RequiredScript) == "lib/units/beings/player/states/playercivilian" then

	local _update_interaction_timers_original = PlayerCivilian._update_interaction_timers
	local _check_action_interact_original = PlayerCivilian._check_action_interact
	
	function PlayerCivilian:_update_interaction_timers(t, ...)
		self:_check_interaction_locked(t)
		return _update_interaction_timers_original(self, t, ...)
	end
	
	function PlayerCivilian:_check_action_interact(t, input, ...)
		if not self:_check_interact_toggle(t, input) then
			return _check_action_interact_original(self, t, input, ...)
		end
	end
	
elseif string.lower(RequiredScript) == "lib/managers/hudmanagerpd2" then

	function HUDManager:set_interaction_bar_locked(status)
		self._hud_interaction:set_locked(status)
	end
	
elseif string.lower(RequiredScript) == "lib/managers/hud/hudinteraction" then
	local show_interaction_bar_original = HUDInteraction.show_interaction_bar
	local hide_interaction_bar_original = HUDInteraction.hide_interaction_bar
	local show_interact_original		= HUDInteraction.show_interact
	local destroy_original				= HUDInteraction.destroy
	
	local set_interaction_bar_width_original = HUDInteraction.set_interaction_bar_width
	
	function HUDInteraction:set_interaction_bar_width(current, total)
		set_interaction_bar_width_original(self, current, total)
		if HUDInteraction.SHOW_TIME_REMAINING then
			self._interact_time:set_text(string.format("%.1fs", math.max(total - current, 0)))
			local perc = current/total
			local color = perc * HUDInteraction.GRADIENT_COLOR + (1-perc) * Color.white
			self._interact_time:set_color(color)
			self._interact_time:set_alpha(1)
			self._interact_time:set_visible(perc < 1)
		end
	end
	
	
	function HUDInteraction:show_interaction_bar(current, total)
		if self._interact_circle_locked then
			self._interact_circle_locked:remove()
			self._interact_circle_locked = nil
		end
		
		local val = show_interaction_bar_original(self, current, total)
		
		HUDInteraction.SHOW_LOCK_INDICATOR = WolfHUD:getSetting("SHOW_LOCK_INDICATOR", "boolean")
		HUDInteraction.SHOW_TIME_REMAINING = WolfHUD:getSetting("SHOW_TIME_REMAINING", "boolean")
		HUDInteraction.SHOW_CIRCLE 	= WolfHUD:getSetting("SHOW_CIRCLE", "boolean")
		HUDInteraction.GRADIENT_COLOR = WolfHUD:getSetting("GRADIENT_COLOR", "color")
		if HUDInteraction.SHOW_CIRCLE then
			if PlayerStandard.LOCK_MODE < 3 and HUDInteraction.SHOW_LOCK_INDICATOR then
				self._interact_circle_locked = CircleBitmapGuiObject:new(self._hud_panel, {
					radius = self._circle_radius,
					color = Color.red,
					blend_mode = "normal",
					alpha = 0,
				})
				self._interact_circle_locked:set_position(self._hud_panel:w() / 2 - self._circle_radius, self._hud_panel:h() / 2 - self._circle_radius)
				self._interact_circle_locked:set_color(Color.red)
				self._interact_circle_locked._circle:set_render_template(Idstring("Text"))
			end
		else
			HUDInteraction.SHOW_LOCK_INDICATOR = false
			self._interact_circle:set_visible(false)
		end
		
		if HUDInteraction.SHOW_TIME_REMAINING and not self._interact_time then
			self._interact_time = self._hud_panel:text({
			name = "interaction_timer",
			visible = false,
			text = "",
			valign = "center",
			align = "center",
			layer = 1,
			color = Color.white,
			font = tweak_data.menu.default_font,
			font_size = 32,
			h = 64
			})
			
			self._interact_time:set_y(self._hud_panel:h() / 2 + 10)
			if self._interact_time then
				self._interact_time:show()
				self._interact_time:set_text(string.format("%.1fs", total))
			end
		end
		
		return val
	end
	

	function HUDInteraction:hide_interaction_bar(complete, ...)		
		if self._interact_circle_locked then
			self._interact_circle_locked:remove()
			self._interact_circle_locked = nil
		end
		
		if self._interact_time then
			self._interact_time:set_text("")
			self._interact_time:set_visible(false)
		end
		
		if not complete and self._old_text then
			self._hud_panel:child(self._child_name_text):set_text(self._old_text or self._hud_panel:child(self._child_name_text):text())
		end
		self._old_text = nil
		return hide_interaction_bar_original(self, complete and HUDInteraction.SHOW_CIRCLE, ...)
	end

	function HUDInteraction:set_locked(status)
		if self._interact_circle_locked then
			self._interact_circle_locked._circle:set_color(status and Color.green or Color.red)
			self._interact_circle_locked._circle:set_alpha(0.25)
		end
		
		if status then
			self._old_text = self._hud_panel:child(self._child_name_text):text()
			local type = managers.controller:get_default_wrapper_type()
			local interact_key  = managers.controller:get_settings(type):get_connection("interact"):get_input_name_list()[1] or "f"
			local equipment_key = managers.controller:get_settings(type):get_connection("use_item"):get_input_name_list()[1] or "g"
			local locked_text = string.upper(managers.localization:text(self._old_text:match(managers.localization:text("hud_int_disable_alarm_pager", {BTN_INTERACT = interact_key})) and "wolfhud_int_pager_locked" or "wolfhud_int_locked", {BTN = (PlayerStandard.EQUIPMENT_PRESS_INTERRUPT and equipment_key or interact_key)}))
			self._hud_panel:child(self._child_name_text):set_text(locked_text)
		end
	end
	
	function HUDInteraction:show_interact(data)
		if not self._old_text then
			return show_interact_original(self, data)
		end
	end
	
	function HUDInteraction:destroy()
		if self._interact_time and self._hud_panel then
			self._hud_panel:remove(self._interact_time)
			self._interact_time = nil
		end
		destroy_original(self)
	end
elseif string.lower(RequiredScript) == "lib/units/interactions/interactionext" then
	local _add_string_macros_original = BaseInteractionExt._add_string_macros

	function BaseInteractionExt:get_unsecured_bonus_bag_value(carry_id)
		return math.round((managers.money:get_bag_value(carry_id, 1) + math.round(managers.money:get_bag_value(carry_id, 1) * (managers.job:current_job_id() and #tweak_data.narrative.jobs[managers.job:current_job_id()].chain or 1) * managers.money:get_contract_difficulty_multiplier(managers.job:has_active_job() and managers.job:current_difficulty_stars() or 0))) * managers.player:upgrade_value("player", "secured_bags_money_multiplier", 1) / managers.money:get_tweak_value("money_manager", "offshore_rate"))
	end
	
	function BaseInteractionExt:get_real_bag_value(carry_id)
		if managers.loot:is_bonus_bag(carry_id) then
			return tweak_data:get_value("money_manager", "bag_values", carry_id) and self:get_unsecured_bonus_bag_value(carry_id) or managers.loot:get_real_value(carry_id, 1)
		else
			return 0 -- Calculate mission bag value here...
		end
	end
	
	function BaseInteractionExt:_add_string_macros(macros)
		_add_string_macros_original(self, macros)
		if self._unit:carry_data() then
			local bag_value = self:get_real_bag_value(self._unit:carry_data():carry_id())
			macros.BAG = managers.localization:text(tweak_data.carry[self._unit:carry_data():carry_id()].name_id)
			macros.VALUE = not tweak_data.carry[self._unit:carry_data():carry_id()].skip_exit_secure and bag_value > 0 and " (" .. managers.experience:cash_string(bag_value) .. ")" or ""
		end
	end

elseif string.lower(RequiredScript) == "lib/managers/objectinteractionmanager" then
	ObjectInteractionManager.AUTO_PICKUP_DELAY = 0.3 --Delay in seconds between auto-pickup procs (0 -> as fast as possible)
	local _update_targeted_original = ObjectInteractionManager._update_targeted
	function ObjectInteractionManager:_update_targeted(...)
		_update_targeted_original(self, ...)

		if alive(self._active_unit) and WolfHUD:getSetting("HOLD2PICK", "boolean") then
			local t = Application:time()
			if self._active_unit:base() and self._active_unit:base().small_loot and managers.menu:get_controller():get_input_bool("interact") and (t >= (self._next_auto_pickup_t or 0)) then
				self._next_auto_pickup_t = t + ObjectInteractionManager.AUTO_PICKUP_DELAY
				self:interact(managers.player:player_unit())
			end
		end
	end
end