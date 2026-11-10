# Build-time helper. Requires fonttools. The app has no Python dependency.
import sys, pathlib, xml.etree.ElementTree as ET
from fontTools.pens.basePen import BasePen
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
(root/'Sources/LocalLLMManager/LuluVectorPaths.swift').write_text('\n'.join(parts)+'\n')
