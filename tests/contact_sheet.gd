extends SceneTree
## Tiles PNGs into one sheet:  --script res://tests/contact_sheet.gd -- out=res://x.png cols=5 w=384 a.png b.png ...
func _initialize() -> void:
	var out := "res://tests/sheet.png"
	var cols := 4
	var w := 384
	var files: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		elif a.begins_with("cols="): cols = int(a.substr(5))
		elif a.begins_with("w="): w = int(a.substr(2))
		else: files.append(a)
	var h := int(w * 9 / 16)
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	for i in files.size():
		var im := Image.load_from_file(files[i])
		if im == null: continue
		im.convert(Image.FORMAT_RGB8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(out)
	print("SHEET ", out, " ", files.size())
	quit(0)
