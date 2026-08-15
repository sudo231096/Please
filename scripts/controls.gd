extends Node
## Глобальное состояние управления (мост между UI и игроком).

var move_vector := Vector2.ZERO
var jump_queued := false
var attack_queued := false
var ui_open := false
var equipped := ""               # id инструмента (пусто = кулак)
var build_mode := false          # режим строительства
var build_piece := "wood_block"  # выбранный блок для постройки
var build_rotate := 0            # 0..3 * 90°
