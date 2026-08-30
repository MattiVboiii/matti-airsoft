Locale = {}
Locale.__index = Locale

local function interpolate(phrase, subs)
	if type(phrase) ~= "string" then
		return phrase
	end

	if type(subs) ~= "table" then
		return phrase
	end

	for key, value in pairs(subs) do
		phrase = phrase:gsub("%%{" .. tostring(key) .. "}", tostring(value))
	end

	return phrase
end

local function resolvePhrase(phrases, key)
	if type(phrases) ~= "table" or type(key) ~= "string" then
		return nil
	end

	local current = phrases
	for part in string.gmatch(key, "[^.]+") do
		if type(current) ~= "table" then
			return nil
		end
		current = current[part]
	end

	if type(current) == "string" then
		return current
	end

	return nil
end

function Locale:new(opts)
	opts = opts or {}
	local instance = setmetatable({}, Locale)
	instance.phrases = opts.phrases or {}
	instance.warnOnMissing = opts.warnOnMissing == true
	instance.fallbackLang = opts.fallbackLang
	return instance
end

function Locale:t(key, subs)
	local phrase = resolvePhrase(self.phrases, key)
	if phrase then
		return interpolate(phrase, subs)
	end

	if self.fallbackLang and self.fallbackLang.t then
		return self.fallbackLang:t(key, subs)
	end

	if self.warnOnMissing then
		print("^3[matti-airsoft]^7 Missing locale key: " .. tostring(key))
	end

	return key
end
