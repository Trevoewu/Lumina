import 'dart:convert';

/// Runs in the viewer host; epub.js owns all column widths and body padding.
String buildEpubReaderScript({
  required String background,
  required String foreground,
  required bool scrolled,
  bool nativeGestures = false,
  double fontScale = 1,
  String? fontFamily,
}) =>
    '''
(function() {
  if (!window.rendition) return;
  var previousConfig = window._luminaReader;
  var typographyChanged = previousConfig &&
    (previousConfig.fontScale !== $fontScale || previousConfig.fontFamily !== ${jsonEncode(fontFamily)});
  var anchor = typographyChanged && rendition.location && rendition.location.start
    ? rendition.location.start.cfi : null;
  window._luminaReader = {
    background: '$background', foreground: '$foreground', scrolled: $scrolled, nativeGestures: $nativeGestures,
    fontScale: $fontScale, fontFamily: ${jsonEncode(fontFamily)}
  };
  function nativeTarget(x, y) {
    var all = rendition.getContents();
    for (var i = 0; i < all.length; i++) {
      var doc = all[i].document;
      var frame = doc.defaultView.frameElement;
      if (!frame) continue;
      var rect = frame.getBoundingClientRect();
      if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
        return doc.elementFromPoint(x - rect.left, y - rect.top);
      }
    }
    return null;
  }
  function hasSelection() {
    return rendition.getContents().some(function(c) {
      var selection = c.window.getSelection();
      return selection && !selection.isCollapsed && selection.toString().trim().length > 0;
    });
  }
  function isInteractive(target) {
    return target && target.closest && target.closest('a, button, input, textarea, select, [contenteditable="true"]');
  }
  // WKWebView can deliver native touches without firing listeners inside a
  // script-disabled EPUB iframe. Receive coordinates from Flutter instead of
  // enabling publisher scripts or stealing the WebView's selection gestures.
  window.luminaPointerDown = function(x, y) {
    window._luminaPointerBlocked = hasSelection() || !!isInteractive(nativeTarget(x, y));
  };
  window.luminaPointerUp = function(x, y, dx, dy, duration) {
    if (window._luminaPointerBlocked || hasSelection() || isInteractive(nativeTarget(x, y))) return;
    var forward;
    if (!window._luminaReader.scrolled && Math.abs(dx) > 40 &&
        Math.abs(dx) > Math.abs(dy) * 1.3 && duration < 600) {
      forward = dx < 0;
    } else if (Math.abs(dx) < 15 && Math.abs(dy) < 15 && duration < 350) {
      var ratio = x / window.innerWidth;
      if (ratio <= .25) forward = false;
      else if (ratio >= .75) forward = true;
      else {
        (window._luminaCenterTap || function(x, y) { window.flutter_inappwebview.callHandler('onTouchUp', x, y); })(ratio, y / window.innerHeight);
        return;
      }
    } else return;
    window.lastCfiRange = null;
    window.isSelecting = false;
    if (forward) rendition.next(); else rendition.prev();
  };
  window.luminaWheel = function(delta) {
    if (window._luminaReader.scrolled || hasSelection()) return;
    var now = Date.now();
    var gesture = window._luminaWheel || {time: 0, distance: 0, turned: false};
    if (now - gesture.time > 250) { gesture.distance = 0; gesture.turned = false; }
    gesture.time = now;
    gesture.distance += delta;
    window._luminaWheel = gesture;
    if (!gesture.turned && Math.abs(gesture.distance) >= 40) {
      gesture.turned = true;
      window.lastCfiRange = null;
      window.isSelecting = false;
      if (gesture.distance > 0) rendition.next(); else rendition.prev();
    }
  };
  function enhance(contents) {
    var doc = contents.document;
    var win = doc && doc.defaultView;
    if (!win) return;
    var config = window._luminaReader;
    var styleKey = JSON.stringify([config.background, config.foreground, config.fontScale, config.fontFamily]);
    if (doc._luminaStyleKey === styleKey && (config.nativeGestures || doc._luminaGestures)) return;
    doc._luminaStyleKey = styleKey;
    var style = doc.getElementById('lumina-reader-style');
    if (!style) {
      style = doc.createElement('style');
      style.id = 'lumina-reader-style';
      doc.head.appendChild(style);
    }
    style.textContent = `
      html, body { background: \${config.background} !important;
        color: \${config.foreground} !important; }
      body * { background-color: transparent !important;
        color: inherit !important; }
      p { margin-top: 0 !important; margin-bottom: .65em !important;
        line-height: 1.5 !important; }
      h1, h2, h3, h4, h5, h6, [class*="title"], [class*="chapter"],
      [class*="heading"], [class*="chap"] {
        margin-top: .75em !important; margin-bottom: .65em !important;
        padding-top: 0 !important; padding-bottom: 0 !important;
        min-height: 0 !important; height: auto !important;
        background: transparent !important;
        -webkit-text-fill-color: \${config.foreground} !important;
      }
      img, svg { max-width: 100% !important; object-fit: contain; }
    `;
    // Snapshot every computed size before writing any overrides. Changing the
    // body alone misses fixed px/pt sizes; measuring after writes compounds em
    // sizes on nested spans and on repeated slider updates.
    if (!doc._luminaTypography) {
      doc._luminaTypography = Array.from(doc.querySelectorAll('body, body *'))
        .filter(function(el) {
          return el.namespaceURI === 'http://www.w3.org/1999/xhtml' &&
            !el.matches('script, style, link');
        }).map(function(el) {
          return {
            element: el,
            size: parseFloat(win.getComputedStyle(el).fontSize),
            family: el.style.getPropertyValue('font-family'),
            familyPriority: el.style.getPropertyPriority('font-family')
          };
        });
    }
    doc._luminaTypography.forEach(function(entry) {
      if (Number.isFinite(entry.size)) {
        entry.element.style.setProperty('font-size', (entry.size * config.fontScale) + 'px', 'important');
      }
      if (config.fontFamily) {
        entry.element.style.setProperty('font-family', config.fontFamily, 'important');
      } else if (entry.family) {
        entry.element.style.setProperty('font-family', entry.family, entry.familyPriority);
      } else {
        entry.element.style.removeProperty('font-family');
      }
    });
    // Override publisher inline !important backgrounds too. Do not alter
    // illustrations, column geometry, page breaks, or intentional text indents.
    doc.querySelectorAll('body *').forEach(function(el) {
      if (el.namespaceURI !== 'http://www.w3.org/1999/xhtml') return;
      el.style.setProperty('background-color', 'transparent', 'important');
      if (el.matches('p, div, section, h1, h2, h3, h4, h5, h6') &&
          !el.querySelector('img, svg, table')) {
        var computed = win.getComputedStyle(el);
        ['margin-top', 'margin-bottom', 'padding-top', 'padding-bottom'].forEach(function(prop) {
          if (parseFloat(computed.getPropertyValue(prop)) > 32) {
            el.style.setProperty(prop, '12px', 'important');
          }
        });
      }
    });
    if (config.nativeGestures || doc._luminaGestures) return;
    doc._luminaGestures = true;
    var start = null;
    var lastTouch = 0;
    function selected() {
      var selection = win.getSelection();
      return selection && !selection.isCollapsed && selection.toString().trim().length > 0;
    }
    function interactive(target) {
      return target && target.closest && target.closest('a, button, input, textarea, select, [contenteditable="true"]');
    }
    function turn(forward) {
      if (selected()) return;
      window.lastCfiRange = null;
      window.isSelecting = false;
      if (forward) rendition.next(); else rendition.prev();
    }
    function tap(x, y) {
      var frame = win.frameElement;
      var ratio = (x + (frame ? frame.getBoundingClientRect().left : 0)) / window.innerWidth;
      if (ratio <= .25) turn(false);
      else if (ratio >= .75) turn(true);
      else if (window.flutter_inappwebview) {
        (window._luminaCenterTap || function(x, y) { window.flutter_inappwebview.callHandler('onTouchUp', x, y); })(ratio, y / window.innerHeight);
      }
    }
    // Window capture precedes the package's document handlers. One completed
    // touch produces exactly one action, with no synthetic-click second turn.
    win.addEventListener('touchstart', function(e) {
      start = e.touches.length === 1 ? {
        x: e.touches[0].clientX, y: e.touches[0].clientY,
        time: Date.now(), selected: selected(), target: e.target
      } : null;
    }, {capture: true, passive: true});
    win.addEventListener('touchcancel', function() { start = null; }, true);
    win.addEventListener('touchend', function(e) {
      var initial = start;
      start = null;
      lastTouch = Date.now();
      // Stop the package from interpreting selections and vertical drags as taps.
      e.stopImmediatePropagation();
      if (!initial || !e.changedTouches.length || initial.selected || selected() ||
          interactive(initial.target)) return;
      var touch = e.changedTouches[0];
      var dx = touch.clientX - initial.x;
      var dy = touch.clientY - initial.y;
      var duration = Date.now() - initial.time;
      if (!window._luminaReader.scrolled && Math.abs(dx) > 40 &&
          Math.abs(dx) > Math.abs(dy) * 1.3 && duration < 600) {
        e.preventDefault();
        turn(dx < 0);
      } else if (Math.abs(dx) < 15 && Math.abs(dy) < 15 && duration < 350) {
        e.preventDefault();
        tap(touch.clientX, touch.clientY);
      }
    }, {capture: true, passive: false});
    win.addEventListener('click', function(e) {
      if (interactive(e.target)) return;
      e.stopImmediatePropagation();
      if (Date.now() - lastTouch < 700 || selected()) return;
      tap(e.clientX, e.clientY);
    }, true);
    // One page per horizontal trackpad gesture, including its momentum tail.
    win.addEventListener('wheel', function(e) {
      if (window._luminaReader.scrolled || Math.abs(e.deltaX) <= Math.abs(e.deltaY) ||
          e.ctrlKey || selected() || interactive(e.target)) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      window.luminaWheel(e.deltaX * (e.deltaMode === 1 ? 16 : 1));
    }, {capture: true, passive: false});
    win.addEventListener('keydown', function(e) {
      if (selected() || interactive(e.target)) return;
      if (['ArrowRight', 'PageDown', ' ', 'ArrowLeft', 'PageUp'].includes(e.key)) {
        e.preventDefault();
        e.stopImmediatePropagation();
        turn(!['ArrowLeft', 'PageUp'].includes(e.key));
      }
    }, true);
  }
  if (!window._luminaContentHook) {
    window._luminaContentHook = enhance;
    rendition.hooks.content.register(enhance);
  }
  rendition.getContents().forEach(enhance);
  if (anchor) {
    // Allow layout to settle, then keep the reader at the same CFI after
    // repagination. Coalesce rapid slider changes around the first anchor.
    window._luminaTypographyAnchor = window._luminaTypographyAnchor || anchor;
    if (window._luminaTypographyFrame) cancelAnimationFrame(window._luminaTypographyFrame);
    window._luminaTypographyFrame = requestAnimationFrame(function() {
      window._luminaTypographyFrame = requestAnimationFrame(function() {
        var target = window._luminaTypographyAnchor;
        window._luminaTypographyAnchor = null;
        window._luminaTypographyFrame = null;
        rendition.display(target).then(function() { rendition.reportLocation(); })
          .catch(function(error) { console.error('EPUB typography reflow failed', error); });
      });
    });
  }
  if ($nativeGestures && !window._luminaBridgeFiltered) {
    window._luminaBridgeFiltered = true;
    var originalHandler = window.flutter_inappwebview.callHandler.bind(window.flutter_inappwebview);
    window._luminaCenterTap = function(x, y) { originalHandler('onTouchUp', x, y); };
    window.flutter_inappwebview.callHandler = function(name) {
      // The package may report touch-up for drags or deliver duplicates on
      // Apple platforms. Flutter owns classification on these platforms.
      if (name === 'onTouchUp' || name === 'onTouchDown') return Promise.resolve();
      return originalHandler.apply(null, arguments);
    };
  }
})();
''';
