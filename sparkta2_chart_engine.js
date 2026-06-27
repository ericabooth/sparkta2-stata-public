/* sparkta2_chart_engine.js -- D3 v7 engine for native (non-map) sparkta2 chart types.
   Builds on:
     https://observablehq.com/@d3/bar-chart-race
     https://observablehq.com/@d3/diverging-stacked-bar-chart/2
     https://d3-graph-gallery.com/donut.html

   Renderers:
     donut    : ring chart, one slice per row
     bar      : vertical / horizontal bars; over() for grouped / stacked
     line     : multi-series line; over() for series
     divbar   : Pew-style diverging stacked bar for Likert / survey items
     barrace  : animated bar chart over time()

   Shared infrastructure (mirrors sparkta2_engine.js):
     Tooltip div, Export menu (PNG / SVG / CSV / Print to PDF / View data),
     data-table panel, animate-on-view (IntersectionObserver), per-row
     tooltipvars table.
*/
(function () {
  "use strict";

  // ---- Shared helpers --------------------------------------------------
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;")
      .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }
  function fmt(v) {
    if (v == null || !Number.isFinite(+v)) return "N/A";
    var n = +v;
    if (Math.abs(n) >= 1000)       return d3.format(",.0f")(n);
    if (Math.abs(n) >= 1)          return d3.format(",.1f")(n);
    return d3.format(".2f")(n);
  }
  function fmtPct(v) {
    if (v == null || !Number.isFinite(+v)) return "N/A";
    return d3.format(".1f")(+v) + "%";
  }
  function luminance(hex) {
    // Convert #rrggbb to relative luminance for label-contrast picking.
    var m = /^#?([0-9a-f]{6})$/i.exec(hex || "");
    if (!m) return 0.5;
    var n = parseInt(m[1], 16);
    var r = ((n >> 16) & 255) / 255;
    var g = ((n >> 8)  & 255) / 255;
    var b = ( n        & 255) / 255;
    function lin(c) { return c <= 0.03928 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4); }
    return 0.2126*lin(r) + 0.7152*lin(g) + 0.0722*lin(b);
  }
  function labelFill(hex) { return luminance(hex) > 0.55 ? "#1f2937" : "#ffffff"; }

  // Palettes
  var TX2036_PALETTE = ["#1B2D55","#D44500","#2B6CB0","#6C7A8D","#7A9D54",
                       "#A67B36","#9C5BA5","#3F8A8C","#C0392B","#F1A208"];
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
    if (name === "tx2036")  return TX2036_PALETTE;
    return d3.schemeBlues[k];
  }
  function divScheme(name, k) {
    k = k || 9;
    if (name === "brbg")   return d3.range(k).map(function (i) { return d3.interpolateBrBG(i / (k - 1)); });
    if (name === "puor")   return d3.range(k).map(function (i) { return d3.interpolatePuOr(i / (k - 1)); });
    if (name === "rdylbu") return d3.range(k).map(function (i) { return d3.interpolateRdYlBu(i / (k - 1)); });
    if (name === "rdylgn") return d3.range(k).map(function (i) { return d3.interpolateRdYlGn(i / (k - 1)); });
    return d3.range(k).map(function (i) { return d3.interpolateRdBu(1 - i / (k - 1)); });
  }

  // ---- Main render -----------------------------------------------------
  function render(cfg) {
    var meta = cfg.meta || {};
    var data = cfg.data || [];
    var tipvars = cfg.tooltipvars || [];

    var W = +meta.width  || 980;
    var H = +meta.height || 560;

    var svg = d3.select("#chart")
      .attr("viewBox", [0, 0, W, H])
      .attr("preserveAspectRatio", "xMidYMid meet");

    var tooltip = d3.select("#tooltip");
    function showTip(html, ev) {
      tooltip.style("opacity", 1).html(html)
        .style("left", (ev.pageX + 14) + "px")
        .style("top",  (ev.pageY - 28) + "px");
    }
    function hideTip() { tooltip.style("opacity", 0); }

    function tipRow(label, val) {
      return "<tr><td style='color:#94a3b8;padding:1px 8px 1px 0'>" + esc(label)
        + "</td><td style='text-align:right'>" + esc(val) + "</td></tr>";
    }
    function tipTable(rows) {
      return "<table style='margin-top:6px;border-spacing:0;font-size:11px;line-height:1.35;border-top:1px solid rgba(255,255,255,.15);padding-top:4px'>"
        + rows.join("") + "</table>";
    }
    function appendTipvars(row, lines) {
      if (!tipvars.length) return;
      var rs = tipvars.map(function (t) {
        var raw = row["t__" + t.var];
        var disp;
        if (raw == null || raw === "") disp = "—";
        else if (Number.isFinite(+raw) && t.numeric) disp = fmt(+raw);
        else disp = raw;
        return tipRow(t.label, disp);
      });
      lines.push(tipTable(rs));
    }

    // ---- Build controls panel (search, export, animate, ...) ----------
    var controlsRoot = d3.select("#controls");
    buildControls();

    function buildControls() {
      controlsRoot.selectAll("*").remove();
      var dlpos = (meta.downloadpos || "side").toLowerCase();
      var hideExport = (dlpos === "none");
      var exportInFooter = (dlpos === "below");

      if ((meta.download || meta.datatable) && !hideExport && !exportInFooter) {
        controlsRoot.append("h3").text("View");
        buildExportMenu(controlsRoot);
      }
      // Type-specific control widgets are appended by the renderer.
      controlsRoot.append("div").attr("class", "meta").attr("id", "metabox");
      updateMetabox();

      if (exportInFooter && !hideExport && (meta.download || meta.datatable)) {
        var foot = d3.select("#chart-footer").classed("active", true);
        foot.selectAll("*").remove();
        buildExportMenu(foot);
      }
      // Collapse the side panel when only the metabox + label-less content
      // would remain.  This keeps the page narrow when the user only wanted
      // Export and pushed it under the chart.
      // Skip the collapse for type(barrace): the bar-chart-race renderer
      // inserts its own Race/Play/Pause/Replay controls into #controls AFTER
      // buildControls() runs, so a premature no-sidebar would hide them.
      var ctrlChildren = controlsRoot.node().children;
      var nonMeta = 0;
      for (var i = 0; i < ctrlChildren.length; i++) {
        if (!d3.select(ctrlChildren[i]).classed("meta")) nonMeta++;
      }
      if (nonMeta === 0 && meta.type !== "barrace") {
        controlsRoot.classed("empty", true);
        d3.select(".panels").classed("no-sidebar", true);
      }
    }
    function updateMetabox() {
      d3.select("#metabox").html("<strong>" + data.length + "</strong> rows");
    }

    // ---- Export menu (PNG/SVG/CSV/Print/View data) --------------------
    function buildExportMenu(root) {
      var wrap = root.append("div").attr("class", "exportmenu");
      var btn = wrap.append("button")
        .attr("type", "button").attr("class", "exportbtn")
        .attr("aria-haspopup", "true").attr("aria-expanded", "false")
        .html("Export &#9662;");
      var menu = wrap.append("div").attr("class", "exportlist").style("display", "none");
      function addItem(label, fn) {
        menu.append("button").attr("type", "button").text(label)
          .on("click", function () { closeMenu(); fn(); });
      }
      function openMenu()  { menu.style("display", "block"); btn.attr("aria-expanded", "true"); }
      function closeMenu() { menu.style("display", "none");  btn.attr("aria-expanded", "false"); }
      btn.on("click", function (ev) {
        ev.stopPropagation();
        if (menu.style("display") === "none") openMenu(); else closeMenu();
      });
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

    function triggerDownload(blob, filename) {
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url; a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(function () { URL.revokeObjectURL(url); }, 5000);
    }

    function downloadPNG() {
      var node = svg.node();
      var clone = node.cloneNode(true);
      clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
      clone.setAttribute("width",  W);
      clone.setAttribute("height", H);
      var styleEl = document.createElementNS("http://www.w3.org/2000/svg", "style");
      styleEl.textContent = collectInlineCSS();
      clone.insertBefore(styleEl, clone.firstChild);
      var svgText = new XMLSerializer().serializeToString(clone);
      var url = "data:image/svg+xml;charset=utf-8;base64," + btoa(unescape(encodeURIComponent(svgText)));
      var img = new Image();
      img.onload = function () {
        var canvas = document.createElement("canvas");
        var scale = 2;
        canvas.width  = W * scale;
        canvas.height = H * scale;
        var ctx = canvas.getContext("2d");
        ctx.fillStyle = "#ffffff";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.drawImage(img, 0, 0, W * scale, H * scale);
        canvas.toBlob(function (blob) {
          triggerDownload(blob, "sparkta2_" + (meta.type || "chart") + ".png");
        });
      };
      img.src = url;
    }
    function downloadSVG() {
      var node = svg.node();
      var clone = node.cloneNode(true);
      clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
      clone.setAttribute("width",  W);
      clone.setAttribute("height", H);
      var styleEl = document.createElementNS("http://www.w3.org/2000/svg", "style");
      styleEl.textContent = collectInlineCSS();
      clone.insertBefore(styleEl, clone.firstChild);
      var svgText = new XMLSerializer().serializeToString(clone);
      var blob = new Blob([svgText], { type: "image/svg+xml;charset=utf-8" });
      triggerDownload(blob, "sparkta2_" + (meta.type || "chart") + ".svg");
    }
    function collectInlineCSS() {
      return [
        ".axis text{font:11px sans-serif;fill:#475569}",
        ".axis path,.axis line{stroke:#cbd5e1}",
        ".bar{stroke:#fff;stroke-width:.5px}",
        ".slice{stroke:#fff;stroke-width:1.5px}",
        ".label{font:11px sans-serif;fill:#1f2937}",
        ".label-light{fill:#fff}",
        ".item-label{font:12px sans-serif;fill:#1f2937}",
        ".legend text{font:11px sans-serif;fill:#334155}",
        ".zero{stroke:#475569;stroke-width:1px}",
        "text{font-family:-apple-system,sans-serif}"
      ].join("");
    }

    function downloadCSV() {
      if (!data.length) { alert("No data to download."); return; }
      var keys = Object.keys(data[0]);
      var core = ["name", "g", "lev", "t", "x", "y"];
      var tCols = keys.filter(function (k) { return k.indexOf("t__") === 0; });
      var ordered = core.filter(function (k) { return keys.indexOf(k) >= 0; }).concat(tCols);
      function head(k) {
        if (k.indexOf("t__") === 0) return k.slice(3);
        if (k === "name") return meta.name || "name";
        if (k === "g")    return meta.over || "group";
        if (k === "lev")  return meta.level || "level";
        if (k === "t")    return meta.time || "time";
        if (k === "x")    return meta.xvar || "x";
        if (k === "y")    return meta.yvar || "y";
        return k;
      }
      function cell(v) {
        if (v == null) return "";
        var s = String(v);
        if (s.indexOf(",") >= 0 || s.indexOf("\"") >= 0 || s.indexOf("\n") >= 0)
          return "\"" + s.replace(/"/g, "\"\"") + "\"";
        return s;
      }
      var lines = [ ordered.map(head).map(cell).join(",") ];
      data.forEach(function (r) {
        lines.push(ordered.map(function (k) { return cell(r[k]); }).join(","));
      });
      var blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8" });
      triggerDownload(blob, "sparkta2_" + (meta.type || "chart") + "_data.csv");
    }

    function toggleDataTable() {
      var host = d3.select("#datatable");
      if (host.empty()) return;
      if (host.classed("open")) {
        host.classed("open", false).style("display", "none").html("");
        return;
      }
      var keys = data.length ? Object.keys(data[0]) : [];
      var core = ["name", "g", "lev", "t", "x", "y"];
      var tCols = keys.filter(function (k) { return k.indexOf("t__") === 0; });
      var ordered = core.filter(function (k) { return keys.indexOf(k) >= 0; }).concat(tCols);
      function head(k) {
        if (k.indexOf("t__") === 0) return k.slice(3);
        if (k === "name") return meta.name || "name";
        if (k === "g")    return meta.over || "group";
        if (k === "lev")  return meta.level || "level";
        if (k === "t")    return meta.time || "time";
        if (k === "x")    return meta.xvar || "x";
        if (k === "y")    return meta.yvar || "y";
        return k;
      }
      var html = "<div class='dt-header'><strong>Data behind the chart</strong> "
        + "<span class='dt-count'>" + data.length + " rows</span>"
        + "<button type='button' class='dt-close' aria-label='Close'>&times;</button></div>";
      html += "<div class='dt-scroll'><table class='dt-table'><thead><tr>";
      ordered.forEach(function (k) { html += "<th>" + esc(head(k)) + "</th>"; });
      html += "</tr></thead><tbody>";
      var MAX = 500;
      data.slice(0, MAX).forEach(function (r) {
        html += "<tr>";
        ordered.forEach(function (k) {
          var v = r[k];
          html += "<td>" + esc(v == null ? "" : v) + "</td>";
        });
        html += "</tr>";
      });
      html += "</tbody></table></div>";
      if (data.length > MAX) {
        html += "<div class='dt-truncated'>Showing first " + MAX + " of "
          + data.length + " rows — use <em>Download CSV</em> for the full set.</div>";
      }
      host.html(html).classed("open", true).style("display", "block");
      host.select(".dt-close").on("click", toggleDataTable);
    }
    function printToPDF() { window.print(); }

    // ---- Dispatch to the per-type renderer ----------------------------
    var renderType = (meta.type || "donut").toLowerCase();
    var rendered;
    if      (renderType === "donut")   rendered = renderDonut();
    else if (renderType === "bar")     rendered = renderBar();
    else if (renderType === "line")    rendered = renderLine();
    else if (renderType === "divbar")  rendered = renderDivbar();
    else if (renderType === "barrace") rendered = renderBarrace();
    else {
      svg.append("text").attr("x", 24).attr("y", 24)
        .text("sparkta2_chart: type(" + renderType + ") not recognised.");
      return;
    }
    setupAnimateOnView(rendered);

    // ---- IntersectionObserver-driven entry animation -----------------
    function setupAnimateOnView(animTargets) {
      if (!meta.animate || !animTargets) return;
      if (typeof IntersectionObserver === "undefined") {
        runEntryAnim(animTargets); return;
      }
      var fired = false;
      var target = document.getElementById("chart");
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting && !fired) {
            fired = true; io.disconnect();
            runEntryAnim(animTargets);
          }
        });
      }, { threshold: 0.2 });
      io.observe(target);
    }
    function runEntryAnim(targets) {
      // Each entry: { selection, fromAttr, finalAttr?, duration, stagger? }
      //
      // Implementation: capture each node's pre-animation value for every
      // key listed in fromAttr.  We key the capture on the DOM node itself
      // (via a WeakMap) so it works for selections that span multiple parent
      // groups -- e.g. a stacked-bar selection where the per-group .each
      // index i would otherwise collide across series.
      if (!Array.isArray(targets)) targets = [targets];
      targets.forEach(function (t) {
        if (!t || !t.selection || t.selection.empty()) return;
        var dur = t.duration || 600;
        var stagger = t.stagger || 0;
        var sel = t.selection;
        var captureMap = new WeakMap();
        var counter = 0;
        if (t.fromAttr) {
          var keys = Object.keys(t.fromAttr);
          sel.each(function () {
            var rec = {};
            for (var ki = 0; ki < keys.length; ki++) {
              rec[keys[ki]] = d3.select(this).attr(keys[ki]);
            }
            rec.__order = counter++;
            captureMap.set(this, rec);
          });
          keys.forEach(function (k) { sel.attr(k, t.fromAttr[k]); });
        }
        var tr = sel.transition()
          .duration(dur)
          .delay(function () {
            var rec = captureMap.get(this);
            return Math.min(dur, (rec ? rec.__order : 0) * stagger);
          });
        if (t.fromAttr) {
          Object.keys(t.fromAttr).forEach(function (k) {
            tr.attr(k, function () {
              var rec = captureMap.get(this);
              return rec ? rec[k] : d3.select(this).attr(k);
            });
          });
        }
        if (t.finalAttr) {
          Object.keys(t.finalAttr).forEach(function (k) {
            tr.attr(k, t.finalAttr[k]);
          });
        }
      });
    }

    // -----------------------------------------------------------------
    //                   DONUT
    // -----------------------------------------------------------------
    function renderDonut() {
      svg.selectAll("*").remove();
      var pad = 24;
      var legendW = 220;
      var innerW = W - legendW - pad * 2;
      var innerH = H - pad * 2;
      var R = Math.min(innerW, innerH) / 2 - 8;
      var ir = Math.max(0, Math.min(0.92, +meta.innerradius || 0.55));
      var cx = pad + innerW / 2;
      var cy = pad + innerH / 2;

      // Color palette
      var palette = seqScheme(meta.scheme || "tx2036", Math.max(3, data.length));
      if (palette.length < data.length) {
        // Extend palette by interpolating
        var ext = d3.range(data.length).map(function (i) {
          return d3.interpolateRgb(palette[0], palette[palette.length - 1])(i / Math.max(1, data.length - 1));
        });
        palette = ext;
      }
      var total = d3.sum(data, function (d) { return +d.x; });

      var pie = d3.pie().sort(null).value(function (d) { return +d.x; });
      var arc = d3.arc().innerRadius(R * ir).outerRadius(R);
      var labelArc = d3.arc().innerRadius(R * (ir + (1 - ir) * 0.55))
                             .outerRadius(R * (ir + (1 - ir) * 0.55));

      var slices = svg.append("g")
        .attr("transform", "translate(" + cx + "," + cy + ")")
        .selectAll("path.slice").data(pie(data)).enter().append("path")
          .attr("class", "slice")
          .attr("d", arc)
          .attr("fill", function (d, i) { return palette[i]; })
        .on("mousemove", function (ev, d) {
          var pct = total ? (100 * d.value / total) : 0;
          var lines = [
            "<strong>" + esc(d.data.name || "Slice") + "</strong>",
            "Value: " + fmt(d.value) + " (" + fmtPct(pct) + ")"
          ];
          appendTipvars(d.data, lines);
          showTip(lines.join("<br/>"), ev);
        })
        .on("mouseleave", hideTip);

      // Slice labels: inside if the slice is large enough, otherwise skip
      svg.append("g")
        .attr("transform", "translate(" + cx + "," + cy + ")")
        .selectAll("text.label").data(pie(data)).enter().append("text")
          .attr("class", "label")
          .attr("transform", function (d) { return "translate(" + labelArc.centroid(d) + ")"; })
          .attr("text-anchor", "middle")
          .attr("dominant-baseline", "middle")
          .each(function (d, i) {
            var pct = total ? (100 * d.value / total) : 0;
            var arcLen = (d.endAngle - d.startAngle) * R;
            if (arcLen < 40 || pct < 4) return;  // skip too-small slices
            var fill = labelFill(palette[i]);
            d3.select(this)
              .style("fill", fill)
              .append("tspan").attr("x", 0).attr("dy", "-.3em")
              .style("font-weight", 600).text(d.data.name || "");
            d3.select(this).append("tspan").attr("x", 0).attr("dy", "1.1em")
              .style("font-size", "10px").text(d3.format(".0f")(pct) + "%");
          });

      // Center label
      if (ir > 0.25) {
        var centerG = svg.append("g")
          .attr("transform", "translate(" + cx + "," + cy + ")")
          .attr("text-anchor", "middle");
        centerG.append("text").attr("class", "label")
          .style("font-size", "20px").style("font-weight", 600).style("fill", "#1f2937")
          .attr("dy", "-.1em").text(fmt(total));
        centerG.append("text").attr("class", "label")
          .style("font-size", "11px").style("fill", "#6c7a8d")
          .attr("dy", "1.2em").text("Total");
      }

      // Legend
      var lg = svg.append("g").attr("class", "legend")
        .attr("transform", "translate(" + (W - legendW - 8) + "," + (pad + 6) + ")");
      data.forEach(function (d, i) {
        var row = lg.append("g").attr("transform", "translate(0," + (i * 18) + ")");
        row.append("rect").attr("width", 12).attr("height", 12).attr("fill", palette[i]).attr("rx", 2);
        var pct = total ? (100 * d.x / total) : 0;
        row.append("text").attr("x", 18).attr("y", 10)
          .text(esc(d.name || "") + "  " + fmt(+d.x) + " (" + d3.format(".1f")(pct) + "%)");
      });

      return [{ selection: slices, fromAttr: { opacity: 0 }, finalAttr: { opacity: 1 }, duration: 600, stagger: 60 }];
    }

    // -----------------------------------------------------------------
    //                   BAR (vertical / horizontal, grouped / stacked / normalize)
    // -----------------------------------------------------------------
    function renderBar() {
      svg.selectAll("*").remove();
      var horiz = !!meta.horizontal;
      var stacked = !!meta.stacked;
      var normalize = !!meta.normalize;
      var hasOver = !!meta.over;

      // Categories preserve input order
      var cats = [];
      data.forEach(function (d) {
        if (cats.indexOf(d.name) < 0) cats.push(d.name);
      });

      // Label-wrap resolution (v0.7.3).  User-facing options:
      //   meta.labelwrap = "auto" (default) | "on" | "off"
      //   meta.labelwidth = explicit left-margin px (0 = use defaults)
      // "auto" keeps the character-count heuristic: wrap iff the longest
      // label exceeds ~28 chars on a horizontal single-series bar.
      // "on" / "off" force the behaviour; "off" truncates with an ellipsis
      // when a label would overflow the gutter.
      var maxLabelLen = cats.reduce(function (m, c) {
        return Math.max(m, String(c || "").length);
      }, 0);
      var lwMode = (meta.labelwrap || "auto").toLowerCase();
      var useWrappedLabels;
      if      (lwMode === "on")  useWrappedLabels = horiz && !hasOver;
      else if (lwMode === "off") useWrappedLabels = false;
      else                        useWrappedLabels = horiz && !hasOver && maxLabelLen > 28;
      var lwOverride = +meta.labelwidth || 0;
      var leftMargin;
      if (lwOverride > 0) leftMargin = lwOverride;
      else                 leftMargin = horiz ? (useWrappedLabels ? 300 : 160) : 64;

      var margin = horiz
        ? { top: 24, right: 24, bottom: 36, left: leftMargin }
        : { top: 24, right: 24, bottom: 60, left: leftMargin };
      var iw = W - margin.left - margin.right;
      var ih = H - margin.top  - margin.bottom;
      var g = svg.append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");

      var entered;  // selection of bar rects, returned for animate

      if (!hasOver) {
        // Simple single-series bar
        var palette = seqScheme(meta.scheme || "blues", 9);
        var color = palette[Math.floor(palette.length / 2)];
        var scaleVal = d3.scaleLinear().nice()
          .domain([0, d3.max(data, function (d) { return +d.x; }) || 1]);
        if (horiz) {
          var yScale = d3.scaleBand().domain(cats).range([0, ih]).padding(0.18);
          scaleVal.range([0, iw]);
          if (useWrappedLabels) {
            // Hand-render wrapped labels instead of using d3.axisLeft, so
            // long survey-item names wrap to 2-3 lines and stay readable.
            var lbls = g.append("g").attr("class", "item-labels");
            cats.forEach(function (c) {
              var y = yScale(c) + yScale.bandwidth() / 2;
              var t = lbls.append("text")
                .attr("class", "item-label")
                .attr("x", -10).attr("y", y)
                .attr("text-anchor", "end")
                .attr("dominant-baseline", "middle");
              wrapText(t, c, margin.left - 20);
            });
          } else if (lwMode === "off") {
            // labelwrap(off): hand-render single-line labels with ellipsis
            // truncation if a label exceeds the gutter.
            var lblsT = g.append("g").attr("class", "item-labels");
            cats.forEach(function (c) {
              var y = yScale(c) + yScale.bandwidth() / 2;
              var t = lblsT.append("text")
                .attr("class", "item-label")
                .attr("x", -10).attr("y", y)
                .attr("text-anchor", "end");
              truncateText(t, c, margin.left - 20);
            });
          } else {
            g.append("g").attr("class", "axis")
              .call(d3.axisLeft(yScale));
          }
          g.append("g").attr("class", "axis")
            .attr("transform", "translate(0," + ih + ")")
            .call(d3.axisBottom(scaleVal).ticks(6));
          entered = g.selectAll("rect.bar").data(data).enter().append("rect")
            .attr("class", "bar")
            .attr("x", 0)
            .attr("y", function (d) { return yScale(d.name); })
            .attr("width",  function (d) { return scaleVal(+d.x); })
            .attr("height", yScale.bandwidth())
            .attr("fill", color);
        } else {
          var xScale = d3.scaleBand().domain(cats).range([0, iw]).padding(0.18);
          scaleVal.range([ih, 0]);
          g.append("g").attr("class", "axis")
            .attr("transform", "translate(0," + ih + ")")
            .call(d3.axisBottom(xScale))
            .selectAll("text").attr("transform", "rotate(-20)").attr("text-anchor", "end");
          g.append("g").attr("class", "axis")
            .call(d3.axisLeft(scaleVal).ticks(6));
          entered = g.selectAll("rect.bar").data(data).enter().append("rect")
            .attr("class", "bar")
            .attr("x", function (d) { return xScale(d.name); })
            .attr("y", function (d) { return scaleVal(+d.x); })
            .attr("width",  xScale.bandwidth())
            .attr("height", function (d) { return ih - scaleVal(+d.x); })
            .attr("fill", color);
        }
        entered.on("mousemove", function (ev, d) {
          var lines = ["<strong>" + esc(d.name) + "</strong>",
                       (meta.xlabel || meta.xvar || "Value") + ": " + fmt(+d.x)];
          appendTipvars(d, lines);
          showTip(lines.join("<br/>"), ev);
        }).on("mouseleave", hideTip);
      }
      else {
        // Grouped or stacked: data is long form { name, g, x }
        // Build groups (over distinct values)
        var groups = [];
        data.forEach(function (d) { if (groups.indexOf(d.g) < 0) groups.push(d.g); });
        var palette = seqScheme(meta.scheme || "blues", Math.max(3, groups.length));
        if (palette.length < groups.length) {
          palette = d3.range(groups.length).map(function (i) {
            return d3.interpolateRgb(palette[0], palette[palette.length - 1])(i / Math.max(1, groups.length - 1));
          });
        }
        var color = d3.scaleOrdinal().domain(groups).range(palette);

        // Reshape long -> wide for d3.stack
        var byCat = {};
        cats.forEach(function (c) { byCat[c] = { name: c }; groups.forEach(function (gN) { byCat[c][gN] = 0; }); });
        data.forEach(function (d) { byCat[d.name][d.g] = +d.x; });
        var wide = cats.map(function (c) { return byCat[c]; });

        if (normalize) {
          wide.forEach(function (row) {
            var s = d3.sum(groups, function (gN) { return +row[gN]; });
            if (s > 0) groups.forEach(function (gN) { row[gN] = row[gN] / s * 100; });
          });
        }

        if (stacked) {
          var stack = d3.stack().keys(groups);
          var series = stack(wide);
          var maxV = normalize ? 100 : d3.max(series[series.length - 1], function (d) { return d[1]; });
          if (horiz) {
            var yScale2 = d3.scaleBand().domain(cats).range([0, ih]).padding(0.18);
            var xScale2 = d3.scaleLinear().domain([0, maxV]).nice().range([0, iw]);
            g.append("g").attr("class", "axis").call(d3.axisLeft(yScale2));
            g.append("g").attr("class", "axis").attr("transform", "translate(0," + ih + ")")
              .call(d3.axisBottom(xScale2).ticks(6).tickFormat(normalize ? function (d) { return d + "%"; } : null));
            var grp = g.selectAll("g.series").data(series).enter().append("g")
              .attr("class", "series").attr("fill", function (d) { return color(d.key); });
            entered = grp.selectAll("rect").data(function (d) { return d.map(function (v) { v.key = d.key; return v; }); })
              .enter().append("rect").attr("class", "bar")
                .attr("y", function (d) { return yScale2(d.data.name); })
                .attr("height", yScale2.bandwidth())
                .attr("x", function (d) { return xScale2(d[0]); })
                .attr("width", function (d) { return xScale2(d[1]) - xScale2(d[0]); });
            entered.on("mousemove", function (ev, d) {
              var lines = ["<strong>" + esc(d.data.name) + "</strong>",
                           esc(d.key) + ": " + (normalize ? fmtPct(d.data[d.key]) : fmt(d.data[d.key]))];
              showTip(lines.join("<br/>"), ev);
            }).on("mouseleave", hideTip);
          } else {
            var xScale3 = d3.scaleBand().domain(cats).range([0, iw]).padding(0.18);
            var yScale3 = d3.scaleLinear().domain([0, maxV]).nice().range([ih, 0]);
            g.append("g").attr("class", "axis").attr("transform", "translate(0," + ih + ")")
              .call(d3.axisBottom(xScale3))
              .selectAll("text").attr("transform", "rotate(-20)").attr("text-anchor", "end");
            g.append("g").attr("class", "axis").call(d3.axisLeft(yScale3).ticks(6)
              .tickFormat(normalize ? function (d) { return d + "%"; } : null));
            var grp2 = g.selectAll("g.series").data(series).enter().append("g")
              .attr("class", "series").attr("fill", function (d) { return color(d.key); });
            entered = grp2.selectAll("rect").data(function (d) { return d.map(function (v) { v.key = d.key; return v; }); })
              .enter().append("rect").attr("class", "bar")
                .attr("x", function (d) { return xScale3(d.data.name); })
                .attr("width", xScale3.bandwidth())
                .attr("y", function (d) { return yScale3(d[1]); })
                .attr("height", function (d) { return yScale3(d[0]) - yScale3(d[1]); });
            entered.on("mousemove", function (ev, d) {
              var lines = ["<strong>" + esc(d.data.name) + "</strong>",
                           esc(d.key) + ": " + (normalize ? fmtPct(d.data[d.key]) : fmt(d.data[d.key]))];
              showTip(lines.join("<br/>"), ev);
            }).on("mouseleave", hideTip);
          }
        }
        else {
          // Grouped (side-by-side)
          var maxV2 = d3.max(data, function (d) { return +d.x; }) || 1;
          if (horiz) {
            var y0 = d3.scaleBand().domain(cats).range([0, ih]).padding(0.18);
            var y1 = d3.scaleBand().domain(groups).range([0, y0.bandwidth()]).padding(0.05);
            var x1 = d3.scaleLinear().domain([0, maxV2]).nice().range([0, iw]);
            g.append("g").attr("class", "axis").call(d3.axisLeft(y0));
            g.append("g").attr("class", "axis").attr("transform", "translate(0," + ih + ")")
              .call(d3.axisBottom(x1).ticks(6));
            entered = g.selectAll("rect.bar").data(data).enter().append("rect")
              .attr("class", "bar")
              .attr("x", 0)
              .attr("y", function (d) { return y0(d.name) + y1(d.g); })
              .attr("height", y1.bandwidth())
              .attr("width", function (d) { return x1(+d.x); })
              .attr("fill", function (d) { return color(d.g); });
          } else {
            var x0 = d3.scaleBand().domain(cats).range([0, iw]).padding(0.18);
            var xg = d3.scaleBand().domain(groups).range([0, x0.bandwidth()]).padding(0.05);
            var yg = d3.scaleLinear().domain([0, maxV2]).nice().range([ih, 0]);
            g.append("g").attr("class", "axis").attr("transform", "translate(0," + ih + ")")
              .call(d3.axisBottom(x0))
              .selectAll("text").attr("transform", "rotate(-20)").attr("text-anchor", "end");
            g.append("g").attr("class", "axis").call(d3.axisLeft(yg).ticks(6));
            entered = g.selectAll("rect.bar").data(data).enter().append("rect")
              .attr("class", "bar")
              .attr("x", function (d) { return x0(d.name) + xg(d.g); })
              .attr("y", function (d) { return yg(+d.x); })
              .attr("width", xg.bandwidth())
              .attr("height", function (d) { return ih - yg(+d.x); })
              .attr("fill", function (d) { return color(d.g); });
          }
          entered.on("mousemove", function (ev, d) {
            var lines = ["<strong>" + esc(d.name) + "</strong>",
                         esc(d.g) + ": " + fmt(+d.x)];
            appendTipvars(d, lines);
            showTip(lines.join("<br/>"), ev);
          }).on("mouseleave", hideTip);
        }
        // Legend
        var lg2 = svg.append("g").attr("class", "legend")
          .attr("transform", "translate(" + (margin.left) + "," + 6 + ")");
        groups.forEach(function (gN, i) {
          var row = lg2.append("g").attr("transform", "translate(" + (i * 110) + ",0)");
          row.append("rect").attr("width", 12).attr("height", 12).attr("fill", color(gN)).attr("rx", 2);
          row.append("text").attr("x", 18).attr("y", 10).text(esc(gN));
        });
      }

      // Entry animation: bars grow from zero
      var fromAttr = horiz ? { width: 0 } : { height: 0, y: ih };
      return [{ selection: entered, fromAttr: fromAttr, finalAttr: {}, duration: 700, stagger: 40 }];
    }

    // -----------------------------------------------------------------
    //                   LINE (multi-series)
    // -----------------------------------------------------------------
    function renderLine() {
      svg.selectAll("*").remove();
      var margin = { top: 24, right: 24, bottom: 44, left: 60 };
      var iw = W - margin.left - margin.right;
      var ih = H - margin.top  - margin.bottom;
      var g = svg.append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");

      var hasSeries = !!meta.over;
      var bySeries = {};
      if (hasSeries) {
        data.forEach(function (d) {
          var s = d.g || "";
          (bySeries[s] = bySeries[s] || []).push(d);
        });
      } else {
        bySeries[""] = data.slice();
      }
      // Sort each series by x ascending
      Object.keys(bySeries).forEach(function (k) {
        bySeries[k].sort(function (a, b) { return (+a.y) - (+b.y); });
      });
      var seriesKeys = Object.keys(bySeries);

      var palette = seqScheme(meta.scheme || "blues", Math.max(3, seriesKeys.length));
      if (palette.length < seriesKeys.length) {
        palette = d3.range(seriesKeys.length).map(function (i) {
          return d3.interpolateRgb(palette[0], palette[palette.length - 1])(i / Math.max(1, seriesKeys.length - 1));
        });
      }
      var color = d3.scaleOrdinal().domain(seriesKeys).range(palette);

      var xs = d3.scaleLinear()
        .domain(d3.extent(data, function (d) { return +d.y; }))
        .nice().range([0, iw]);
      var ys = d3.scaleLinear()
        .domain([0, d3.max(data, function (d) { return +d.x; })])
        .nice().range([ih, 0]);

      g.append("g").attr("class", "axis").attr("transform", "translate(0," + ih + ")")
        .call(d3.axisBottom(xs).ticks(7));
      g.append("g").attr("class", "axis")
        .call(d3.axisLeft(ys).ticks(6));

      var lineGen = d3.line()
        .x(function (d) { return xs(+d.y); })
        .y(function (d) { return ys(+d.x); })
        .curve(d3.curveMonotoneX);

      var allPaths = [];
      seriesKeys.forEach(function (k) {
        var arr = bySeries[k];
        var path = g.append("path").datum(arr)
          .attr("fill", "none")
          .attr("stroke", color(k))
          .attr("stroke-width", 2.2)
          .attr("d", lineGen);
        allPaths.push(path);
        // Endpoint dots for hover
        g.selectAll("circle.dot-" + k.replace(/\W/g, "_")).data(arr).enter().append("circle")
          .attr("class", "dot")
          .attr("cx", function (d) { return xs(+d.y); })
          .attr("cy", function (d) { return ys(+d.x); })
          .attr("r", 3).attr("fill", color(k)).attr("stroke", "#fff").attr("stroke-width", 0.6)
          .on("mousemove", function (ev, d) {
            var lines = [];
            if (hasSeries) lines.push("<strong>" + esc(d.g) + "</strong>");
            lines.push((meta.xvar || "x") + ": " + fmt(+d.y));
            lines.push((meta.yvar || meta.xlabel || "y") + ": " + fmt(+d.x));
            appendTipvars(d, lines);
            showTip(lines.join("<br/>"), ev);
          }).on("mouseleave", hideTip);
      });

      if (hasSeries) {
        var lg3 = svg.append("g").attr("class", "legend")
          .attr("transform", "translate(" + (margin.left + 8) + "," + 6 + ")");
        seriesKeys.forEach(function (k, i) {
          var row = lg3.append("g").attr("transform", "translate(" + (i * 110) + ",0)");
          row.append("rect").attr("width", 12).attr("height", 12).attr("fill", color(k)).attr("rx", 2);
          row.append("text").attr("x", 18).attr("y", 10).text(esc(k));
        });
      }

      // Entry animation: dots fade in.  The lines themselves are always
      // visible -- a stroke-dasharray reveal looks slick on simple charts
      // but interacts poorly with d3 transitions that need numeric
      // interpolation of a style-vs-attribute property, and the fade-in
      // pairs better with the points-on-line tooltip targets anyway.
      var dotSel = svg.selectAll("circle.dot");
      return [{ selection: dotSel, fromAttr: { opacity: 0 }, finalAttr: { opacity: 1 },
                duration: 700, stagger: 25 }];
    }

    // -----------------------------------------------------------------
    //                   DIVBAR (Pew-style diverging stacked bar)
    // -----------------------------------------------------------------
    function renderDivbar() {
      svg.selectAll("*").remove();
      // Label-wrap resolution.  divbar defaults to wrap=on (Pew-style) but
      // user can pass labelwrap(off) to truncate, and labelwidth(N) to
      // override the gutter width.
      var lwModeD = (meta.labelwrap || "auto").toLowerCase();
      var divDoWrap = (lwModeD !== "off");
      var divLeftOverride = +meta.labelwidth || 0;
      // Generous left margin to host wrapped survey-item text; works well
      // up to ~80-character items with two-line wrap.  Right margin
      // reserves space for the Net (+/-) annotation column.
      var margin = { top: 60, right: 90, bottom: 14,
                     left: (divLeftOverride > 0 ? divLeftOverride : 300) };
      var iw = W - margin.left - margin.right;
      var ih = H - margin.top  - margin.bottom;
      var g = svg.append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");

      // Required: name() is item, lev is response level, x is share.
      // Build items in input order, levels per meta.levelorder() or first-seen.
      var items = [];
      data.forEach(function (d) { if (items.indexOf(d.name) < 0) items.push(d.name); });

      var levels;
      if (meta.levelorder) {
        levels = meta.levelorder.split("|").filter(Boolean);
      } else {
        levels = [];
        data.forEach(function (d) { if (levels.indexOf(d.lev) < 0) levels.push(d.lev); });
      }
      // Center level: default is the middle of the list when odd count;
      // when even, divide between the two middle ones (no level centered).
      var centerLevel = meta.centerlevel || (levels.length % 2 === 1 ? levels[Math.floor(levels.length/2)] : null);

      // Diverging palette: assign red shades to the "negative" levels (those
      // before center) and blue shades to the "positive" levels (after).
      // The center level (if any) gets a neutral fill.
      var negLevels = [], posLevels = [];
      var negPart = true;
      levels.forEach(function (lv) {
        if (lv === centerLevel) { negPart = false; return; }
        if (negPart) negLevels.push(lv);
        else         posLevels.push(lv);
      });
      // Build color map
      var divPalNeg = d3.range(Math.max(1, negLevels.length)).map(function (i, _, arr) {
        return d3.interpolateRdBu(0.05 + 0.35 * (negLevels.length === 1 ? 0.5 : i / (negLevels.length - 1)));
      });
      var divPalPos = d3.range(Math.max(1, posLevels.length)).map(function (i) {
        return d3.interpolateRdBu(0.6 + 0.35 * (posLevels.length === 1 ? 0.5 : i / (posLevels.length - 1)));
      });
      var colorMap = {};
      negLevels.forEach(function (lv, i) { colorMap[lv] = divPalNeg[i]; });
      posLevels.forEach(function (lv, i) { colorMap[lv] = divPalPos[i]; });
      if (centerLevel) colorMap[centerLevel] = "#e2e8f0";

      // Reshape to wide per item: { item: { level: share } }
      var byItem = {};
      items.forEach(function (it) { byItem[it] = { name: it }; levels.forEach(function (lv) { byItem[it][lv] = 0; }); });
      data.forEach(function (d) { byItem[d.name][d.lev] = +d.x; });

      // For each item, compute left-offset (negative side total + half of center)
      var maxAbs = 0;
      items.forEach(function (it) {
        var negSum = negLevels.reduce(function (s, lv) { return s + (+byItem[it][lv]); }, 0);
        var ctrSum = centerLevel ? (+byItem[it][centerLevel]) : 0;
        var posSum = posLevels.reduce(function (s, lv) { return s + (+byItem[it][lv]); }, 0);
        byItem[it].__neg = negSum + ctrSum / 2;
        byItem[it].__pos = posSum + ctrSum / 2;
        if (byItem[it].__neg > maxAbs) maxAbs = byItem[it].__neg;
        if (byItem[it].__pos > maxAbs) maxAbs = byItem[it].__pos;
      });
      // Round up to a clean axis bound
      var bound = Math.ceil(maxAbs / 10) * 10;
      if (bound < maxAbs) bound = maxAbs * 1.05;

      var xs = d3.scaleLinear().domain([-bound, bound]).range([0, iw]);
      var ys = d3.scaleBand().domain(items).range([0, ih]).padding(0.28);

      // Item labels on the LEFT.  Default: wrap multi-line (Pew style);
      // labelwrap(off) switches to truncate-with-ellipsis on a single line.
      var itemLabel = g.append("g").attr("class", "item-labels");
      items.forEach(function (it) {
        var y = ys(it) + ys.bandwidth() / 2;
        var t = itemLabel.append("text")
          .attr("class", "item-label")
          .attr("x", -10).attr("y", y)
          .attr("text-anchor", "end")
          .attr("dominant-baseline", "middle");
        if (divDoWrap) wrapText(t, it, margin.left - 20);
        else           truncateText(t, it, margin.left - 20);
      });

      // Bars: for each item, render segments
      var bars = g.append("g");
      var enteredSegs = [];
      items.forEach(function (it) {
        var xCursor = -byItem[it].__neg;  // start at left edge of negatives
        levels.forEach(function (lv) {
          var v = +byItem[it][lv];
          if (v === 0) return;
          var seg = bars.append("rect")
            .attr("class", "bar")
            .datum({ item: it, level: lv, value: v })
            .attr("x", xs(xCursor))
            .attr("width", xs(xCursor + v) - xs(xCursor))
            .attr("y", ys(it))
            .attr("height", ys.bandwidth())
            .attr("fill", colorMap[lv]);
          seg.on("mousemove", function (ev, d) {
            var lines = [
              "<strong>" + esc(d.item) + "</strong>",
              esc(d.level) + ": " + fmtPct(d.value)
            ];
            showTip(lines.join("<br/>"), ev);
          }).on("mouseleave", hideTip);

          // Direct labels inside each segment if wide enough
          if (meta.directlabels) {
            var segPx = xs(xCursor + v) - xs(xCursor);
            if (segPx >= 28) {
              var lbl = g.append("text")
                .attr("class", "label")
                .attr("x", xs(xCursor + v / 2))
                .attr("y", ys(it) + ys.bandwidth() / 2)
                .attr("text-anchor", "middle")
                .attr("dominant-baseline", "middle")
                .style("fill", labelFill(colorMap[lv]))
                .text(d3.format(".0f")(v) + "%");
            }
          }
          enteredSegs.push(seg.node());
          xCursor += v;
        });
        // Net favorability label to the right of the bar
        if (meta.directlabels) {
          var net = byItem[it].__pos - byItem[it].__neg;
          g.append("text")
            .attr("class", "label")
            .attr("x", iw + 8).attr("y", ys(it) + ys.bandwidth() / 2)
            .attr("text-anchor", "start")
            .attr("dominant-baseline", "middle")
            .style("font-weight", 600)
            .style("fill", net > 0 ? "#0f5c8f" : (net < 0 ? "#b34a3a" : "#475569"))
            .text((net > 0 ? "+" : "") + d3.format(".0f")(net));
        }
      });

      // Central zero baseline (Pew-style)
      g.append("line").attr("class", "zero")
        .attr("x1", xs(0)).attr("x2", xs(0))
        .attr("y1", -8).attr("y2", ih + 4);

      // Legend at top
      var lg4 = svg.append("g").attr("class", "legend")
        .attr("transform", "translate(" + (margin.left) + "," + 16 + ")");
      var legX = 0;
      levels.forEach(function (lv) {
        var row = lg4.append("g").attr("transform", "translate(" + legX + ",0)");
        row.append("rect").attr("width", 12).attr("height", 12).attr("fill", colorMap[lv]).attr("rx", 2);
        var t = row.append("text").attr("x", 18).attr("y", 10).text(esc(lv));
        var bbox;
        try { bbox = t.node().getBBox(); } catch (e) { bbox = { width: lv.length * 6 }; }
        legX += 18 + bbox.width + 18;
      });
      // "Net" key
      if (meta.directlabels) {
        svg.append("text").attr("class", "label")
          .attr("x", W - margin.right + 4).attr("y", margin.top - 12)
          .attr("text-anchor", "start").style("font-size", "10px").style("fill", "#6c7a8d")
          .text("Net (+/−)");
      }

      // Suppress bottom axis per Pew style unless user opted in.
      if (!meta.suppressaxis) {
        g.append("g").attr("class", "axis")
          .attr("transform", "translate(0," + (ih + 6) + ")")
          .call(d3.axisBottom(xs).ticks(6).tickFormat(function (d) { return Math.abs(d) + "%"; }));
      }

      // Entry animation: collapse segments to zero width at the zero line
      var segSel = d3.selectAll(enteredSegs);
      return [{
        selection: segSel,
        fromAttr: { width: 0, x: function (d) { return xs(0); } },
        finalAttr: {
          width: function (d, i, nodes) { return d3.select(nodes[i]).attr("width"); },
          x:     function (d, i, nodes) { return d3.select(nodes[i]).attr("x"); }
        },
        duration: 700, stagger: 30
      }];
    }

    // Truncate-with-ellipsis helper: single-line label that fits in maxPx.
    // Uses a binary search on `getComputedTextLength` to find the longest
    // prefix that fits.  No-ops if the full content already fits.
    function truncateText(text, content, maxPx) {
      var full = String(content || "");
      var x = +text.attr("x") || 0;
      text.text(null);
      var tspan = text.append("tspan").attr("x", x).attr("dy", "0.32em");
      tspan.text(full);
      if (tspan.node().getComputedTextLength() <= maxPx) return;
      // Binary search: find the longest prefix length L such that
      // (full.slice(0, L) + "…") fits.
      var lo = 0, hi = full.length;
      while (lo < hi) {
        var mid = Math.ceil((lo + hi) / 2);
        tspan.text(full.slice(0, mid).replace(/\s+$/, "") + "…");
        if (tspan.node().getComputedTextLength() <= maxPx) lo = mid;
        else hi = mid - 1;
      }
      tspan.text(full.slice(0, lo).replace(/\s+$/, "") + "…");
    }

    // Text-wrap helper for long survey items in the left margin.
    // Builds a vertically-centered block of <tspan>s around the text
    // element's original y.  dy on the first tspan shifts the block up
    // by half its height; subsequent tspans use a relative step-down.
    function wrapText(text, content, maxPx) {
      var words = String(content || "").split(/\s+/);
      var lineHeight = 1.1;
      var x = +text.attr("x") || 0;
      text.text(null);

      // Greedy line-fill using a hidden probe tspan so getComputedTextLength
      // can measure as we add words.
      var lines = [];
      var current = [];
      var probe = text.append("tspan").attr("x", x);
      for (var i = 0; i < words.length; i++) {
        current.push(words[i]);
        probe.text(current.join(" "));
        if (probe.node().getComputedTextLength() > maxPx && current.length > 1) {
          current.pop();
          lines.push(current.join(" "));
          current = [words[i]];
        }
      }
      if (current.length) lines.push(current.join(" "));
      probe.remove();

      // Lay out one tspan per line.  First tspan's dy lifts the block so
      // the wrapped text is vertically centered on the original y; each
      // subsequent tspan is one lineHeight below the previous.
      var n = lines.length;
      var firstDy = -((n - 1) / 2) * lineHeight;
      lines.forEach(function (ln, idx) {
        text.append("tspan")
          .attr("x", x)
          .attr("dy", (idx === 0 ? firstDy : lineHeight) + "em")
          .text(ln);
      });
    }

    // -----------------------------------------------------------------
    //                   BARRACE (animated horizontal bar chart over time)
    // -----------------------------------------------------------------
    function renderBarrace() {
      svg.selectAll("*").remove();
      var margin = { top: 30, right: 120, bottom: 24, left: 160 };
      var iw = W - margin.left - margin.right;
      var ih = H - margin.top  - margin.bottom;
      var g = svg.append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");

      // Discover keyframes (sorted unique time values)
      var times = [];
      data.forEach(function (d) {
        var t = +d.t;
        if (Number.isFinite(t) && times.indexOf(t) < 0) times.push(t);
      });
      times.sort(function (a, b) { return a - b; });

      // Per (category, time) value lookup
      var byCatTime = {};
      data.forEach(function (d) {
        var key = d.name + "||" + d.t;
        byCatTime[key] = +d.x;
      });
      var allCats = [];
      data.forEach(function (d) { if (allCats.indexOf(d.name) < 0) allCats.push(d.name); });

      var topN = Math.max(3, +meta.top || 12);

      // Color palette: stable per category by hash-pick from a sequential.
      var pal = seqScheme(meta.scheme || "tx2036", Math.max(10, allCats.length));
      var color = d3.scaleOrdinal().domain(allCats).range(pal);

      // Time-display element
      var timeText = svg.append("text").attr("class", "race-time")
        .attr("x", W - margin.right - 8).attr("y", H - 28).text("");

      var xScale = d3.scaleLinear().range([0, iw]);
      var yScale = d3.scaleBand().range([0, ih]).padding(0.12);
      var axisG  = g.append("g").attr("class", "axis").attr("transform", "translate(0," + ih + ")");

      // Pre-compute per-frame ranking
      function rankAt(t) {
        return allCats.map(function (c) {
          return { name: c, value: byCatTime[c + "||" + t] || 0 };
        }).sort(function (a, b) { return b.value - a.value; }).slice(0, topN);
      }
      var frames = times.map(function (t) { return { t: t, rows: rankAt(t) }; });

      // Initial state: first frame
      var current = frames[0];
      var maxVal = d3.max(current.rows, function (r) { return r.value; });
      xScale.domain([0, maxVal || 1]).nice();
      yScale.domain(current.rows.map(function (r) { return r.name; }));
      timeText.text(current.t);

      axisG.call(d3.axisBottom(xScale).ticks(6));

      // Initial bar group
      var bars = g.append("g").attr("class", "bars");
      var labels = g.append("g").attr("class", "labels");
      var values = g.append("g").attr("class", "values");

      function update(frame, duration) {
        var maxV = d3.max(frame.rows, function (r) { return r.value; }) || 1;
        xScale.domain([0, maxV]).nice();
        yScale.domain(frame.rows.map(function (r) { return r.name; }));

        // BARS
        var bsel = bars.selectAll("rect.bar").data(frame.rows, function (d) { return d.name; });
        bsel.exit().transition().duration(duration).attr("width", 0).remove();
        var bent = bsel.enter().append("rect").attr("class", "bar")
          .attr("x", 0).attr("width", 0)
          .attr("y", function (d) { return yScale(d.name); })
          .attr("height", yScale.bandwidth())
          .attr("fill", function (d) { return color(d.name); });
        bent.merge(bsel).transition().duration(duration).ease(d3.easeLinear)
          .attr("x", 0)
          .attr("y", function (d) { return yScale(d.name); })
          .attr("height", yScale.bandwidth())
          .attr("width", function (d) { return xScale(d.value); });

        // LABEL (category name on left)
        var lsel = labels.selectAll("text.cat").data(frame.rows, function (d) { return d.name; });
        lsel.exit().remove();
        var lent = lsel.enter().append("text").attr("class", "cat item-label")
          .attr("text-anchor", "end")
          .attr("dominant-baseline", "middle")
          .attr("x", -8)
          .attr("y", function (d) { return yScale(d.name) + yScale.bandwidth()/2; })
          .text(function (d) { return d.name; });
        lent.merge(lsel).transition().duration(duration).ease(d3.easeLinear)
          .attr("y", function (d) { return yScale(d.name) + yScale.bandwidth()/2; })
          .text(function (d) { return d.name; });

        // VALUE (number on right end of bar)
        var vsel = values.selectAll("text.val").data(frame.rows, function (d) { return d.name; });
        vsel.exit().remove();
        var vent = vsel.enter().append("text").attr("class", "val label")
          .attr("dominant-baseline", "middle")
          .attr("text-anchor", "start")
          .attr("x", function (d) { return xScale(d.value) + 4; })
          .attr("y", function (d) { return yScale(d.name) + yScale.bandwidth()/2; })
          .text(function (d) { return fmt(d.value); });
        vent.merge(vsel).transition().duration(duration).ease(d3.easeLinear)
          .attr("x", function (d) { return xScale(d.value) + 4; })
          .attr("y", function (d) { return yScale(d.name) + yScale.bandwidth()/2; })
          .tween("text", function (d) {
            var i = d3.interpolateNumber(+this.textContent.replace(/[^0-9.\-]/g, "") || 0, d.value);
            return function (tt) { this.textContent = fmt(i(tt)); };
          });

        axisG.transition().duration(duration).ease(d3.easeLinear)
          .call(d3.axisBottom(xScale).ticks(6));

        timeText.text(frame.t);
      }
      update(current, 0);

      // Playhead controls: play/pause + replay button in the View panel.
      var playState = { idx: 0, playing: true, timer: null };
      var fps = Math.max(1, +meta.fps || 12);
      var totalDuration = Math.max(1, +meta.duration || 25) * 1000;
      var perFrame = totalDuration / Math.max(1, frames.length - 1);
      function step() {
        playState.idx++;
        if (playState.idx >= frames.length) {
          playState.playing = false;
          updatePlayBtn();
          return;
        }
        update(frames[playState.idx], perFrame);
        if (playState.playing) {
          playState.timer = setTimeout(step, perFrame);
        }
      }
      function start() {
        playState.playing = true; updatePlayBtn();
        if (playState.idx >= frames.length - 1) {
          // Restart
          playState.idx = 0;
          update(frames[0], 0);
        }
        playState.timer = setTimeout(step, 300);
      }
      function pause() { playState.playing = false; clearTimeout(playState.timer); updatePlayBtn(); }
      var playBtn = controlsRoot.insert("button", ":first-child")
        .attr("type", "button").style("margin-bottom", "6px")
        .on("click", function () {
          if (playState.playing) pause(); else start();
        });
      var titleH3 = controlsRoot.insert("h3", ":first-child").text("Race");
      function updatePlayBtn() {
        playBtn.text(playState.playing ? "Pause" : (playState.idx >= frames.length - 1 ? "Replay" : "Play"));
      }
      updatePlayBtn();
      // Auto-start
      start();

      return null;  // no IO-driven entry animation; the race itself is the animation
    }
  }

  window.sparkta2RenderChart = render;
})();
