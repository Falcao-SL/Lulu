# Build-time helper. Requires fonttools. The app has no Python dependency.
import sys, pathlib, xml.etree.ElementTree as ET
from fontTools.pens.basePen import BasePen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.svgLib.path import parse_path
root=pathlib.Path(__file__).resolve().parent.parent
def point(p): return f'CGPoint(x: {p[0]:.6f}, y: {p[1]:.6f})'
class Pen(BasePen):
 def __init__(self): super().__init__(None); self.lines=[]
 def _moveTo(self,p): self.lines.append(f'p.move(to: {point(p)})')
 def _lineTo(self,p): self.lines.append(f'p.addLine(to: {point(p)})')
 def _curveToOne(self,a,b,c): self.lines.append(f'p.addCurve(to: {point(c)}, control1: {point(a)}, control2: {point(b)})')
 def _qCurveToOne(self,a,b): self.lines.append(f'p.addQuadCurve(to: {point(b)}, control: {point(a)})')
 def _closePath(self): self.lines.append('p.closeSubpath()')
 def _endPath(self): pass
parts=['// Generated from the vendored Lucide SVGs. See ThirdParty/Lucide/LICENSE.','import SwiftUI','','enum LuluVectorPaths {','    static let all: [String: Path] = [']
for file in sorted((root/'ThirdParty/Lucide').glob('*.svg')):
 pen=Pen()
 for e in ET.parse(file).getroot():
  tag=e.tag.split('}')[-1]; a=e.attrib
  if tag=='path':parse_path(a['d'],pen)
  elif tag=='circle':
   x,y,r=[float(a[k]) for k in ['cx','cy','r']];pen.lines.append(f'p.addEllipse(in: CGRect(x: {x-r}, y: {y-r}, width: {2*r}, height: {2*r}))')
  elif tag=='rect':
   x,y,w,h=[float(a.get(k,0)) for k in ['x','y','width','height']];r=float(a.get('rx',0));pen.lines.append(f'p.addRoundedRect(in: CGRect(x: {x}, y: {y}, width: {w}, height: {h}), cornerSize: CGSize(width: {r}, height: {r}))')
  elif tag=='line':pen._moveTo((float(a['x1']),float(a['y1'])));pen._lineTo((float(a['x2']),float(a['y2'])))
  elif tag in ('polyline','polygon'):
   pts=a['points'].replace(',',' ').split(); coords=list(zip(map(float,pts[::2]),map(float,pts[1::2])));pen._moveTo(coords[0])
   for pt in coords[1:]:pen._lineTo(pt)
   if tag=='polygon':pen._closePath()
  else:raise ValueError(tag)
 parts+=['        "'+file.stem+'": {','            var p = Path()']+['            '+line for line in pen.lines]+['            return p','        }(),']
parts+=['    ]','}']
(root/'Sources/LocalLLMManager/Shared/DesignSystem/LuluVectorPaths.swift').write_text('\n'.join(parts)+'\n')

# The Affinity export has one group with a uniform scale and translation.
# Both renderers fit the group's visible bounds, so they can use its local coordinates.
svg = ET.parse(root / 'docs/assets/icon.svg').getroot()
ns = {'svg': 'http://www.w3.org/2000/svg'}
group = svg.find('svg:g', ns)
layers = group.findall('svg:path', ns)
assert len(layers) == len(group) and layers
colors = {'fill:rgb(20,66,54);': 'ink', 'fill:rgb(235,250,246);': 'ivory'}
bounds = BoundsPen(None)
for layer in layers:
    parse_path(layer.attrib['d'], bounds)
x0, y0, x1, y1 = bounds.bounds
w, h = x1 - x0, y1 - y0

parts = [
    '// Generated from docs/assets/icon.svg by Scripts/generate-icons.py.',
    'import CoreGraphics',
    '',
    'enum CatGeometry {',
    '    enum Tone { case ink, ivory }',
    '',
    f'    private static let bounds = CGRect(x: {x0:.6f}, y: {y0:.6f}, width: {w:.6f}, height: {h:.6f})',
    '',
    '    static func transform(in rect: CGRect) -> CGAffineTransform {',
    '        let scale = min(rect.width / bounds.width, rect.height / bounds.height)',
    '        return CGAffineTransform(translationX: rect.midX, y: rect.midY)',
    '            .scaledBy(x: scale, y: scale)',
    '            .translatedBy(x: -bounds.midX, y: -bounds.midY)',
    '    }',
    '',
    '    static let layers: [(tone: Tone, path: CGPath)] = [',
]
for layer in layers:
    tone = colors[layer.attrib['style']]
    data = layer.attrib['d']
    pen = Pen()
    parse_path(data, pen)
    parts += [f'        (.{tone}, {{', '            let p = CGMutablePath()']
    parts += ['            ' + line for line in pen.lines]
    parts += ['            return p', '        }()),']
parts += ['    ]', '}']
(root/'Sources/LocalLLMManager/Shared/DesignSystem/CatGeometry.swift').write_text('\n'.join(parts)+'\n')

hex_colors = {'ink': '#144236', 'ivory': '#ebfaf6'}
tray = ET.parse(root / 'docs/assets/icon-tray.svg').getroot()
paths = tray.findall('svg:path', ns)
parts = [
    '// Generated from docs/assets/icon-tray.svg and docs/assets/icon.svg by Scripts/generate-icons.py.',
    'enum WebChatBrand {',
    '    static let symbol = #"""',
    f'    <symbol id="icon-cat" viewBox="{tray.attrib["viewBox"]}">',
]
parts += [f'        <path d="{path.attrib["d"]}"/>' for path in paths]
parts += [
    '    </symbol>',
    f'    <symbol id="icon-cat-emblem" viewBox="{x0:.6f} {y0:.6f} {w:.6f} {h:.6f}" fill-rule="evenodd">',
]
for layer in layers:
    fill = hex_colors[colors[layer.attrib['style']]]
    parts.append(f'        <path d="{layer.attrib["d"]}" fill="{fill}"/>')
parts += ['    </symbol>', '    """#', '}']
(root/'Sources/LocalLLMManager/Features/Chat/WebChatBrand.swift').write_text('\n'.join(parts)+'\n')
