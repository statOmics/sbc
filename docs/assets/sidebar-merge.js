// Merge the per-page "On this page" TOC into the book's left chapter
// sidebar, so each chapter can be expanded inline instead of showing a
// separate right-hand panel. Requires format.html.toc-location: left in
// _quarto.yml (that's what makes Quarto put <nav id="TOC"> inside
// #quarto-sidebar instead of the right-hand margin sidebar).
(function () {
  "use strict";

  function fragmentToChapterHref(baseHref, toc) {
    // rewrite #fragment links inside a fetched chapter's TOC so they point
    // back at that chapter's page when viewed from a different page.
    toc.querySelectorAll("a[href^='#']").forEach(function (a) {
      a.setAttribute("href", baseHref + a.getAttribute("href"));
    });
    return toc;
  }

  function buildToggle() {
    var toggle = document.createElement("span");
    toggle.className = "chapter-toc-toggle";
    toggle.setAttribute("role", "button");
    toggle.setAttribute("aria-label", "Toon/verberg inhoud van dit hoofdstuk");
    toggle.innerHTML = "<svg viewBox='0 0 16 16' width='10' height='10'><path d='M4 2l8 6-8 6z' fill='currentColor'/></svg>";
    return toggle;
  }

  function expand(li) {
    li.classList.add("chapter-expanded");
  }
  function collapse(li) {
    li.classList.remove("chapter-expanded");
  }

  function attachNestedToc(li, tocEl) {
    // NOTE: for the active chapter, tocEl is the *same node object* that
    // Quarto's own quarto.js scroll-tracking script captured a reference to
    // (via `document.querySelector('nav.toc-active[role="doc-toc"]')`) and
    // queries live for its .nav-link descendants. We must relocate that
    // exact node (not clone it, not just move its <ul> out from under it),
    // or active-section-while-scrolling highlighting breaks.
    tocEl.classList.add("chapter-toc-nested");
    li.appendChild(tocEl);
  }

  function loadRemoteToc(li, href, toggle) {
    li.classList.add("chapter-toc-loading");
    fetch(href)
      .then(function (resp) { return resp.text(); })
      .then(function (html) {
        var doc = new DOMParser().parseFromString(html, "text/html");
        var toc = doc.querySelector("#TOC");
        var list = toc ? toc.querySelector("ul") : null;
        li.classList.remove("chapter-toc-loading");
        li.dataset.tocFetched = "1";
        if (!list || !list.children.length) {
          li.classList.add("chapter-toc-empty");
          return;
        }
        // this is a detached node parsed from fetched HTML (not the live
        // page), so there's no scroll-tracking reference to preserve here.
        list.classList.add("chapter-toc-nested");
        li.appendChild(fragmentToChapterHref(href, list));
        expand(li);
      })
      .catch(function () {
        li.classList.remove("chapter-toc-loading");
        li.classList.add("chapter-toc-empty");
      });
  }

  function init() {
    var sidebar = document.getElementById("quarto-sidebar");
    if (!sidebar) return;

    var menu = sidebar.querySelector(".sidebar-menu-container > ul");
    if (!menu) return;

    // the current page's own TOC, already rendered in full by Quarto
    // (present because format.html.toc-location: left is set). Strip the
    // "Inhoudsopgave" heading and edit-page link, keep the <ul> in place.
    var pageToc = sidebar.querySelector("#TOC");
    if (pageToc) {
      var heading = pageToc.querySelector("#toc-title");
      if (heading) heading.remove();
      var actions = pageToc.querySelector(".toc-actions");
      if (actions) actions.remove();
    }
    var pageTocUl = pageToc ? pageToc.querySelector("ul") : null;
    var pageTocHasItems = !!(pageTocUl && pageTocUl.children.length);

    var items = menu.querySelectorAll(":scope > li.sidebar-item");
    items.forEach(function (li) {
      var link = li.querySelector(":scope > .sidebar-item-container > a.sidebar-link");
      if (!link) return;
      var href = link.getAttribute("href");
      var isActive = link.classList.contains("active");

      var toggle = buildToggle();
      link.parentNode.insertBefore(toggle, link);

      toggle.addEventListener("click", function (e) {
        e.preventDefault();
        e.stopPropagation();
        if (li.classList.contains("chapter-expanded")) {
          collapse(li);
          return;
        }
        if (li.dataset.tocFetched === "1" || isActive) {
          expand(li);
        } else {
          loadRemoteToc(li, href, toggle);
        }
      });

      if (isActive && pageTocHasItems) {
        attachNestedToc(li, pageToc);
        li.dataset.tocFetched = "1";
        expand(li);
      } else if (isActive) {
        li.classList.add("chapter-toc-empty");
      }
    });

    // if the active page had no headings, pageToc (if present) was never
    // relocated into a sidebar item; drop the leftover empty wrapper
    if (!pageTocHasItems && pageToc && pageToc.parentNode) {
      pageToc.parentNode.removeChild(pageToc);
    }
  }

  // This script is loaded via include-after-body, i.e. right before
  // </body>: the sidebar and TOC markup it operates on are already fully
  // parsed into the DOM by the time it runs, so there is no need to wait
  // for DOMContentLoaded (and definitely not for window "load", which
  // would also wait on every embedded YouTube iframe on the page --
  // noticeably slow and janky, especially on mobile). Quarto's own
  // scroll-tracking script (quarto.js, a deferred module) caches a
  // reference to <nav id="TOC"> once, in its own DOMContentLoaded handler,
  // whichever order that runs in relative to this script -- but it's a
  // reference to the actual DOM node, so relocating that same node later
  // (rather than cloning it) keeps the reference valid regardless of
  // execution order. Verified by testing real scroll-driven highlighting
  // after this change.
  init();
})();
