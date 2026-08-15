extends Node
## Глобальное состояние управления (мост между UI и игроком).

var move_vector := Vector2.ZERO  # джойстик
var jump_queued := false         # одиночный флаг: нажата кнопка прыжка
var attack_queued := false       # одиночный флаг: нажата кнопка удара/копания
var ui_open := false             # открыт инвентарь/крафт — игнор геймплея
var equipped := ""               # id экипированного инструмента (пусто = кулак)
