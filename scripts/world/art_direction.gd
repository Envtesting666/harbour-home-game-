class_name CityArtDirection
extends RefCounted
## One color authority for native models, neighborhood lighting and game UI.
## After changing WORLD, run tools/bake_architecture.gd to rebuild model scenes.

const UI_INK := Color("17334e")
const UI_MUTED := Color("526b7a")
const UI_PAPER := Color("fffaf1")
const UI_PRIMARY := Color("17665d")
const UI_PRIMARY_HOVER := Color("24786c")
const UI_ON_PRIMARY := Color("ffffff")
const UI_HOVER := Color("e7efea")
const UI_PRESSED := Color("d7e6df")
const UI_DISABLED := Color("e2e7e1")
const UI_DISABLED_TEXT := Color("6d7d88")
const UI_GOAL := Color("fff5d9")
const UI_LINE := Color("d8e0d7")
const UI_ACCENT_LIGHT := Color("ffd66b")
const UI_GOLD := Color("eeb441")
const UI_NAVY := Color("153d60")
const UI_NAVY_HOVER := Color("245981")
const UI_ALERT := Color("ac4935")
const UI_SHADOW := Color(0.04, 0.14, 0.12, 0.14)
const COVERAGE := Color(0.18, 0.46, 0.38, 0.16)
const PREVIEW := Color(0.35, 0.65, 0.56, 0.48)
const SUN_COLOR := Color("fff2dd")
const SUN_ENERGY := 0.67
const SUN_ROTATION := Vector3(-61, -32, 0)
const AMBIENT_COLOR := Color("d2e4ff")
const AMBIENT_ENERGY := 0.36

const WORLD := {
	"wall":Color("efd6a2"), "wall_warm":Color("d99770"), "trim":Color("fff3d6"),
	"roof":Color("c45a36"), "roof_dark":Color("345b85"), "glass":Color("245e79"),
	"shutter":Color("248f9b"), "metal":Color("28495b"), "wood":Color("a46b39"),
	"stone":Color("9fae9b"), "paving":Color("cfbf9e"), "water":Color("299db8"),
	"grass":Color("599e54"), "grass_light":Color("6ba95c"),
	"leaf":Color("378347"), "leaf_light":Color("69a64b"),
	"earth":Color("a58a65"), "construction":Color("d2a45d"), "ink":UI_INK,
	"skin":Color("c89b71"), "road":Color("5d7381"),
	"coral":Color("dd856a"), "butter":Color("f4ca6d"), "azure":Color("67b4c0"),
	"ivory":Color("f5e9c9"), "slate":Color("37567d"), "citrus":Color("edac36"),
	"flower_pink":Color("e7708b"), "flower_yellow":Color("f3c346"), "flower_white":Color("fff2dc")
}
