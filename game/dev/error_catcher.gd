extends Logger
## Motor ve betik hatalarını toplar (testler ve ekransız kontroller için): OS.add_logger(preload(...).new()).
## Uyarılar sayılmaz; hata, betik hatası ve shader hatası toplanır. Logger başka iş parçacığından da çağrılabilir: kilitli.

var _lock := Mutex.new()
var _errors: Array[String] = []

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var text := rationale if rationale != "" else code
	_lock.lock()
	_errors.append("%s (%s:%d %s)" % [text, file.get_file(), line, function])
	_lock.unlock()

## Biriken hataları döndürür ve listeyi boşaltır
func take() -> Array[String]:
	_lock.lock()
	var out: Array[String] = _errors.duplicate()
	_errors.clear()
	_lock.unlock()
	return out

func count() -> int:
	_lock.lock()
	var n := _errors.size()
	_lock.unlock()
	return n
