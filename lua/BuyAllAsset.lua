if string.lower(RequiredScript) == "lib/managers/missionassetsmanager" then
	function MissionAssetsManager:unlock_all_buyable_assets()
		for _, asset in ipairs(self._global.assets) do
			if self:asset_is_buyable(asset) then
				self:unlock_asset(asset.id)
			end
		end
	end
	
	function MissionAssetsManager:asset_is_buyable(asset)
		return self:asset_is_locked(asset) and (Network:is_server() and asset.can_unlock or Network:is_client() and self:get_asset_can_unlock_by_id(asset.id))
	end
	
	function MissionAssetsManager:asset_is_locked(asset)
		return asset.show and not asset.unlocked
	end
	
	function MissionAssetsManager:has_locked_assets()
		local level_id = managers.job:current_level_id()
		if not tweak_data.preplanning or not tweak_data.preplanning.locations or not tweak_data.preplanning.locations[level_id] then
			for _, asset in ipairs(self._global.assets) do
				if self:asset_is_locked(asset) then
					return true
				end
			end
		end
		return false
	end
	
	function MissionAssetsManager:has_buyable_assets()
		local level_id = managers.job:current_level_id()
		if self:is_unlock_asset_allowed() and not tweak_data.preplanning or not tweak_data.preplanning.locations or not tweak_data.preplanning.locations[level_id] then
			local asset_costs = self:get_total_assets_costs()
			if asset_costs > 0 and  asset_costs < managers.money:total() then
				return true
			end
		end
		return false
	end
	
	function MissionAssetsManager:get_total_assets_costs()
		local total_costs = 0
		for _, asset in ipairs(self._global.assets) do
			if self:asset_is_buyable(asset) then
				total_costs = total_costs + (asset.id and managers.money:get_mission_asset_cost_by_id(asset.id) or 0)
			end
		end
		return total_costs
	end
elseif string.lower(RequiredScript) == "lib/managers/menu/missionbriefinggui" then
	local create_assets_original = AssetsItem.create_assets
	local unlock_asset_by_id_original = AssetsItem.unlock_asset_by_id
	local mouse_moved_original = AssetsItem.mouse_moved
	local mouse_pressed_original = AssetsItem.mouse_pressed

	function AssetsItem:create_assets(...)
		create_assets_original(self, ...)

		self._buy_all_btn = self._panel:text({
			name = "buy_all_btn",
			text = "",
			h = tweak_data.menu.pd2_medium_font_size * 0.95,
			font_size = tweak_data.menu.pd2_medium_font_size * 0.9,
			font = tweak_data.menu.pd2_medium_font,
			color = tweak_data.screen_colors.button_stage_3,
			align = "right",
			blend_mode = "add",
			visible = managers.assets:has_locked_assets(),
		})
		
		self:update_buy_all_btn()
	end
	
	function AssetsItem:unlock_asset_by_id(...)
		unlock_asset_by_id_original(self, ...)

		self:update_buy_all_btn()
	end
	
	function AssetsItem:mouse_moved(x, y, ...)
		if alive(self._buy_all_btn) and managers.assets:has_buyable_assets() then
			if self._buy_all_btn:inside(x, y) then
				if not self._buy_all_highlighted then
					self._buy_all_highlighted = true
					self._buy_all_btn:set_color(tweak_data.screen_colors.button_stage_2)
					managers.menu_component:post_event("highlight")
				end
				return true, "link"
			elseif self._buy_all_highlighted then
				self._buy_all_highlighted = nil
				self._buy_all_btn:set_color(tweak_data.screen_colors.button_stage_3)
			end
		end

		return mouse_moved_original(self, x, y, ...)
	end
	
	function AssetsItem:mouse_pressed(button, x, y, ...)
		if alive(self._buy_all_btn) and button == Idstring("0") and self._buy_all_btn:inside(x, y) then
			managers.assets:unlock_all_buyable_assets()
			self:update_buy_all_btn()
		end

		return mouse_pressed_original(self, button, x, y, ...)
	end
	
	function AssetsItem:update_buy_all_btn()
		if alive(self._buy_all_btn) then
			if managers.assets:has_buyable_assets() then
				self._buy_all_btn:set_color(self._buy_all_highlighted and tweak_data.screen_colors.button_stage_2 or tweak_data.screen_colors.button_stage_3)
			else
				self._buy_all_btn:set_color(tweak_data.screen_color_grey)
			end
			local asset_costs = managers.assets:get_total_assets_costs()
			local text = string.format("%s (%s)", managers.localization:to_upper_text("wolfhud_buy_all_assets"), managers.experience:cash_string(asset_costs))
			self._buy_all_btn:set_text(text)
			local _, _, w, _ = self._buy_all_btn:text_rect()
			self._buy_all_btn:set_w(math.ceil(w))
			self._buy_all_btn:set_top(15)
			self._buy_all_btn:set_right(self._panel:w() - 5)
		end
	end
end