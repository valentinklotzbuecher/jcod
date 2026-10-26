/* Presentation navigation for the native, two-dimensional RevealJS deck.
 * No custom arrow-key handlers: Reveal keeps its keyboard and presenter tools.
 */
(() => {
  "use strict";

  const button = (className, text, label, action) => {
    const element = document.createElement("button");
    element.type = "button";
    element.className = className;
    element.textContent = text;
    element.setAttribute("aria-label", label);
    element.title = label;
    element.addEventListener("click", (event) => {
      action(event);
      // Release focus after pointer clicks; a later arrow key would otherwise
      // make the button :focus-visible and keep the dock over the slides.
      if (event.detail) element.blur();
    });
    return element;
  };

  function mount(reveal) {
    if (document.querySelector(".deck-navigation")) return;

    const root = document.querySelector(".reveal .slides");
    if (!root) return;
    const horizontalSlides = [...root.children].filter((element) =>
      element.tagName === "SECTION"
    );
    const chapters = horizontalSlides.flatMap((horizontal, h) => {
      const vertical = [...horizontal.children].filter((element) =>
        element.tagName === "SECTION"
      );
      const cover = horizontal.matches(".chapter-slide") ? horizontal :
        vertical.find((slide) => slide.matches(".chapter-slide"));
      if (!cover) return [];
      const heading = cover.querySelector("h1, h2");
      const label = cover.dataset.chapterLabel || cover.dataset.chapter ||
        heading?.textContent?.trim() || `Chapter ${h}`;
      return [{h, cover, vertical, label}];
    });
    const map = root.querySelector("#session-map");
    const mapIndices = map ? reveal.getIndices(map) : {h: 0, v: 0};

    const navigate = (h, v = 0) => {
      if (reveal.isOverview()) reveal.toggleOverview(false);
      reveal.slide(h, v);
    };

    const navigation = document.createElement("nav");
    navigation.className = "deck-navigation";
    navigation.setAttribute("aria-label", "Presentation chapters");

    navigation.append(button(
      "deck-navigation__brand", "Map", "Go to the session map",
      () => navigate(mapIndices.h, mapIndices.v)
    ));

    const chapterList = document.createElement("div");
    chapterList.className = "deck-navigation__chapters";
    for (const chapter of chapters) {
      chapter.button = button(
        "deck-navigation__chapter", chapter.label,
        `Go to chapter: ${chapter.label}`,
        () => navigate(chapter.h, 0)
      );
      chapter.button.dataset.horizontalIndex = chapter.h;
      chapterList.append(chapter.button);
    }
    navigation.append(chapterList);

    const position = document.createElement("span");
    position.className = "deck-navigation__position";
    position.setAttribute("aria-live", "polite");
    position.setAttribute("aria-atomic", "true");
    navigation.append(position);

    const overview = button(
      "deck-navigation__overview", "Overview", "Show the two-dimensional overview (Esc)",
      () => reveal.toggleOverview()
    );
    overview.setAttribute("aria-pressed", "false");
    navigation.append(overview);
    document.body.append(navigation);

    // On 16:9 screens the dock would cover content-slide headings. It tucks
    // away there and returns on covers, at the top edge and on keyboard focus.
    // Touch devices, which cannot hover, keep it visible.
    const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)");
    let pointerAtTop = false;
    const tuck = () => {
      const cover = !!reveal.getCurrentSlide()?.matches("#title-slide, .chapter-slide");
      navigation.classList.toggle("is-tucked",
        finePointer.matches && !cover && !pointerAtTop);
    };
    document.addEventListener("pointermove", (event) => {
      const atTop = event.clientY < 80 || navigation.contains(event.target);
      if (atTop === pointerAtTop) return;
      pointerAtTop = atTop;
      tuck();
    }, {capture: true, passive: true});
    document.documentElement.addEventListener("mouseleave", () => {
      pointerAtTop = false;
      tuck();
    });
    if (finePointer.addEventListener) finePointer.addEventListener("change", tuck);

    const hint = document.createElement("div");
    hint.className = "deck-keyboard-hint";
    hint.setAttribute("aria-hidden", "true");
    for (const text of ["← → chapters", "↑ ↓ examples", "Space next", "Esc overview"]) {
      const item = document.createElement("span");
      item.textContent = text;
      hint.append(item);
    }
    document.body.append(hint);

    // Follow Quarto's native code fragments without adding another fragment
    // sequence. The explanations stay visible, including in static handouts.
    const updateCodeCallouts = () => {
      const current = reveal.getCurrentSlide();
      if (!current) return;
      const callouts = current.querySelectorAll(".code-callout[data-code-lines]");
      if (!callouts.length) return;
      const codes = [...current.querySelectorAll("pre code[data-code-line-numbers]")];
      const activeCode = codes.find((code) => code.classList.contains("current-fragment")) ||
        codes.filter((code) => code.classList.contains("visible")).at(-1) || codes[0];
      const lines = activeCode?.dataset.codeLineNumbers;
      for (const callout of callouts) {
        const active = callout.dataset.codeLines === lines;
        callout.classList.toggle("is-active", active);
        if (active) callout.setAttribute("aria-current", "step");
        else callout.removeAttribute("aria-current");
      }
    };

    const update = () => {
      const {h, v = 0} = reveal.getIndices();
      const chapter = chapters.find((candidate) => candidate.h === h);
      const current = reveal.getCurrentSlide();
      for (const candidate of chapters) {
        const active = candidate === chapter;
        candidate.button.classList.toggle("is-active", active);
        if (active) candidate.button.setAttribute("aria-current", "step");
        else candidate.button.removeAttribute("aria-current");
      }
      navigation.dataset.currentChapter = chapter?.label || "Introduction";
      position.textContent = chapter ? `${v + 1} / ${chapter.vertical.length || 1}` :
        (current === map ? "Session map" : "Welcome");
      position.title = chapter ?
        `Slide ${v + 1} of ${chapter.vertical.length || 1} in ${chapter.label}` :
        position.textContent;
      document.body.classList.toggle("deck-overview-open", reveal.isOverview());
      overview.setAttribute("aria-pressed", String(reveal.isOverview()));
      tuck();
      updateCodeCallouts();
    };
    // Reveal lazily loads images. Populate every thumbnail on first overview,
    // including figures from chapters the audience has not visited yet.
    const preloadOverviewImages = () => {
      for (const image of root.querySelectorAll("img[data-src]")) {
        image.addEventListener("load", () => reveal.layout(), {once: true});
        image.src = image.dataset.src;
        image.removeAttribute("data-src");
      }
    };
    reveal.on("slidechanged", update);
    reveal.on("overviewshown", preloadOverviewImages);
    reveal.on("overviewshown", update);
    reveal.on("overviewhidden", update);
    reveal.on("fragmentshown", updateCodeCallouts);
    reveal.on("fragmenthidden", updateCodeCallouts);

    const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    const configured = reveal.getConfig();
    const transitions = {
      transition: configured.transition,
      backgroundTransition: configured.backgroundTransition,
      autoAnimate: configured.autoAnimate
    };
    const respectMotionPreference = () => reveal.configure(motion.matches ? {
      transition: "none", backgroundTransition: "none", autoAnimate: false
    } : transitions);
    respectMotionPreference();
    if (motion.addEventListener) motion.addEventListener("change", respectMotionPreference);
    update();
  }

  let attempts = 0;
  function boot() {
    const reveal = window.Reveal;
    if (!reveal?.on) {
      if (++attempts < 200) window.setTimeout(boot, 50);
      return;
    }
    if (reveal.isReady()) mount(reveal);
    else reveal.on("ready", () => mount(reveal));
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot, {once: true});
  } else boot();
})();
