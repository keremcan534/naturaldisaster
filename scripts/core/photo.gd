extends RefCounted
## Photo mode: grabs the next frame drawn (the caller hides the HUD first) and
## saves it as a PNG: a download in the browser, user://photos/ elsewhere.


static func capture(viewport: Viewport) -> bool:
	# One frame for the hidden HUD to take effect, one to read back.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var file := "dogal-afet-%s.png" % stamp
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(image.save_png_to_buffer(), file, "image/png")
		return true
	DirAccess.make_dir_recursive_absolute("user://photos")
	return image.save_png("user://photos/" + file) == OK
