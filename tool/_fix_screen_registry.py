from pathlib import Path

p = Path('apps/waddle_display/lib/extensions/screen_widget_registry.dart')
t = p.read_text(encoding='utf-8')
t = t.replace('ctx.db: ctx.db', 'db: ctx.db')
t = t.replace('ctx.blobs: ctx.blobs', 'blobs: ctx.blobs')
t = t.replace('ctx.adminBaseUrl: ctx.adminBaseUrl', 'adminBaseUrl: ctx.adminBaseUrl')
t = t.replace('ctx.instanceIdFile: ctx.instanceIdFile', 'instanceIdFile: ctx.instanceIdFile')
t = t.replace('ctx.viewerInviteRuntime: ctx.viewerInviteRuntime', 'viewerInviteRuntime: ctx.viewerInviteRuntime')
t = t.replace('theme: theme', 'theme: ctx.theme')
t = t.replace('slide: slide', 'slide: ctx.slide')
t = t.replace("import 'screens/", "import '../display/screens/")
if "case 'plugin_template'" not in t:
    t = t.replace(
        "case 'web_page':",
        "case 'plugin_template':\n"
        "              return PluginTemplateSlideWidget(\n"
        "                spec: w,\n"
        "                theme: ctx.theme,\n"
        "              );\n"
        "            case 'web_page':",
    )
p.write_text(t, encoding='utf-8')
print('fixed')
