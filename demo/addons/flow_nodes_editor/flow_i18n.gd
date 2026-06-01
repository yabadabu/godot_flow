@tool
extends RefCounted
class_name FlowI18n

static var node_translation_enabled := true

const ZH_CN := {
	"Actions": "操作",
	"Analyze": "分析",
	"Assets": "资源",
	"Attributes": "属性",
	"Auto Regen": "自动再生成",
	"Back": "返回",
	"Collapse Selected to Subgraph": "将所选折叠为子图",
	"Color Nodes": "节点着色",
	"connections": "连接",
	"Control Flow": "控制流",
	"Data Flow": "数据流",
	"Debug": "调试",
	"Density": "密度",
	"Filter": "过滤",
	"Generators": "生成器",
	"Info": "信息",
	"Input: %s": "输入：%s",
	"Inputs": "输入",
	"Inputs...": "输入...",
	"Inspect selected node raw data (A)": "检查所选节点的原始数据 (A)",
	"Math": "数学",
	"Meshes": "网格",
	"Metadata": "元数据",
	"No inputs defined": "未定义输入",
	"No outputs defined": "未定义输出",
	"nodes": "节点",
	"Open a FlowGraph resource": "打开 FlowGraph 资源",
	"Open Graph": "打开图",
	"Output: %s": "输出：%s",
	"Outputs": "输出",
	"Outputs...": "输出...",
	"Point Ops": "点操作",
	"Promote To Parameter": "提升为参数",
	"Ready": "就绪",
	"Recently Used": "最近使用",
	"Regenerate": "重新生成",
	"Reload": "重新加载",
	"Sampler": "采样器",
	"Save Resource": "保存资源",
	"Search nodes...": "搜索节点...",
	"Settings": "设置",
	"Spatial": "空间",
	"Splines": "样条",
	"Translate Nodes": "翻译节点",
	"Utility": "工具",
}

static func t(message: String) -> String:
	if _uses_simplified_chinese():
		return ZH_CN.get(message, message)
	return message

static func tn(message: String) -> String:
	if node_translation_enabled:
		return t(message)
	return message

static func trf(message: String, values: Array) -> String:
	return t(message) % values

static func count(value: int, label: String) -> String:
	if _uses_simplified_chinese():
		return "%d 个%s" % [value, t(label)]
	return "%d %s" % [value, t(label)]

static func set_node_translation_enabled(enabled: bool):
	node_translation_enabled = enabled

static func is_node_translation_enabled() -> bool:
	return node_translation_enabled

static func _uses_simplified_chinese() -> bool:
	var locale := TranslationServer.get_locale()
	if Engine.is_editor_hint():
		var editor_settings := EditorInterface.get_editor_settings()
		if editor_settings and editor_settings.has_setting("interface/editor/editor_language"):
			var editor_locale := String(editor_settings.get_setting("interface/editor/editor_language"))
			if not editor_locale.is_empty():
				locale = editor_locale
	locale = locale.to_lower().replace("-", "_")
	return locale == "zh" or locale.begins_with("zh_cn") or locale.begins_with("zh_hans") or locale.begins_with("zh_sg")
