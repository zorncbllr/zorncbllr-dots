/* zorncbllr-dots site: live cookie clock, Material shapes, login-field demo, small UI helpers.
   No dependencies, nothing leaves the page. */
(function () {
  "use strict";

  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => Array.from(el.querySelectorAll(s));
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (/[?&]shot\b/.test(location.search)) document.documentElement.classList.add("shotmode"); // static renders for testing

  /* ---------- shapes (Material-style rounded polygons, drawn with round joins) ---------- */
  const f = (n) => +n.toFixed(2);
  function pts(n, r, cx, cy, rot, inner) {
    const out = [];
    const total = inner ? n * 2 : n;
    for (let k = 0; k < total; k++) {
      const a = ((rot + (360 / total) * k) * Math.PI) / 180;
      const rad = inner && k % 2 ? inner : r;
      out.push([cx + rad * Math.cos(a), cy + rad * Math.sin(a)]);
    }
    return out;
  }
  const poly = (p, sw) =>
    `<polygon points="${p.map((q) => f(q[0]) + "," + f(q[1])).join(" ")}" fill="currentColor" stroke="currentColor" stroke-width="${sw}" stroke-linejoin="round"/>`;

  // closed Catmull-Rom -> cubic Bezier: the scalloped "cookie" outline
  function smooth(p) {
    const n = p.length;
    let d = `M${f(p[0][0])},${f(p[0][1])}`;
    for (let i = 0; i < n; i++) {
      const p0 = p[(i - 1 + n) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n];
      const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
      const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
      d += ` C${f(c1[0])},${f(c1[1])} ${f(c2[0])},${f(c2[1])} ${f(p2[0])},${f(p2[1])}`;
    }
    return d + "Z";
  }
  const cookiePath = (cx, cy, r, sides, ratio) => smooth(pts(sides, r, cx, cy, -90, r * ratio));

  const SHAPES = {
    clover: () => `<g fill="currentColor"><circle cx="8.3" cy="8.3" r="5.2"/><circle cx="15.7" cy="8.3" r="5.2"/><circle cx="8.3" cy="15.7" r="5.2"/><circle cx="15.7" cy="15.7" r="5.2"/><rect x="8" y="8" width="8" height="8"/></g>`,
    arrow: () => poly([[12, 3.5], [20, 19.5], [12, 15.6], [4, 19.5]], 3),
    pill: () => `<rect x="2.5" y="6.5" width="19" height="11" rx="5.5" fill="currentColor"/>`,
    softburst: () => poly(pts(8, 10.2, 12, 12, -90, 8.4), 2.4),
    diamond: () => poly(pts(4, 9, 12, 12, -90), 3.4),
    clamshell: () => `<path d="M3.5 18 C3.5 9 7.5 5.5 12 5.5 S20.5 9 20.5 18 Z" fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>`,
    pentagon: () => poly(pts(5, 8.6, 12, 12, -90), 3.4),
    cookie: () => `<path d="${cookiePath(12, 12, 11.3, 12, 0.88)}" fill="currentColor"/>`,
    circle: () => `<circle cx="12" cy="12" r="11" fill="currentColor"/>`,
  };
  const shapeSvg = (name) => `<svg viewBox="0 0 24 24" aria-hidden="true">${SHAPES[name]()}</svg>`;

  // decorative shapes behind feature icons: <span class="shape t" data-shape="cookie">
  $$("[data-shape]").forEach((el) => el.insertAdjacentHTML("afterbegin", shapeSvg(el.dataset.shape)));
  $$("[data-brand-shape]").forEach((el) => (el.innerHTML = shapeSvg("cookie")));

  /* ---------- the cookie clock (same geometry as the shell's widget, 230 px grid) ---------- */
  const clockHost = $("#clock");
  const hands = {};
  if (clockHost) {
    let dial = "";
    for (let i = 0; i < 12; i++) dial += `<rect x="22" y="113" width="18" height="4" rx="2" transform="rotate(${i * 30} 115 115)"/>`;
    for (let i = 0; i < 60; i++) dial += `<rect x="22" y="114" width="7" height="2" rx="1" transform="rotate(${i * 6} 115 115)"/>`;
    const pent = pts(5, 27, 32, 33, -90).map((q) => f(q[0]) + "," + f(q[1])).join(" ");
    clockHost.innerHTML = `
      <svg class="cookie-clock" viewBox="0 0 230 230" role="img" aria-label="Live cookie clock showing your local time">
        <path d="${cookiePath(115, 115, 114, 14, 0.925)}" fill="#d4d4d4"/>
        <g fill="#d2d2d2">${dial}</g>
        <g font-weight="700" text-anchor="middle" dominant-baseline="central" fill="#ececec">
          <text id="c-hh" x="115" y="76" font-size="68">04</text>
          <text id="c-mm" x="115" y="143" font-size="68">10</text>
          <text id="c-ap" x="115" y="183" font-size="26">pm</text>
        </g>
        <g id="c-min" style="transform-box:view-box;transform-origin:115px 115px;transition:transform .5s var(--spatial)"><rect x="109" y="109" width="95" height="12" rx="6" fill="#e2e2e2"/></g>
        <g id="c-hour" style="transform-box:view-box;transform-origin:115px 115px;transition:transform .5s var(--spatial)"><rect x="105" y="105" width="72" height="20" rx="10" fill="#fff"/></g>
        <circle cx="115" cy="115" r="3" fill="#d4d4d4"/>
        <polygon points="${pent}" fill="#919191" stroke="#919191" stroke-width="7" stroke-linejoin="round"/>
        <text id="c-day" x="32" y="34" font-size="30" font-weight="800" text-anchor="middle" dominant-baseline="central" fill="#000">15</text>
        <circle cx="198" cy="198" r="32" fill="#474747"/>
        <text id="c-mon" x="198" y="199" font-size="30" font-weight="800" text-anchor="middle" dominant-baseline="central" fill="#e2e2e2">10</text>
      </svg>`;
    ["hh", "mm", "ap", "day", "mon"].forEach((k) => (hands[k] = $("#c-" + k)));
    hands.min = $("#c-min");
    hands.hour = $("#c-hour");
  }

  const pad = (n) => String(n).padStart(2, "0");
  const WD = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  function tick() {
    const d = new Date();
    const h24 = d.getHours(), m = d.getMinutes();
    const h12 = h24 % 12 || 12, ap = h24 < 12 ? "am" : "pm";
    if (clockHost) {
      hands.hh.textContent = pad(h12);
      hands.mm.textContent = pad(m);
      hands.ap.textContent = ap;
      hands.day.textContent = String(d.getDate());
      hands.mon.textContent = pad(d.getMonth() + 1);
      hands.min.style.transform = `rotate(${-90 + 6 * m}deg)`;
      hands.hour.style.transform = `rotate(${-90 + 30 * ((h24 % 12) + m / 60)}deg)`;
    }
    const when = $("#when");
    if (when) when.textContent = `${h12}:${pad(m)} ${ap} • ${WD[d.getDay()]}, ${pad(d.getDate())}/${pad(d.getMonth() + 1)}`;
  }
  tick();
  setInterval(tick, 1000 * 15);

  /* ---------- workspace dots = which section you are in ---------- */
  const sections = $$("[data-ws]");
  const dotsEl = $("#dots");
  if (dotsEl && sections.length) {
    sections.forEach((s, i) => {
      const b = document.createElement("button");
      b.className = "dot";
      b.setAttribute("aria-label", "Go to " + s.dataset.ws);
      b.title = s.dataset.ws;
      b.addEventListener("click", () => s.scrollIntoView({ behavior: reduce ? "auto" : "smooth" }));
      dotsEl.appendChild(b);
    });
    const dots = $$(".dot", dotsEl);
    const setActive = (i) => dots.forEach((d, j) => d.classList.toggle("active", i === j));
    setActive(0);
    const io = new IntersectionObserver(
      (entries) => entries.forEach((e) => { if (e.isIntersecting) setActive(sections.indexOf(e.target)); }),
      { rootMargin: "-45% 0px -50% 0px" }
    );
    sections.forEach((s) => io.observe(s));
  }

  /* ---------- copy buttons ---------- */
  const toast = $("#toast");
  let toastTimer;
  function say(msg) {
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove("show"), 1800);
  }
  async function copy(text) {
    try {
      await navigator.clipboard.writeText(text);
    } catch (_) {
      const t = document.createElement("textarea");
      t.value = text; t.style.position = "fixed"; t.style.opacity = "0";
      document.body.appendChild(t); t.select();
      try { document.execCommand("copy"); } catch (__) { /* ignore */ }
      t.remove();
    }
    say("Copied");
  }
  $$("[data-copy]").forEach((b) => b.addEventListener("click", () => copy(b.dataset.copy)));

  /* ---------- screenshot viewer ---------- */
  const lb = $("#lightbox");
  if (lb) {
    const big = $("img", lb);
    $$(".shot").forEach((s) =>
      s.addEventListener("click", () => {
        const im = $("img", s);
        big.src = im.currentSrc || im.src;
        big.alt = im.alt;
        lb.showModal();
      })
    );
    lb.addEventListener("click", () => lb.close());
  }

  /* ---------- login-field demo: typed characters become Material shapes ---------- */
  const field = $("#field");
  if (field) {
    const input = $("input", field), row = $(".row", field), ph = $(".ph", field), caret = $(".caret", field);
    const order = ["clover", "arrow", "pill", "softburst", "diamond", "clamshell", "pentagon"];
    const sync = () => {
      const n = input.value.length;
      while (row.querySelectorAll("i").length < n) {
        const i = document.createElement("i");
        i.innerHTML = shapeSvg(order[row.querySelectorAll("i").length % order.length]);
        row.insertBefore(i, caret);
      }
      let all = row.querySelectorAll("i");
      while (all.length > n) { all[all.length - 1].remove(); all = row.querySelectorAll("i"); }
      ph.hidden = n > 0;
      const over = row.scrollWidth - $(".chars", field).clientWidth;
      row.style.transform = `translateX(${-Math.max(0, over)}px)`;
    };
    input.addEventListener("input", () => { field.classList.remove("bad"); ph.textContent = "Enter password"; sync(); });
    input.addEventListener("keydown", (e) => {
      if (e.key === "Escape") { input.value = ""; sync(); }
      if (e.key === "Enter") {
        // demo only: nothing is checked or sent anywhere; always "wrong", like a failed unlock
        e.preventDefault();
        input.value = "";
        sync();
        ph.textContent = "Incorrect password";
        field.classList.add("bad", "shake");
        setTimeout(() => field.classList.remove("shake"), 300);
      }
    });
    field.addEventListener("click", () => input.focus());
    sync();
  }
  $$("[data-demo-btn]").forEach((b) => b.addEventListener("click", () => { const i = $("#field input"); if (i) { i.focus(); i.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" })); } }));

  /* ---------- reveal on scroll ---------- */
  const rv = $$(".reveal");
  if (!("IntersectionObserver" in window) || reduce) rv.forEach((e) => e.classList.add("in"));
  else {
    const ro = new IntersectionObserver((entries) => entries.forEach((e) => {
      if (e.isIntersecting) { e.target.classList.add("in"); ro.unobserve(e.target); }
    }), { rootMargin: "0px 0px -8% 0px" });
    rv.forEach((e) => ro.observe(e));
  }
})();
