extends RefCounted
## Рисуем pixel-art текстуры в коде (Terraria-like).


static func tex(w: int, h: int, paint: Callable) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	paint.call(img)
	return ImageTexture.create_from_image(img)


static func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, c)


# --- ИГРОК ---
# pose: 0 = idle, 1 = walk A, 2 = walk B, 3 = attack (рука вверх)
static func player_tex(pose: int = 0) -> ImageTexture:
	return tex(16, 24, func(img: Image) -> void:
		var skin := Color(0.96, 0.76, 0.58)
		var hair := Color(0.35, 0.2, 0.1)
		var shirt := Color(0.25, 0.55, 0.85)
		var pants := Color(0.25, 0.3, 0.55)
		var boot := Color(0.25, 0.15, 0.1)
		var eye := Color(0.1, 0.1, 0.1)
		# голова
		rect(img, 4, 1, 8, 7, skin)
		rect(img, 3, 2, 10, 5, hair)
		rect(img, 4, 3, 8, 4, skin)
		rect(img, 9, 4, 2, 2, eye)  # взгляд вправо
		# тело
		rect(img, 4, 8, 8, 8, shirt)
		# руки
		rect(img, 2, 8, 2, 7, skin)  # левая
		if pose == 3:
			rect(img, 12, 3, 2, 5, skin)  # правая поднята (замах)
		else:
			rect(img, 12, 8, 2, 7, skin)
		# ноги
		if pose == 1:
			# шаг A: левая нога приподнята
			rect(img, 4, 16, 3, 4, pants)
			rect(img, 3, 20, 4, 2, boot)
			rect(img, 9, 16, 3, 6, pants)
			rect(img, 9, 21, 4, 3, boot)
		elif pose == 2:
			# шаг B: правая нога приподнята
			rect(img, 4, 16, 3, 6, pants)
			rect(img, 3, 21, 4, 3, boot)
			rect(img, 9, 16, 3, 4, pants)
			rect(img, 9, 20, 4, 2, boot)
		else:
			rect(img, 4, 16, 3, 6, pants)
			rect(img, 9, 16, 3, 6, pants)
			rect(img, 3, 21, 4, 3, boot)
			rect(img, 9, 21, 4, 3, boot)
	)


# --- РАЗБОЙНИК ---
# pose: 0 = idle, 1 = walk A, 2 = walk B, 3 = attack (нож вперёд)
static func bandit_tex(pose: int = 0) -> ImageTexture:
	return tex(16, 24, func(img: Image) -> void:
		var skin := Color(0.9, 0.7, 0.55)
		var hood := Color(0.25, 0.15, 0.12)
		var shirt := Color(0.45, 0.2, 0.15)
		var pants := Color(0.2, 0.18, 0.15)
		var boot := Color(0.15, 0.1, 0.08)
		var mask := Color(0.12, 0.12, 0.12)
		# капюшон / голова
		rect(img, 3, 1, 10, 8, hood)
		rect(img, 4, 3, 8, 5, skin)
		rect(img, 4, 5, 8, 3, mask)
		rect(img, 5, 5, 2, 1, Color(0.9, 0.9, 0.2))
		rect(img, 9, 5, 2, 1, Color(0.9, 0.9, 0.2))
		# тело
		rect(img, 4, 9, 8, 7, shirt)
		# руки
		rect(img, 2, 9, 2, 6, skin)
		if pose == 3:
			rect(img, 12, 7, 2, 5, skin)  # рука с ножом поднята
			rect(img, 13, 5, 2, 4, Color(0.7, 0.7, 0.75))  # нож вверх
		else:
			rect(img, 12, 9, 2, 6, skin)
			rect(img, 13, 11, 2, 5, Color(0.7, 0.7, 0.75))  # нож
		# пояс
		rect(img, 4, 15, 8, 1, Color(0.35, 0.25, 0.1))
		# ноги
		if pose == 1:
			rect(img, 4, 16, 3, 3, pants)
			rect(img, 3, 19, 4, 2, boot)
			rect(img, 9, 16, 3, 5, pants)
			rect(img, 9, 21, 4, 3, boot)
		elif pose == 2:
			rect(img, 4, 16, 3, 5, pants)
			rect(img, 3, 21, 4, 3, boot)
			rect(img, 9, 16, 3, 3, pants)
			rect(img, 9, 19, 4, 2, boot)
		else:
			rect(img, 4, 16, 3, 5, pants)
			rect(img, 9, 16, 3, 5, pants)
			rect(img, 3, 21, 4, 3, boot)
			rect(img, 9, 21, 4, 3, boot)
	)


