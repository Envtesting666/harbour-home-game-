class_name CityLocale
extends RefCounted
## Stable message sources; English is the default. Locale is a preference, not save state.

static var language := "en"
static var messages: Dictionary = {}
static var reverse: Dictionary = {}

static func set_language(value: String) -> void:
	language = value if value in ["en", "tr"] else "en"
	if messages.is_empty():
		var file := FileAccess.open("res://data/localization.json", FileAccess.READ)
		if file != null:
			messages = JSON.parse_string(file.get_as_text())
			for source: String in messages:
				if not reverse.has(str(messages[source])):
					reverse[str(messages[source])] = source

static func t(source: String) -> String:
	if messages.is_empty():
		set_language(language)
	return str(messages.get(source, source)) if language == "en" else str(reverse.get(source, source))

static func f(source: String, args: Array) -> String:
	return t(source).format(args)

static func money(amount: int) -> String:
	var digits := str(absi(amount))
	var formatted := ""
	var separator := "," if language == "en" else "."
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			formatted += separator
		formatted += digits[i]
	return ("-" if amount < 0 else "") + ("$" + formatted if language == "en" else formatted + " $")

static func compact_duration(seconds: int) -> String:
	var minute := "m" if language == "en" else "dk"
	var second := "s" if language == "en" else "sn"
	if seconds < 60: return str(seconds) + second
	return str(int(seconds / 60)) + minute + (str(seconds % 60) + second if seconds % 60 > 0 else "")
