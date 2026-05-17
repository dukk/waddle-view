from pathlib import Path

src = Path('apps/waddle_display/lib/display/screen_rotator.dart').read_text(encoding='utf-8')
start = src.index('          switch (w.type) {')
end = src.index('        }).toList(),', start)
switch = src[start:end]
header = Path('tool/_screen_registry_header.dart').read_text(encoding='utf-8')
footer = '\n  }\n}\n'
body = switch
replacements = [
    ('theme.', 'ctx.theme.'),
    ('slide.', 'ctx.slide.'),
    ('db:', 'ctx.db:'),
    ('db,', 'ctx.db,'),
    ('blobs:', 'ctx.blobs:'),
    ('blobs,', 'ctx.blobs,'),
    ('localRestBaseUrl', 'ctx.localRestBaseUrl'),
    ('adminBaseUrl', 'ctx.adminBaseUrl'),
    ('instanceIdFile', 'ctx.instanceIdFile'),
    ('viewerInviteRuntime', 'ctx.viewerInviteRuntime'),
    ('allowVideoPlayback', 'ctx.allowVideoPlayback'),
    ('onReportDesiredDwell(slideIndex,', 'ctx.onReportDesiredDwell(ctx.slideIndex,'),
    ('bottom: gap', 'bottom: ctx.gap'),
    ('spec: w', 'spec: w'),
]
for a, b in replacements:
    body = body.replace(a, b)
# fix double ctx
body = body.replace('ctx.ctx.', 'ctx.')
out = header + body + footer
Path('apps/waddle_display/lib/extensions/screen_widget_registry.dart').write_text(out, encoding='utf-8')
print('ok', len(out))