# --- БОСС (гигантский разбойник) ---
# pose: 0 = idle, 1 = walk A, 2 = walk B, 3 = attack
static func boss_tex(pose: int = 0) -> ImageTexture:
	return tex(24, 36, func(img: Image) -> void:
		var skin := Color(0.85, 0.65, 0.5)
		var hood := Color(0.45, 0.12, 0.1)
		var shirt := Color(0.3, 0.16, 0.14)
		var armor := Color(0.52, 0.52, 0.58)
		var pants := Color(0.18, 0.16, 0.14)
		var boot := Color(0.12, 0.08, 0.06)
		var mask := Color(0.1, 0.1, 0.1)
		var eye := Color(0.95, 0.3, 0.15)
		# капюшон + голова
		rect(img, 5, 2, 14, 12, hood)
		rect(img, 6, 4, 12, 8, skin)
		rect(img, 6, 7, 12, 5, mask)
		rect(img, 7, 7, 3, 2, eye)
		rect(img, 14, 7, 3, 2, eye)
		# шипы/корона
		rect(img, 4, 0, 3, 3, Color(0.7, 0.6, 0.2))
		rect(img, 10, 0, 3, 3, Color(0.7, 0.6, 0.2))
		rect(img, 17, 0, 3, 3, Color(0.7, 0.6, 0.2))
		# тело + броня
		rect(img, 5, 14, 14, 12, shirt)
		rect(img, 5, 14, 14, 3, armor)
		rect(img, 3, 14, 2, 10, armor)
		rect(img, 19, 14, 2, 10, armor)
		# руки
		rect(img, 3, 14, 2, 9, skin)
		if pose == 3:
			rect(img, 19, 6, 2, 8, skin)
			rect(img, 20, 4, 3, 5, Color(0.7, 0.7, 0.75))
		else:
			rect(img, 19, 14, 2, 9, skin)
			rect(img, 20, 17, 3, 6, Color(0.7, 0.7, 0.75))
		# ноги
		if pose == 1:
			rect(img, 5, 26, 5, 5, pants)
			rect(img, 4, 31, 6, 3, boot)
			rect(img, 13, 26, 5, 8, pants)
			rect(img, 13, 33, 6, 3, boot)
		elif pose == 2:
			rect(img, 5, 26, 5, 8, pants)
			rect(img, 4, 33, 6, 3, boot)
			rect(img, 13, 26, 5, 5, pants)
			rect(img, 13, 31, 6, 3, boot)
		else:
			rect(img, 5, 26, 5, 8, pants)
			rect(img, 4, 33, 6, 3, boot)
			rect(img, 13, 26, 5, 8, pants)
			rect(img, 13, 33, 6, 3, boot)
	)


# --- МОНЕТА ---
static func coin_tex(big: bool = false) -> ImageTexture:
	var s := 12 if big else 8
	return tex(s, s, func(img: Image) -> void:
		var gold := Color(1.0, 0.8, 0.15)
		var dark := Color(0.8, 0.55, 0.05)
		var light := Color(1.0, 0.95, 0.6)
		var c := float(s) * 0.5
		for yy in range(s):
			for xx in range(s):
				var d := Vector2(xx, yy).distance_to(Vector2(c - 0.5, c - 0.5))
				if d <= c:
					img.set_pixel(xx, yy, gold if d < c - 1.0 else dark)
		rect(img, int(c) - 2, int(c) - 3, 3, 3, light)
	)


static func ground_tex() -> ImageTexture:
	return tex(16, 16, func(img: Image) -> void:
		rect(img, 0, 0, 16, 16, Color(0.35, 0.25, 0.15))
		rect(img, 0, 0, 16, 4, Color(0.25, 0.45, 0.18))
		for i in range(12):
			var x := randi() % 16
			var y := 4 + randi() % 12
			rect(img, x, y, 1, 1, Color(0.3, 0.2, 0.12))
	)


static func grass_tex() -> ImageTexture:
	return tex(16, 16, func(img: Image) -> void:
		rect(img, 0, 8, 16, 8, Color(0.28, 0.5, 0.2))
		rect(img, 0, 0, 16, 8, Color(0.32, 0.55, 0.22))
		for i in range(10):
			rect(img, randi() % 16, randi() % 8, 1, 1, Color(0.4, 0.65, 0.25))
	)


static func flag_tex() -> ImageTexture:
	return tex(16, 24, func(img: Image) -> void:
		rect(img, 2, 0, 2, 24, Color(0.4, 0.25, 0.1))
		rect(img, 4, 1, 10, 7, Color(0.2, 0.7, 0.3))
		rect(img, 5, 2, 3, 3, Color(1, 1, 0.3))
	)
