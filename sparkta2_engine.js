/* sparkta2_engine.js -- D3 choropleth + bivariate + hexbin + points map engine
   Builds on:
     https://observablehq.com/@d3/bivariate-choropleth
     https://observablehq.com/@mbostock/methods-of-comparison-compared
     https://observablehq.com/@d3/zoom-to-bounding-box
     https://d3-graph-gallery.com/graph/hexbinmap_geo_label.html
     https://d3-graph-gallery.com/graph/backgroundmap_country.html

   Features:
     - Choropleth / bivariate / diff / ratio modes
     - Hexbin aggregation over centroids or lat/lon points
     - Point (graduated-symbol) maps for lat/lon data
     - Background-map style: faded states/nation outline behind features
     - Categorical filter dropdowns, dual-handle range sliders
     - Pan/zoom, click-to-zoom, dblclick reset
     - In-browser county/ZIP-name search
     - Auto-zoom to a FIPS subset on load
     - Tooltip data table from arbitrary Stata vars
     - Swap-axes button
     - Export menu: PNG, SVG, CSV download + view-data table + print-to-PDF
     - Animate-on-view (IntersectionObserver-gated fade-in)
     - Small-multiples mode
*/
(function () {
  "use strict";

  var BIV3 = {
    rdbu: ["#e8e8e8","#e4acac","#c85a5a","#b0d5df","#ad9ea5","#985356","#64acbe","#627f8c","#574249"],
    bupu: ["#e8e8e8","#ace4e4","#5ac8c8","#dfb0d6","#a5add3","#5698b9","#be64ac","#8c62aa","#3b4994"],
    gnbu: ["#e8e8e8","#b5c0da","#6c83b5","#b8d6be","#90b2b3","#567994","#73ae80","#5a9178","#2a5a5b"],
    puor: ["#e8e8e8","#e4d9ac","#c8b35a","#cbb8d7","#c8ada0","#af8e53","#9972af","#976b82","#804d36"]
  };

  function seqScheme(name, k) {
    k = k || 7;
    var map = {
      blues: d3.schemeBlues, reds: d3.schemeReds, greens: d3.schemeGreens,
      oranges: d3.schemeOranges, purples: d3.schemePurples, greys: d3.schemeGreys
    };
    if (map[name] && map[name][k]) return map[name][k];
    if (name === "viridis") return d3.range(k).map(function (i) { return d3.interpolateViridis(i / (k - 1)); });
    if (name === "magma")   return d3.range(k).map(function (i) { return d3.interpolateMagma(i / (k - 1)); });
    if (name === "inferno") return d3.range(k).map(function (i) { return d3.interpolateInferno(i / (k - 1)); });
    if (name === "plasma")  return d3.range(k).map(function (i) { return d3.interpolatePlasma(i / (k - 1)); });
    if (name === "cividis") return d3.range(k).map(function (i) { return d3.interpolateCividis(i / (k - 1)); });
    return d3.schemeBlues[k];
  }

  function divScheme(name, k) {
    k = k || 9;
    if (name === "brbg")   return d3.range(k).map(function (i) { return d3.interpolateBrBG(i / (k - 1)); });
    if (name === "puor")   return d3.range(k).map(function (i) { return d3.interpolatePuOr(i / (k - 1)); });
    if (name === "rdylbu") return d3.range(k).map(function (i) { return d3.interpolateRdYlBu(i / (k - 1)); });
    return d3.range(k).map(function (i) { return d3.interpolateRdBu(1 - i / (k - 1)); });
  }

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;")
      .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }
  function fmt(v) {
    if (v == null || !Number.isFinite(+v)) return "N/A";
    var n = +v;
    return Math.abs(n) >= 1000 ? d3.format(",.0f")(n) : d3.format(",.2f")(n);
  }
  function padId(id, width) {
    if (id == null) return "";
    var s = String(id);
    width = width || 5;
    while (s.length < width) s = "0" + s;
    return s;
  }
  function binLabel(scale, idx) {
    var q = scale.quantiles();
    if (!q || !q.length) return "";
    if (idx === 0) return "< " + fmt(q[0]);
    if (idx === q.length) return "≥ " + fmt(q[q.length - 1]);
    return fmt(q[idx - 1]) + " – " + fmt(q[idx]);
  }
  function modeNice(m, meta) {
    if (m === "bivariate") return "Bivariate";
    if (m === "x")         return meta.xlabel || meta.xvar || "X";
    if (m === "y")         return meta.ylabel || meta.yvar || "Y";
    if (m === "diff")      return (meta.ylabel || meta.yvar || "Y") + " − " + (meta.xlabel || meta.xvar || "X");
    if (m === "ratio")     return (meta.ylabel || meta.yvar || "Y") + " / " + (meta.xlabel || meta.xvar || "X");
    return m;
  }

  // ---- Main render -------------------------------------------------------
  function render(cfg) {
    var meta = cfg.meta || {};
    var data = cfg.data || [];
    var ctrl = cfg.controls || { filters: [], sliders: [], tooltipvars: [] };
    var topo = cfg.topo;

    if (!ctrl.tooltipvars) ctrl.tooltipvars = [];

    var nBins = Math.max(2, Math.min(5, +meta.bins || 3));
    var biv = BIV3[(meta.scheme || "rdbu").toLowerCase()] || BIV3.rdbu;
    if (biv.length !== 9) biv = BIV3.rdbu;

    var idwidth = +meta.idwidth || 5;
    var renderType = (meta.type || "bivariate").toLowerCase();
    // renderType ∈ {bivariate, choropleth, hexbin, points}

    var hasYvar = !!meta.yvar;
    var hasLatLon = !!(meta.latvar && meta.lonvar);
    var hexRadius = +meta.hexradius || 18;
    var hexStat = (meta.hexstat || "mean").toLowerCase();
    var pointSize = +meta.pointsize || 4;
    var basemap = !!meta.basemap;

    var allowedModes = (meta.modes || "x").split("|").filter(Boolean);
    if (!hasYvar) allowedModes = allowedModes.filter(function (m) { return m === "x"; });
    if (!allowedModes.length) allowedModes = hasYvar ? ["bivariate"] : ["x"];

    var state = {
      mode: (meta.mode || allowedModes[0] || "x").toLowerCase(),
      swap: false,
      filters: {},
      sliders: {},
      search: "",
      multiples: !!meta.multiples && allowedModes.length > 1
    };
    if (!hasYvar) state.mode = "x";
    if (allowedModes.indexOf(state.mode) < 0) state.mode = allowedModes[0];

    ctrl.filters.forEach(function (f) { state.filters[f.var] = "__all__"; });
    ctrl.sliders.forEach(function (s) { state.sliders[s.var] = [s.min, s.max]; });

    // ---- Pick topojson layer (with GeoJSON FeatureCollection fallback) ---
    // The bundled texas_counties topojson exposes objects {counties, states,
    // nation}.  For custom geographies the file may be either a TopoJSON
    // (with .objects) or a GeoJSON FeatureCollection (with .features).
    var isGeoJSON = (topo.type === "FeatureCollection");
    var layerName = meta.layer || "";
    var features = [];
    if (isGeoJSON) {
      features = topo.features || [];
    } else {
      if (!layerName) {
        if (topo.objects.counties)      layerName = "counties";
        else if (topo.objects.districts) layerName = "districts";
        else if (topo.objects.zctas)     layerName = "zctas";
        else if (topo.objects.tracts)    layerName = "tracts";
        else                              layerName = Object.keys(topo.objects)[0];
      }
      features = topo.objects[layerName]
        ? topojson.feature(topo, topo.objects[layerName]).features
        : [];
    }

    // Reference layers for basemap — only meaningful for TopoJSON inputs.
    var basemapFeatures = [];
    if (basemap && !isGeoJSON) {
      if (topo.objects.states && layerName !== "states") {
        basemapFeatures = topojson.feature(topo, topo.objects.states).features;
      }
      else if (topo.objects.nation && layerName !== "nation") {
        basemapFeatures = topojson.feature(topo, topo.objects.nation).features;
      }
    }

    var index = d3.index(data, function (d) { return padId(d.id, idwidth); });

    var fullW  = +meta.width  || 980;
    var fullH  = +meta.height || 720;

    function passes(row) {
      if (!row) return false;
      for (var k in state.filters) {
        var sel = state.filters[k];
        if (sel !== "__all__" && (row["f__" + k] || "") !== sel) return false;
      }
      for (var s in state.sliders) {
        var range = state.sliders[s];
        var v = row["s__" + s];
        if (v == null) continue;
        if (+v < range[0] || +v > range[1]) return false;
      }
      if (state.search) {
        var nm = (row.name || "").toLowerCase();
        if (nm.indexOf(state.search) < 0) return false;
      }
      return true;
    }

    function buildPalette(modeForPanel) {
      var activeRows = data.filter(passes);
      if (!activeRows.length) activeRows = data;

      var xVar = state.swap ? "y" : "x";
      var yVar = state.swap ? "x" : "y";
      var xVals = activeRows.map(function (d) { return +d[xVar]; }).filter(Number.isFinite);
      var yVals = hasYvar ? activeRows.map(function (d) { return +d[yVar]; }).filter(Number.isFinite) : [];

      var xLab = state.swap ? (meta.ylabel || meta.yvar || "Y") : (meta.xlabel || meta.xvar || "X");
      var yLab = state.swap ? (meta.xlabel || meta.xvar || "X") : (meta.ylabel || meta.yvar || "Y");

      var palette = {
        mode: modeForPanel,
        xLab: xLab, yLab: yLab,
        xVar: xVar, yVar: yVar,
        xVals: xVals, yVals: yVals
      };

      if (modeForPanel === "bivariate") {
        palette.xScale = d3.scaleQuantile(xVals, d3.range(nBins));
        palette.yScale = d3.scaleQuantile(yVals, d3.range(nBins));
        palette.colorFn = function (row) {
          if (!row || !Number.isFinite(+row[xVar]) || !Number.isFinite(+row[yVar])) return "#ccc";
          return biv[palette.yScale(+row[yVar]) + palette.xScale(+row[xVar]) * nBins];
        };
      }
      else if (modeForPanel === "x" || modeForPanel === "y") {
        var v = modeForPanel === "x" ? xVar : yVar;
        var vals = modeForPanel === "x" ? xVals : yVals;
        var seq = seqScheme((meta.scheme || "blues").toLowerCase(), 7);
        if (!Array.isArray(seq) || seq.length < 5) seq = d3.schemeBlues[7];
        palette.scale = d3.scaleQuantile(vals, seq);
        palette.colorFn = function (row) {
          if (!row || !Number.isFinite(+row[v])) return "#ccc";
          return palette.scale(+row[v]);
        };
        palette.varLabel = modeForPanel === "x" ? xLab : yLab;
      }
      else if (modeForPanel === "diff") {
        var xRank = d3.scaleLinear().domain(d3.extent(xVals)).range([0, 1]);
        var yRank = d3.scaleLinear().domain(d3.extent(yVals)).range([0, 1]);
        var diffs = activeRows.map(function (d) {
          var xv = +d[xVar], yv = +d[yVar];
          if (!Number.isFinite(xv) || !Number.isFinite(yv)) return NaN;
          return meta.comparable ? (yv - xv) : (yRank(yv) - xRank(xv));
        }).filter(Number.isFinite);
        var ext = d3.extent(diffs);
        var absMax = Math.max(Math.abs(ext[0] || 0), Math.abs(ext[1] || 0)) || 1;
        var divColors = divScheme((meta.scheme || "rdbu").toLowerCase(), 9);
        palette.diffScale = d3.scaleQuantize().domain([-absMax, absMax]).range(divColors);
        palette.colorFn = function (row) {
          if (!row || !Number.isFinite(+row[xVar]) || !Number.isFinite(+row[yVar])) return "#ccc";
          var dv = meta.comparable
            ? (+row[yVar] - +row[xVar])
            : (yRank(+row[yVar]) - xRank(+row[xVar]));
          return palette.diffScale(dv);
        };
        palette.diffExtent = [-absMax, absMax];
        palette.comparable = !!meta.comparable;
        palette.xRank = xRank;
        palette.yRank = yRank;
      }
      else if (modeForPanel === "ratio") {
        var ratios = activeRows.map(function (d) {
          var xv = +d[xVar], yv = +d[yVar];
          if (!Number.isFinite(xv) || !Number.isFinite(yv) || xv === 0) return NaN;
          return yv / xv;
        }).filter(function (v) { return Number.isFinite(v) && v > 0; });
        var logRatios = ratios.map(function (r) { return Math.log(r); });
        var ext2 = d3.extent(logRatios);
        var absMax2 = Math.max(Math.abs(ext2[0] || 0), Math.abs(ext2[1] || 0)) || 1;
        var divColors2 = divScheme((meta.scheme || "rdbu").toLowerCase(), 9);
        palette.ratioScale = d3.scaleQuantize().domain([-absMax2, absMax2]).range(divColors2);
        palette.colorFn = function (row) {
          if (!row) return "#ccc";
          var xv = +row[xVar], yv = +row[yVar];
          if (!Number.isFinite(xv) || !Number.isFinite(yv) || xv === 0) return "#ccc";
          return palette.ratioScale(Math.log(yv / xv));
        };
        palette.ratioExtent = [Math.exp(-absMax2), Math.exp(absMax2)];
      }

      return palette;
    }

    var tooltip = d3.select("#tooltip");
    function showTip(html, ev) {
      tooltip.style("opacity", 1).html(html)
        .style("left", (ev.pageX + 14) + "px")
        .style("top",  (ev.pageY - 28) + "px");
    }
    function hideTip() { tooltip.style("opacity", 0); }

    function tipHTML(row, name, palette) {
      if (!row) return "<strong>" + esc(name) + "</strong><br/><span style='color:#94a3b8'>no data</span>";
      var lines = ["<strong>" + esc(name) + "</strong>"];
      var xv = +row[palette.xVar], yv = hasYvar ? +row[palette.yVar] : null;
      if (palette.mode === "bivariate") {
        var xi = palette.xScale(xv), yi = palette.yScale(yv);
        lines.push(esc(palette.xLab) + ": " + fmt(xv) + " <span style='color:#94a3b8'>(" + binLabel(palette.xScale, xi) + ")</span>");
        lines.push(esc(palette.yLab) + ": " + fmt(yv) + " <span style='color:#94a3b8'>(" + binLabel(palette.yScale, yi) + ")</span>");
      } else if (palette.mode === "x") {
        lines.push(esc(palette.xLab) + ": " + fmt(xv));
      } else if (palette.mode === "y") {
        lines.push(esc(palette.yLab) + ": " + fmt(yv));
      } else if (palette.mode === "diff") {
        lines.push(esc(palette.xLab) + ": " + fmt(xv));
        lines.push(esc(palette.yLab) + ": " + fmt(yv));
        if (palette.comparable) lines.push("Diff (y − x): " + fmt(yv - xv));
        else lines.push("Rank diff (y − x): " + d3.format("+.2f")(palette.yRank(yv) - palette.xRank(xv)));
      } else if (palette.mode === "ratio") {
        lines.push(esc(palette.xLab) + ": " + fmt(xv));
        lines.push(esc(palette.yLab) + ": " + fmt(yv));
        if (xv !== 0) lines.push("Ratio (y / x): " + fmt(yv / xv));
      }
      if (ctrl.tooltipvars.length) {
        var rows = ctrl.tooltipvars.map(function (t) {
          var raw = row["t__" + t.var];
          var disp;
          if (raw == null || raw === "") disp = "—";
          else if (Number.isFinite(+raw) && t.numeric) disp = fmt(+raw);
          else disp = esc(raw);
          return "<tr><td style='color:#94a3b8;padding:1px 8px 1px 0'>" + esc(t.label) + "</td>"
            + "<td style='text-align:right'>" + disp + "</td></tr>";
        }).join("");
        lines.push("<table style='margin-top:6px;border-spacing:0;font-size:11px;line-height:1.35;border-top:1px solid rgba(255,255,255,.15);padding-top:4px'>" + rows + "</table>");
      }
      var fctx = [];
      ctrl.filters.forEach(function (f) {
        var v = row["f__" + f.var];
        if (v) fctx.push(esc(f.label) + ": " + esc(v));
      });
      if (fctx.length) lines.push("<span style='color:#94a3b8;font-size:11px'>" + fctx.join(" · ") + "</span>");
      if (!passes(row)) lines.push("<span style='color:#fbbf24'>(filtered out)</span>");
      return lines.join("<br/>");
    }

    function hexTipHTML(bin, palette, aggVal) {
      var lines = ["<strong>Hex bin</strong> · " + bin.length + " points"];
      lines.push(esc(palette.varLabel || "Value") + " (" + hexStat + "): " + fmt(aggVal));
      var samples = bin.slice(0, 6).map(function (p) {
        return "<li style='margin:0;color:#cbd5e1;font-size:11px'>" + esc(p.name || p.id) + " — " + fmt(p.v) + "</li>";
      }).join("");
      var more = bin.length > 6 ? "<li style='margin:0;color:#94a3b8;font-size:11px'>… and " + (bin.length - 6) + " more</li>" : "";
      lines.push("<ul style='margin:4px 0 0 0;padding-left:14px'>" + samples + more + "</ul>");
      return lines.join("<br/>");
    }

    // ---- Panel construction ----------------------------------------------
    var panels = [];

    function buildPanels() {
      panels.forEach(function (p) { p.svg.selectAll("*").remove(); });
      panels = [];

      if (state.multiples) {
        d3.select("#map").style("display", "none");
        var pdiv = d3.select("#panels").classed("active", true);
        pdiv.selectAll("*").remove();
        var n = allowedModes.length;
        var cols = n <= 2 ? n : (n <= 4 ? 2 : 3);
        pdiv.style("grid-template-columns", "repeat(" + cols + ", 1fr)");
        var pw = Math.round(fullW / Math.max(1, cols));
        var ph = Math.round(fullH / Math.max(1, cols));
        var legendM = Math.round(pw * 0.32);
        allowedModes.forEach(function (m) {
          var panel = pdiv.append("div").attr("class", "panel");
          panel.append("h4").attr("class", "panel-title").text(modeNice(m, meta));
          var svg = panel.append("svg")
            .attr("viewBox", [0, 0, pw, ph])
            .attr("preserveAspectRatio", "xMidYMid meet");
          panels.push(makePanel(svg, m, pw, ph, legendM));
        });
      }
      else {
        d3.select("#map").style("display", null);
        d3.select("#panels").classed("active", false).selectAll("*").remove();
        var svg = d3.select("#map")
          .attr("viewBox", [0, 0, fullW, fullH])
          .attr("preserveAspectRatio", "xMidYMid meet");
        svg.selectAll("*").remove();
        panels.push(makePanel(svg, state.mode, fullW, fullH, 220));
      }

      if (meta.zoom !== 0) {
        panels.forEach(function (panel) {
          var zoom = d3.zoom()
            .scaleExtent([1, 12])
            .on("zoom", function (ev) {
              panel.gWrap.attr("transform", ev.transform);
              panel.gWrap.attr("stroke-width", 0.45 / ev.transform.k);
            });
          panel.zoom = zoom;
          panel.svg.call(zoom);
          panel.svg.on("dblclick.zoom", null);
          panel.svg.on("dblclick", function () {
            panel.svg.transition().duration(500).call(zoom.transform, d3.zoomIdentity);
          });
        });
      }
    }

    // ---- Projection builder (v0.6.1) ------------------------------------
    // Resolve meta.projection + auto-defaults + numeric overrides into a
    // configured d3 projection instance.  fitExtent() is applied by the
    // caller after this returns.
    function parseNumList(s) {
      if (!s) return null;
      var out = String(s).split("|").map(function (v) { return +v; })
        .filter(Number.isFinite);
      return out.length ? out : null;
    }
    function buildProjection() {
      var preset = (meta.projection || "").toLowerCase();
      if (!preset) {
        if (layerName === "states" || layerName === "nation" || meta.geo === "us") {
          preset = "albers_usa";
        } else if (meta.geo === "texas") {
          preset = "albers_tx";
        } else {
          preset = "albers_usa";
        }
      }

      var proj;
      switch (preset) {
        case "albers_tx":
          proj = d3.geoAlbers()
            .rotate([99, 0])
            .center([0, 31.5])
            .parallels([27.5, 35.5]);
          break;
        case "albers":
          proj = d3.geoAlbers();
          break;
        case "mercator":
          proj = d3.geoMercator();
          break;
        case "albers_usa":
        default:
          proj = d3.geoAlbersUsa();
          break;
      }

      // Numeric overrides.  geoAlbersUsa is a composite that doesn't expose
      // rotate/parallels/center, so these flags are silently no-ops there
      // (d3 will throw if we try -- guard accordingly).
      var rot = parseNumList(meta.rotate);
      var par = parseNumList(meta.parallels);
      var ctr = parseNumList(meta.center);

      if (rot && typeof proj.rotate === "function") {
        if (rot.length === 1) proj.rotate([rot[0], 0]);
        else                  proj.rotate([rot[0], rot[1]]);
      }
      if (par && par.length === 2 && typeof proj.parallels === "function") {
        proj.parallels([par[0], par[1]]);
      }
      if (ctr && ctr.length === 2 && typeof proj.center === "function") {
        proj.center([ctr[0], ctr[1]]);
      }
      return proj;
    }

    function makePanel(svg, mode, w, h, legendMargin) {
      var margin = { top: 18, right: legendMargin, bottom: 14, left: 10 };

      // Always fit the projection to the FOCUSED features so the user's region
      // fills the viewport.  The basemap is drawn beneath at whatever extent —
      // it may extend off-screen, that's fine for a "background" effect.
      // If the focused layer is empty (rare), fall back to the basemap.
      var fitFeatures = features.length ? features : basemapFeatures;
      var fc = { type: "FeatureCollection", features: fitFeatures };

      // Projection selection.  Order of precedence:
      //   1. meta.projection -- explicit preset (albers_usa|albers_tx|albers|mercator)
      //   2. Auto-default driven by geo / layer:
      //        layer = states|nation OR geo = us   -> albers_usa (CONUS composite)
      //        geo   = texas                        -> albers_tx  (Texas-tuned)
      //        anything else                         -> albers_usa (legacy default)
      //   3. Numeric overrides (meta.rotate, meta.parallels, meta.center) layer
      //      on top of the chosen preset.  Pipe-separated lists like "27.5|35.5".
      //
      // The Texas-tuned albers_tx preset corrects a ~3-degree downward lean of
      // the panhandle's top edge that occurs when geoAlbersUsa()'s CONUS-wide
      // standard parallels (29.5/45.5) and -96 rotation are applied to a
      // Texas-only viewport.  See v0.6.1 notes in sparkta2_map.ado.
      var projection = buildProjection();
      projection.fitExtent(
        [[margin.left, margin.top], [w - margin.right, h - margin.bottom]],
        fc
      );

      var pathGen = d3.geoPath(projection);
      var gWrap   = svg.append("g").attr("class", "wrap");
      var gBase   = gWrap.append("g").attr("class", "basemap");
      var gMap    = gWrap.append("g").attr("class", "regions");
      var gHex    = gWrap.append("g").attr("class", "hexbins");
      var gPts    = gWrap.append("g").attr("class", "points");
      var gLegend = svg.append("g").attr("class", "legend");

      return {
        mode: mode, svg: svg, w: w, h: h, margin: margin,
        pathGen: pathGen, projection: projection,
        gWrap: gWrap, gBase: gBase, gMap: gMap, gHex: gHex, gPts: gPts, gLegend: gLegend
      };
    }

    // ---- Paint one panel -------------------------------------------------
    function paintPanel(panel) {
      var palette = buildPalette(panel.mode);
      panel._palette = palette;

      // Always paint basemap first (faded outline)
      panel.gBase.selectAll("path").remove();
      if (basemapFeatures.length) {
        panel.gBase.selectAll("path").data(basemapFeatures).enter().append("path")
          .attr("d", panel.pathGen)
          .attr("fill", "#eef2f7")
          .attr("stroke", "#cbd5e1")
          .attr("stroke-width", 0.6)
          .attr("pointer-events", "none");
      }

      if (renderType === "hexbin") {
        paintHexbins(panel, palette);
      }
      else if (renderType === "points") {
        paintPoints(panel, palette);
      }
      else {
        paintRegions(panel, palette);
      }

      drawLegend(panel, palette);
    }

    function paintRegions(panel, palette) {
      panel.gHex.selectAll("*").remove();
      panel.gPts.selectAll("*").remove();

      var sel = panel.gMap.selectAll("path.region").data(features, function (d) { return d.id; });
      var entered = sel.enter().append("path")
          .attr("class", "region")
          .attr("d", panel.pathGen);

      entered.on("mousemove", function (ev, d) {
        var row = index.get(padId(d.id, idwidth));
        var name = (row && row.name) || ("FIPS " + padId(d.id, idwidth));
        showTip(tipHTML(row, name, panel._palette), ev);
        d3.select(this).classed("hl", true);
      });
      entered.on("mouseleave", function () {
        hideTip();
        d3.select(this).classed("hl", false);
      });

      if (meta.zoom !== 0 && panel.zoom) {
        entered.on("click", function (ev, d) {
          ev.stopPropagation();
          zoomToFeature(panel, d);
        });
      }

      entered.merge(sel)
        .attr("fill", function (d) {
          var row = index.get(padId(d.id, idwidth));
          if (!row || !passes(row)) return null;
          return palette.colorFn(row);
        })
        .classed("dim", function (d) {
          var row = index.get(padId(d.id, idwidth));
          return !row || !passes(row);
        });
    }

    function paintPoints(panel, palette) {
      panel.gMap.selectAll("*").remove();
      panel.gHex.selectAll("*").remove();

      // Outline of layer (counties etc.) underneath, faded
      var outline = panel.gMap.selectAll("path.outline").data(features).enter().append("path")
        .attr("class", "region")
        .attr("d", panel.pathGen)
        .attr("fill", "#f8fafc")
        .attr("stroke", "#cbd5e1")
        .attr("stroke-width", 0.4)
        .attr("pointer-events", "none");

      // Project each row's lat/lon -> [x,y]
      var pts = data.map(function (d) {
        if (d.lat == null || d.lon == null) return null;
        var xy = panel.projection([+d.lon, +d.lat]);
        if (!xy) return null;
        return { row: d, x: xy[0], y: xy[1] };
      }).filter(function (p) { return p; });

      var circles = panel.gPts.selectAll("circle").data(pts).enter().append("circle")
        .attr("cx", function (p) { return p.x; })
        .attr("cy", function (p) { return p.y; })
        .attr("r", pointSize)
        .attr("fill", function (p) {
          return passes(p.row) ? palette.colorFn(p.row) : "#e2e8f0";
        })
        .attr("stroke", "#fff")
        .attr("stroke-width", 0.4)
        .style("opacity", function (p) { return passes(p.row) ? 0.85 : 0.25; });

      circles.on("mousemove", function (ev, p) {
        var nm = p.row.name || p.row.id;
        showTip(tipHTML(p.row, nm, panel._palette), ev);
        d3.select(this).attr("stroke", "#0f172a").attr("stroke-width", 1.2);
      });
      circles.on("mouseleave", function () {
        hideTip();
        d3.select(this).attr("stroke", "#fff").attr("stroke-width", 0.4);
      });
    }

    function paintHexbins(panel, palette) {
      panel.gPts.selectAll("*").remove();

      // Outline counties (faded) below the hexbins
      panel.gMap.selectAll("*").remove();
      panel.gMap.selectAll("path.outline").data(features).enter().append("path")
        .attr("class", "region")
        .attr("d", panel.pathGen)
        .attr("fill", "#f8fafc")
        .attr("stroke", "#cbd5e1")
        .attr("stroke-width", 0.4)
        .attr("pointer-events", "none");

      // Build the points to hexbin over:
      //   - If lat/lon are set on the data rows, use them
      //   - Else fall back to feature centroids, joined by id
      var points = [];
      if (hasLatLon) {
        data.forEach(function (d) {
          if (d.lat == null || d.lon == null) return;
          var xy = panel.projection([+d.lon, +d.lat]);
          if (!xy) return;
          var v = +d[palette.xVar];
          points.push({ x: xy[0], y: xy[1], v: v, name: d.name, id: d.id, row: d });
        });
      } else {
        features.forEach(function (f) {
          var row = index.get(padId(f.id, idwidth));
          if (!row || !passes(row)) return;
          var c = panel.pathGen.centroid(f);
          if (!c || isNaN(c[0])) return;
          var v = +row[palette.xVar];
          if (!Number.isFinite(v)) return;
          points.push({ x: c[0], y: c[1], v: v, name: row.name, id: row.id, row: row });
        });
      }

      // d3-hexbin defaults to array indexing (point[0]/point[1]); set accessors
      // so it reads our object-shaped points correctly.
      var hb = d3.hexbin()
        .x(function (d) { return d.x; })
        .y(function (d) { return d.y; })
        .radius(hexRadius)
        .extent([[0, 0], [panel.w, panel.h]]);
      var bins = hb(points);

      // Aggregate per bin
      function aggregate(bin) {
        var vals = bin.map(function (p) { return +p.v; }).filter(Number.isFinite);
        if (!vals.length) return NaN;
        if (hexStat === "sum")    return d3.sum(vals);
        if (hexStat === "median") return d3.median(vals);
        if (hexStat === "count")  return vals.length;
        if (hexStat === "max")    return d3.max(vals);
        if (hexStat === "min")    return d3.min(vals);
        return d3.mean(vals);
      }
      var aggVals = bins.map(aggregate).filter(Number.isFinite);

      var seq = seqScheme((meta.scheme || "blues").toLowerCase(), 7);
      var scale = d3.scaleQuantile(aggVals, seq);

      panel._palette.scale = scale;
      panel._palette.varLabel = (meta.xlabel || meta.xvar || "Value") + " (" + hexStat + ")";

      var hexes = panel.gHex.selectAll("path.hex").data(bins).enter().append("path")
        .attr("class", "hex")
        .attr("d", hb.hexagon())
        .attr("transform", function (d) { return "translate(" + d.x + "," + d.y + ")"; })
        .attr("fill", function (d) {
          var v = aggregate(d);
          return Number.isFinite(v) ? scale(v) : "#eef2f7";
        })
        .attr("stroke", "#fff")
        .attr("stroke-width", 0.5);

      hexes.on("mousemove", function (ev, d) {
        var v = aggregate(d);
        showTip(hexTipHTML(d, panel._palette, v), ev);
        d3.select(this).attr("stroke", "#0f172a").attr("stroke-width", 1.4);
      });
      hexes.on("mouseleave", function () {
        hideTip();
        d3.select(this).attr("stroke", "#fff").attr("stroke-width", 0.5);
      });
    }

    function zoomToFeature(panel, feature) {
      var b = panel.pathGen.bounds(feature);
      var x0 = b[0][0], y0 = b[0][1], x1 = b[1][0], y1 = b[1][1];
      var k = Math.min(12, 0.9 / Math.max((x1 - x0) / panel.w, (y1 - y0) / panel.h));
      var tx = panel.w / 2 - k * (x0 + x1) / 2;
      var ty = panel.h / 2 - k * (y0 + y1) / 2;
      panel.svg.transition().duration(750)
        .call(panel.zoom.transform, d3.zoomIdentity.translate(tx, ty).scale(k));
    }

    function zoomToFeatures(panel, featureSet) {
      if (!featureSet.length || !panel.zoom) return;
      var fc = { type: "FeatureCollection", features: featureSet };
      var b = panel.pathGen.bounds(fc);
      var x0 = b[0][0], y0 = b[0][1], x1 = b[1][0], y1 = b[1][1];
      var k = Math.min(12, 0.9 / Math.max((x1 - x0) / panel.w, (y1 - y0) / panel.h));
      var tx = panel.w / 2 - k * (x0 + x1) / 2;
      var ty = panel.h / 2 - k * (y0 + y1) / 2;
      panel.svg.call(panel.zoom.transform, d3.zoomIdentity.translate(tx, ty).scale(k));
    }

    function drawLegend(panel, palette) {
      panel.gLegend.selectAll("*").remove();
      var lx = panel.w - panel.margin.right + 14;
      var ly = 28;
      panel.gLegend.attr("transform", "translate(" + lx + "," + ly + ")");

      if (renderType === "hexbin") {
        drawSeqLegend(panel, palette.scale, palette.varLabel);
        return;
      }

      if (palette.mode === "bivariate") {
        var k = Math.max(14, Math.min(24, Math.round((panel.margin.right - 60) / nBins)));
        panel.gLegend.append("text").attr("x", 0).attr("y", -8)
          .attr("font-weight", 600).text("Bivariate scale");
        d3.cross(d3.range(nBins), d3.range(nBins)).forEach(function (pair) {
          var i = pair[0], j = pair[1];
          panel.gLegend.append("rect")
            .attr("x", i * k).attr("y", (nBins - 1 - j) * k)
            .attr("width", k).attr("height", k)
            .attr("fill", biv[j * nBins + i]);
        });
        panel.gLegend.append("text").attr("x", 0).attr("y", nBins * k + 14).text(palette.xLab + " →");
        panel.gLegend.append("text")
          .attr("transform", "translate(" + (nBins * k + 12) + "," + (nBins * k) + ") rotate(-90)")
          .text(palette.yLab + " →");
      }
      else if (palette.mode === "x" || palette.mode === "y") {
        drawSeqLegend(panel, palette.scale, palette.varLabel);
      }
      else if (palette.mode === "diff") {
        var title = palette.comparable
          ? (palette.yLab + " − " + palette.xLab)
          : "Rank(" + palette.yLab + ") − Rank(" + palette.xLab + ")";
        drawDivLegend(panel, palette.diffScale, title);
      }
      else if (palette.mode === "ratio") {
        drawDivLegend(panel, palette.ratioScale, palette.yLab + " / " + palette.xLab + " (log)");
      }
    }

    function drawSeqLegend(panel, scale, label) {
      if (!scale || !scale.range) return;
      panel.gLegend.append("text").attr("x", 0).attr("y", -8)
        .attr("font-weight", 600).text(label);
      var colors = scale.range();
      var quantiles = scale.quantiles ? scale.quantiles() : [];
      var bw = 20, bh = Math.max(14, Math.min(20, Math.round((panel.h - 60) / colors.length)));
      colors.forEach(function (c, i) {
        panel.gLegend.append("rect")
          .attr("x", 0).attr("y", i * bh)
          .attr("width", bw).attr("height", bh).attr("fill", c);
        var lbl;
        if (i === 0) lbl = "< " + fmt(quantiles[0]);
        else if (i === colors.length - 1) lbl = "≥ " + fmt(quantiles[quantiles.length - 1]);
        else lbl = fmt(quantiles[i - 1]) + " – " + fmt(quantiles[i]);
        panel.gLegend.append("text").attr("x", bw + 6).attr("y", i * bh + bh / 2 + 4).text(lbl);
      });
    }

    function drawDivLegend(panel, scale, label) {
      panel.gLegend.append("text").attr("x", 0).attr("y", -8)
        .attr("font-weight", 600).text(label);
      var colors = scale.range();
      var domain = scale.domain();
      var bw = 20, bh = Math.max(12, Math.min(18, Math.round((panel.h - 60) / colors.length)));
      colors.forEach(function (c, i) {
        panel.gLegend.append("rect")
          .attr("x", 0).attr("y", i * bh)
          .attr("width", bw).attr("height", bh).attr("fill", c);
      });
      var nb = colors.length;
      panel.gLegend.append("text").attr("x", bw + 6).attr("y", bh / 2 + 4).text(fmt(domain[1]));
      panel.gLegend.append("text").attr("x", bw + 6).attr("y", nb * bh - bh / 2 + 4).text(fmt(domain[0]));
      panel.gLegend.append("text").attr("x", bw + 6).attr("y", (nb / 2) * bh + 4).text("0");
    }

    function repaint() {
      panels.forEach(paintPanel);
      updateMeta();
    }

    // ---- Controls panel --------------------------------------------------
    var controlsRoot = d3.select("#controls");

    function buildControls() {
      controlsRoot.selectAll("*").remove();

      // Mode toggle only meaningful for choropleth/bivariate (not hexbin/points)
      if (renderType !== "hexbin" && renderType !== "points"
          && !state.multiples && allowedModes.length > 1) {
        controlsRoot.append("h3").text("Comparison mode");
        var modeBox = controlsRoot.append("div").attr("class", "modes");
        allowedModes.forEach(function (m) {
          modeBox.append("button")
            .attr("type", "button")
            .classed("active", m === state.mode)
            .text(modeNice(m, meta))
            .on("click", function () {
              state.mode = m;
              modeBox.selectAll("button").classed("active", false);
              d3.select(this).classed("active", true);
              buildPanels();
              repaint();
            });
        });
      }
      else if (renderType !== "hexbin" && renderType !== "points" && state.multiples) {
        controlsRoot.append("h3").text("Small multiples");
        controlsRoot.append("div").style("font-size", ".8rem").style("color", "var(--muted)")
          .text(allowedModes.length + " panels: " +
                allowedModes.map(function (m) { return modeNice(m, meta); }).join(", "));
      }

      if (meta.search) {
        controlsRoot.append("h3").style("margin-top", "12px").text("Search");
        controlsRoot.append("input")
          .attr("type", "search")
          .attr("placeholder", "Filter by name…")
          .on("input", function () {
            state.search = (this.value || "").toLowerCase();
            repaint();
          });
      }

      if (meta.swap && hasYvar) {
        controlsRoot.append("button")
          .style("margin-top", "10px")
          .attr("type", "button")
          .text("Swap axes (X ⇄ Y)")
          .on("click", function () { state.swap = !state.swap; repaint(); });
      }

      if ((ctrl.filters || []).length) {
        controlsRoot.append("h3").style("margin-top", "14px").text("Filters");
        ctrl.filters.forEach(function (f) {
          controlsRoot.append("label").text(f.label);
          var sel = controlsRoot.append("select")
            .on("change", function () {
              state.filters[f.var] = this.value;
              repaint();
            });
          sel.append("option").attr("value", "__all__").text("All (" + f.values.length + ")");
          f.values.forEach(function (v) {
            sel.append("option").attr("value", v).text(v);
          });
        });
      }

      if ((ctrl.sliders || []).length) {
        controlsRoot.append("h3").style("margin-top", "14px").text("Range filters");
        ctrl.sliders.forEach(function (s) { buildSlider(controlsRoot, s); });
      }

      var hasZoom = meta.zoom !== 0;
      if (hasZoom || meta.download || meta.datatable) {
        controlsRoot.append("h3").style("margin-top", "14px").text("View");
        if (hasZoom) {
          controlsRoot.append("button")
            .attr("type", "button")
            .style("margin-bottom", "6px")
            .text("Reset zoom")
            .on("click", resetZoom);
        }
        if (meta.download || meta.datatable) {
          buildExportMenu(controlsRoot);
        }
      }

      controlsRoot.append("div").attr("class", "meta").attr("id", "metabox");
    }

    // ---- Export menu (PNG/SVG/CSV/View data/Print to PDF) ----------------
    function buildExportMenu(root) {
      var wrap = root.append("div").attr("class", "exportmenu");
      var btn = wrap.append("button")
        .attr("type", "button")
        .attr("class", "exportbtn")
        .attr("aria-haspopup", "true")
        .attr("aria-expanded", "false")
        .html("Export &#9662;");
      var menu = wrap.append("div").attr("class", "exportlist").style("display", "none");

      function addItem(label, fn) {
        menu.append("button")
          .attr("type", "button")
          .text(label)
          .on("click", function () {
            closeMenu();
            fn();
          });
      }
      function openMenu()  { menu.style("display", "block"); btn.attr("aria-expanded", "true"); }
      function closeMenu() { menu.style("display", "none");  btn.attr("aria-expanded", "false"); }

      btn.on("click", function (ev) {
        ev.stopPropagation();
        if (menu.style("display") === "none") openMenu();
        else closeMenu();
      });
      // Close on outside click
      d3.select(document).on("click.exportmenu", function () { closeMenu(); });
      menu.on("click", function (ev) { ev.stopPropagation(); });

      if (meta.download) {
        addItem("Download PNG", downloadPNG);
        addItem("Download SVG", downloadSVG);
        addItem("Print to PDF…", printToPDF);
      }
      if (meta.datatable) {
        addItem("Download CSV", downloadCSV);
        addItem("View data table", toggleDataTable);
      }
    }

    function resetZoom() {
      panels.forEach(function (p) {
        if (p.zoom) p.svg.transition().duration(500).call(p.zoom.transform, d3.zoomIdentity);
      });
    }

    function buildSlider(root, s) {
      var span = s.max - s.min;
      var pad = span === 0 ? 1 : 0;
      var lo = state.sliders[s.var][0];
      var hi = state.sliders[s.var][1];

      var box = root.append("div").attr("class", "sliderbox");
      var lbl = box.append("div").attr("class", "lbl");
      lbl.append("span").attr("class", "name").text(s.label);
      var vlbl = lbl.append("span").attr("class", "vals").text(fmt(lo) + " – " + fmt(hi));

      var track = box.append("div").attr("class", "track");
      var fill = track.append("div").attr("class", "fill");

      var inputLo = track.append("input")
        .attr("type", "range").attr("min", s.min - pad).attr("max", s.max + pad)
        .attr("step", (span / 200) || 0.01).property("value", lo);
      var inputHi = track.append("input")
        .attr("type", "range").attr("min", s.min - pad).attr("max", s.max + pad)
        .attr("step", (span / 200) || 0.01).property("value", hi);

      function updateFill() {
        var v0 = +inputLo.property("value");
        var v1 = +inputHi.property("value");
        if (v0 > v1) { var t = v0; v0 = v1; v1 = t; }
        var pct0 = (v0 - s.min) / (span || 1) * 100;
        var pct1 = (v1 - s.min) / (span || 1) * 100;
        fill.style("left", pct0 + "%").style("width", (pct1 - pct0) + "%");
        vlbl.text(fmt(v0) + " – " + fmt(v1));
        state.sliders[s.var] = [v0, v1];
      }
      updateFill();
      inputLo.on("input", function () { updateFill(); repaint(); });
      inputHi.on("input", function () { updateFill(); repaint(); });
    }

    function updateMeta() {
      var pass = data.filter(passes).length;
      d3.select("#metabox").html(
        "<strong>" + pass + "</strong> of " + data.length + (renderType === "points" ? " points" : " features") + " shown"
      );
    }

    function downloadPNG() {
      if (state.multiples) compositePNG(panels);
      else compositePNG([panels[0]]);
    }

    // ---- SVG download: serialize the live SVG with inlined CSS -----------
    function downloadSVG() {
      var panelList = state.multiples ? panels : [panels[0]];
      var inlineCSS =
        ".region{stroke:#fff;stroke-width:.45px}" +
        ".region.dim{fill:#f1f5f9}" +
        ".legend text{font:12px sans-serif;fill:#334155}" +
        "text{font-family:-apple-system,sans-serif}";

      if (panelList.length === 1) {
        var clone = panelList[0].svg.node().cloneNode(true);
        clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
        clone.setAttribute("width",  panelList[0].w);
        clone.setAttribute("height", panelList[0].h);
        var styleEl = document.createElementNS("http://www.w3.org/2000/svg", "style");
        styleEl.textContent = inlineCSS;
        clone.insertBefore(styleEl, clone.firstChild);
        var svgText = new XMLSerializer().serializeToString(clone);
        var blob = new Blob([svgText], { type: "image/svg+xml;charset=utf-8" });
        triggerDownload(blob, "sparkta2_map.svg");
        return;
      }

      // Small-multiples: stack panels in a single SVG so the export is one file.
      var totalW = Math.max.apply(null, panelList.map(function (p) { return p.w; }));
      var totalH = panelList.reduce(function (s, p) { return s + p.h + 24; }, 0);
      var outer = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      outer.setAttribute("xmlns", "http://www.w3.org/2000/svg");
      outer.setAttribute("width",  totalW);
      outer.setAttribute("height", totalH);
      var s2 = document.createElementNS("http://www.w3.org/2000/svg", "style");
      s2.textContent = inlineCSS;
      outer.appendChild(s2);
      var yOff = 0;
      panelList.forEach(function (p) {
        var g = document.createElementNS("http://www.w3.org/2000/svg", "g");
        g.setAttribute("transform", "translate(0," + yOff + ")");
        // Copy all children of the panel SVG into the wrapping <g>.
        var src = p.svg.node();
        for (var i = 0; i < src.childNodes.length; i++) {
          g.appendChild(src.childNodes[i].cloneNode(true));
        }
        outer.appendChild(g);
        yOff += p.h + 24;
      });
      var outerText = new XMLSerializer().serializeToString(outer);
      var blob2 = new Blob([outerText], { type: "image/svg+xml;charset=utf-8" });
      triggerDownload(blob2, "sparkta2_multiples.svg");
    }

    // ---- CSV download: serialize the bound data rows --------------------
    function downloadCSV() {
      var rows = data;
      if (!rows || !rows.length) {
        alert("No data to download.");
        return;
      }
      // Stable, predictable column order: id, name, x, y, lat, lon, then
      // f__/s__/t__ helper columns last.  Skip helper-prefix names in the
      // header by mapping them back to their bare variable name.
      var coreCols = ["id", "name", "x", "y", "lat", "lon"];
      var keys = Object.keys(rows[0]);
      var fCols = keys.filter(function (k) { return k.indexOf("f__") === 0; });
      var sCols = keys.filter(function (k) { return k.indexOf("s__") === 0; });
      var tCols = keys.filter(function (k) { return k.indexOf("t__") === 0; });
      var ordered = coreCols.filter(function (k) { return keys.indexOf(k) >= 0; })
        .concat(fCols).concat(sCols).concat(tCols);

      // Header line uses the variable's real name (strip f__/s__/t__).
      var displayHead = ordered.map(function (k) {
        if (k.indexOf("f__") === 0) return k.slice(3);
        if (k.indexOf("s__") === 0) return k.slice(3);
        if (k.indexOf("t__") === 0) return k.slice(3);
        if (k === "x") return meta.xvar || "x";
        if (k === "y") return meta.yvar || "y";
        return k;
      });

      function csvCell(v) {
        if (v == null) return "";
        var s = String(v);
        if (s.indexOf(",") >= 0 || s.indexOf("\"") >= 0 || s.indexOf("\n") >= 0) {
          return "\"" + s.replace(/"/g, "\"\"") + "\"";
        }
        return s;
      }

      var lines = [ displayHead.map(csvCell).join(",") ];
      rows.forEach(function (r) {
        lines.push(ordered.map(function (k) { return csvCell(r[k]); }).join(","));
      });
      var csv = lines.join("\n");
      var blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
      triggerDownload(blob, "sparkta2_data.csv");
    }

    // ---- Toggle the collapsible data-view table -------------------------
    function toggleDataTable() {
      var host = d3.select("#datatable");
      if (host.empty()) return;
      var shown = host.classed("open");
      if (shown) {
        host.classed("open", false).style("display", "none").html("");
        return;
      }
      // Build a simple, scrollable HTML table.  Only show rows that pass the
      // active filters/sliders/search so what the user reads matches what
      // the map shows.
      var rows = data.filter(passes);
      var coreCols = ["id", "name", "x", "y", "lat", "lon"];
      var keys = rows.length ? Object.keys(rows[0]) : [];
      var fCols = keys.filter(function (k) { return k.indexOf("f__") === 0; });
      var sCols = keys.filter(function (k) { return k.indexOf("s__") === 0; });
      var tCols = keys.filter(function (k) { return k.indexOf("t__") === 0; });
      var ordered = coreCols.filter(function (k) { return keys.indexOf(k) >= 0; })
        .concat(fCols).concat(sCols).concat(tCols);
      function head(k) {
        if (k.indexOf("f__") === 0) return k.slice(3);
        if (k.indexOf("s__") === 0) return k.slice(3);
        if (k.indexOf("t__") === 0) return k.slice(3);
        if (k === "x") return meta.xvar || "x";
        if (k === "y") return meta.yvar || "y";
        return k;
      }
      var html = "<div class='dt-header'><strong>Data behind the map</strong> "
        + "<span class='dt-count'>" + rows.length + " of " + data.length + " rows shown</span>"
        + "<button type='button' class='dt-close' aria-label='Close'>&times;</button></div>";
      html += "<div class='dt-scroll'><table class='dt-table'><thead><tr>";
      ordered.forEach(function (k) { html += "<th>" + esc(head(k)) + "</th>"; });
      html += "</tr></thead><tbody>";
      // Cap visible rows to keep the DOM light; CSV download has the full set.
      var MAX = 500;
      rows.slice(0, MAX).forEach(function (r) {
        html += "<tr>";
        ordered.forEach(function (k) {
          var v = r[k];
          html += "<td>" + esc(v == null ? "" : v) + "</td>";
        });
        html += "</tr>";
      });
      html += "</tbody></table></div>";
      if (rows.length > MAX) {
        html += "<div class='dt-truncated'>Showing first " + MAX + " of "
          + rows.length + " rows — use <em>Download CSV</em> for the full set.</div>";
      }
      host.html(html).classed("open", true).style("display", "block");
      host.select(".dt-close").on("click", toggleDataTable);
    }

    // ---- Print to PDF: open the browser's print dialog ------------------
    function printToPDF() {
      // The browser-native print path is the most reliable way to a PDF
      // without bundling a 70KB jsPDF lib.  Use a CSS print sheet to hide
      // the controls and show only the map.  The user picks "Save as PDF"
      // in the print dialog.
      window.print();
    }

    function triggerDownload(blob, filename) {
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url; a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(function () { URL.revokeObjectURL(url); }, 5000);
    }

    // ---- Animate-on-view: fade regions in when chart enters viewport ----
    function setupAnimateOnView() {
      if (!meta.animate) return;
      if (typeof IntersectionObserver === "undefined") {
        // Older browser: fall back to immediate fade-in.
        triggerAnimation();
        return;
      }
      var fired = false;
      var target = document.getElementById("map") || document.getElementById("panels");
      if (!target) return;
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting && !fired) {
            fired = true;
            io.disconnect();
            triggerAnimation();
          }
        });
      }, { threshold: 0.2 });
      io.observe(target);
    }

    function triggerAnimation() {
      // Stagger by feature index for a "sweep across the map" effect; keep
      // total duration short (under 900ms) so it doesn't feel sluggish.
      panels.forEach(function (panel) {
        var sel;
        if (renderType === "hexbin") sel = panel.gHex.selectAll("path.hex");
        else if (renderType === "points") sel = panel.gPts.selectAll("circle");
        else sel = panel.gMap.selectAll("path.region");
        if (!sel || sel.empty()) return;
        var n = sel.size();
        sel.style("opacity", 0)
           .transition()
           .duration(450)
           .delay(function (d, i) { return Math.min(450, i * (450 / Math.max(1, n))); })
           .style("opacity", null);
      });
    }

    function compositePNG(panelList) {
      var scale = 2;
      var totalW = Math.max.apply(null, panelList.map(function (p) { return p.w; }));
      var totalH = panelList.reduce(function (s, p) { return s + p.h + 24; }, 0);
      var canvas = document.createElement("canvas");
      canvas.width  = totalW * scale;
      canvas.height = totalH * scale;
      var ctx = canvas.getContext("2d");
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      var inlineCSS =
        ".region{stroke:#fff;stroke-width:.45px}" +
        ".region.dim{fill:#f1f5f9}" +
        ".legend text{font:12px sans-serif;fill:#334155}" +
        "text{font-family:-apple-system,sans-serif}";

      var yOffset = 0;
      var loaded = 0;
      panelList.forEach(function (panel, i) {
        var pw = panel.w, ph = panel.h;
        var node = panel.svg.node();
        var clone = node.cloneNode(true);
        clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
        clone.setAttribute("width", pw);
        clone.setAttribute("height", ph);
        var styleEl = document.createElementNS("http://www.w3.org/2000/svg", "style");
        styleEl.textContent = inlineCSS;
        clone.insertBefore(styleEl, clone.firstChild);
        var svgText = new XMLSerializer().serializeToString(clone);
        var url = "data:image/svg+xml;charset=utf-8;base64," + btoa(unescape(encodeURIComponent(svgText)));
        var img = new Image();
        var yi = yOffset;
        img.onload = function () {
          ctx.drawImage(img, 0, yi * scale, pw * scale, ph * scale);
          loaded++;
          if (loaded === panelList.length) {
            canvas.toBlob(function (blob) {
              var dl = document.createElement("a");
              dl.download = "sparkta2_" + (panelList.length > 1 ? "multiples" : "map") + ".png";
              dl.href = URL.createObjectURL(blob);
              dl.click();
              setTimeout(function () { URL.revokeObjectURL(dl.href); }, 5000);
            });
          }
        };
        img.onerror = function () { loaded++; };
        img.src = url;
        yOffset += ph + 24;
      });
    }

    buildControls();
    buildPanels();
    repaint();
    setupAnimateOnView();

    if (meta.zoomto) {
      var wantFips = (meta.zoomto || "").split("|").filter(Boolean);
      if (wantFips.length) {
        var toZoom = features.filter(function (f) { return wantFips.indexOf(padId(f.id, idwidth)) >= 0; });
        panels.forEach(function (p) { zoomToFeatures(p, toZoom); });
      }
    }
  }

  window.sparkta2Render = render;
})();
