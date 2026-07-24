// hero preset tabs: swap which TOC panel is shown
  (function () {
    var ed = document.querySelector(".editor");
    if (!ed) return;
    var tabs = ed.querySelectorAll(".tab");
    var panels = ed.querySelectorAll(".toc");
    tabs.forEach(function (t) {
      t.addEventListener("click", function () {
        var p = t.getAttribute("data-preset");
        tabs.forEach(function (x) { x.classList.toggle("on", x === t); });
        panels.forEach(function (pl) { pl.hidden = pl.getAttribute("data-preset") !== p; });
      });
    });
  })();

  // hero split: cycle the "cursor" through headings, flashing source + TOC in sync
  (function () {
    var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce) return;
    var seq = ["1", "3", "4", "7", "8", "10"];
    var i = 0;
    function tick() {
      var k = seq[i];
      var rows = document.querySelectorAll(".editor .src .row");
      var ents = document.querySelectorAll(".editor .toc .e");
      rows.forEach(function (r) { r.classList.remove("on", "beacon"); });
      ents.forEach(function (e) { e.classList.remove("on"); });
      var row = document.querySelector('.editor .src .row[data-k="' + k + '"]');
      var ent = document.querySelector('.editor .toc .e[data-k="' + k + '"]');
      if (row) { void row.offsetWidth; row.classList.add("on", "beacon"); }
      if (ent) ent.classList.add("on");
      i = (i + 1) % seq.length;
    }
    if (document.querySelector(".editor")) { tick(); setInterval(tick, 1900); }
  })();

  (function () {
    var ids = ["overview", "install", "config", "usage"];
    var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    function pick(sel) {
      return ids.map(function (id) {
        return document.querySelector(sel + '[data-target="' + id + '"]');
      });
    }
    var tocLinks = pick(".toc-e");
    var menuLinks = pick(".menu a");
    var els = ids.map(function (id) { return document.getElementById(id); });
    var current = null;

    function setActive(id) {
      if (id === current) return;
      current = id;
      ids.forEach(function (x, i) {
        var on = x === id;
        var t = tocLinks[i], m = menuLinks[i];
        if (t) {
          t.classList.toggle("active", on);
          if (on && !reduce) {
            t.classList.remove("flash");
            void t.offsetWidth;
            t.classList.add("flash");
          }
        }
        if (m) m.classList.toggle("active", on);
      });
    }

    // Deterministic scroll-spy: the active section is the last one whose top
    // has scrolled above a probe line near the top of the viewport.
    var PROBE = 120;
    function compute() {
      var doc = document.documentElement;
      if (window.innerHeight + window.scrollY >= doc.scrollHeight - 4) {
        setActive(ids[ids.length - 1]); // pinned to bottom → last section
        return;
      }
      var active = ids[0];
      for (var i = 0; i < els.length; i++) {
        if (!els[i]) continue;
        if (els[i].getBoundingClientRect().top - PROBE <= 0) active = ids[i];
        else break; // sections are in document order; the rest are lower
      }
      setActive(active);
    }

    var ticking = false;
    function onScroll() {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(function () { compute(); ticking = false; });
    }
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);

    // Clicking a menu / TOC entry activates it immediately (before the smooth
    // scroll settles), so the two panels never lag behind the click.
    tocLinks.concat(menuLinks).forEach(function (a) {
      if (!a) return;
      a.addEventListener("click", function () {
        var id = a.getAttribute("data-target");
        if (id) setActive(id);
      });
    });

    compute();
  })();
