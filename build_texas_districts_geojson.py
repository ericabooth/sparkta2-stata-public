#!/usr/bin/env python3
"""Build texas_districts.geojson from the NCES EDGE SY24-25 shapefile.

Output: texas_districts.geojson next to this script.

Key correctness notes (learned the hard way):
  - d3-geo uses ESRI/shapefile winding convention for outer rings:
    OUTER = clockwise (negative signed area), HOLE = counterclockwise.
    KEEP the shapefile's winding as-is — do NOT reverse rings to match
    RFC 7946 (which says outer=CCW). d3 will render CCW outer rings as
    "the whole world minus this hole" and paint a giant rectangle.
  - Drop tiny degenerate polygons (signed-area below MIN_AREA ≈ 1 km²).
    They cause d3-geo to inject world-clip rectangles into the path output.
  - Holes follow their parent outer in the shapefile's ring sequence;
    group them into the same GeoJSON polygon.

Run (the shapefile is the NCES EDGE school-district boundary file,
EDGE_SCHOOLDISTRICT_TL25_SY2425.shp, downloadable from nces.ed.gov/programs/edge):
  python3 build_texas_districts_geojson.py /path/to/EDGE_SCHOOLDISTRICT_TL25_SY2425.shp
or set SPARKTA2_NCES_SHP to that path.
"""
import shapefile, json, math, os, sys

SHP = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("SPARKTA2_NCES_SHP", "")
if not SHP or not os.path.exists(SHP):
    sys.exit("Give the NCES EDGE school-district .shp path as the first argument "
             "or in SPARKTA2_NCES_SHP.")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "texas_districts.geojson")

EPS      = 0.003   # Douglas-Peucker tolerance in degrees (~330m)
MIN_AREA = 1e-3   # drop polygons smaller than ~1 km^2 (avoids d3-geo clip bugs)


def perp_dist(p, p1, p2):
    if p1 == p2:
        return math.hypot(p[0]-p1[0], p[1]-p1[1])
    dx, dy = p2[0]-p1[0], p2[1]-p1[1]
    return abs(dy*p[0] - dx*p[1] + p2[0]*p1[1] - p2[1]*p1[0]) / math.hypot(dx, dy)


def dp(points, eps):
    if len(points) < 3:
        return points
    dmax, idx = 0, 0
    for i in range(1, len(points)-1):
        d = perp_dist(points[i], points[0], points[-1])
        if d > dmax:
            idx, dmax = i, d
    if dmax > eps:
        return dp(points[:idx+1], eps)[:-1] + dp(points[idx:], eps)
    return [points[0], points[-1]]


def signed_area(ring):
    s = 0
    for i in range(len(ring) - 1):
        x1, y1 = ring[i]
        x2, y2 = ring[i+1]
        s += (x1 * y2 - x2 * y1)
    return s / 2


def main():
    r = shapefile.Reader(SHP)
    fields = [f[0] for f in r.fields if f[0] != 'DeletionFlag']
    fi = lambda n: fields.index(n)

    features = []
    n_drop_small = 0
    total_in = total_out = 0
    for sr in r.iterShapeRecords():
        rec = sr.record
        if rec[fi('STATEFP')] != '48':
            continue
        shape = sr.shape
        parts = list(shape.parts) + [len(shape.points)]
        pts = shape.points
        total_in += len(pts)
        raw_rings = []
        for j in range(len(shape.parts)):
            ring = [(round(p[0],4), round(p[1],4)) for p in pts[parts[j]:parts[j+1]]]
            ring = dp(ring, EPS)
            if len(ring) >= 4:
                raw_rings.append([list(p) for p in ring])
        if not raw_rings:
            continue

        # Group by outer ring (CW, negative signed area); holes (CCW, positive)
        # follow their parent outer in the shapefile sequence.  KEEP winding.
        polygons = []
        current = None
        for ring in raw_rings:
            a = signed_area(ring)
            if abs(a) < MIN_AREA:
                n_drop_small += 1
                continue
            if a < 0:
                current = [ring]
                polygons.append(current)
            else:
                if current is None:
                    # orphan hole -> reverse to outer
                    current = [list(reversed(ring))]
                    polygons.append(current)
                else:
                    current.append(ring)
        if not polygons:
            continue

        total_out += sum(sum(len(r) for r in p) for p in polygons)
        features.append({
            "type":"Feature",
            "id": rec[fi('GEOID')],
            "geometry": {"type":"MultiPolygon", "coordinates": polygons},
            "properties": {
                "name":     rec[fi('NAME')],
                "geoid":    rec[fi('GEOID')],
                "sdtyp":    rec[fi('SDTYP')],
                "intptlat": float(rec[fi('INTPTLAT')]),
                "intptlon": float(rec[fi('INTPTLON')]),
            }
        })

    gj = {"type":"FeatureCollection", "features": features}
    with open(OUT, 'w') as f:
        json.dump(gj, f, separators=(',', ':'))
    print(f"Features:           {len(features)}")
    print(f"Degenerate dropped: {n_drop_small}")
    print(f"Vertices in/out:    {total_in:,} / {total_out:,}")
    print(f"Output:             {OUT}")
    print(f"Size:               {os.path.getsize(OUT)/1024:.1f} KB")


if __name__ == "__main__":
    main()
