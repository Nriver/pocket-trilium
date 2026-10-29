(function () {
  if (window.__triliumMobileBackHandlerInstalled) {
    return;
  }

  window.__triliumMobileBackHandlerInstalled = true;

  const GUARD_STATE_KEY = "__triliumBackGuard";
  // 每次页面加载都使用新的标记：刷新后 history.state 可能仍残留上一次的守卫，
  // 若直接信任它就会以为守卫已经压入，导致首次打开菜单时返回无效。
  const GUARD_TOKEN = "guard-" + Date.now() + "-" + Math.random().toString(36).slice(2);
  const OVERLAY_SELECTOR = [
    ".modal.show",
    ".modal.in",
    ".dropdown-menu.show",
    ".dropdown-menu.in",
    ".popover.show",
    ".offcanvas.show"
  ].join(", ");

  let enabled = __BACK_CLOSE_ENABLED__;
  let observer = null;
  let guardPushed = false;
  let overlayStack = [];
  let removeGuardTimer = null;
  let syncScheduled = false;

  function hasGuardState() {
    return !!(history.state && history.state[GUARD_STATE_KEY] === GUARD_TOKEN);
  }

  function isVisible(el) {
    if (!el || !el.isConnected) {
      return false;
    }

    const style = window.getComputedStyle(el);

    if (style.display === "none" || style.visibility === "hidden") {
      return false;
    }

    return el.getClientRects().length > 0;
  }

  // 只返回真正可见的弹窗/菜单，避免 Trilium 关闭后仍残留的 show class 造成误判
  function getOpenOverlays() {
    return Array.prototype.filter.call(
      document.querySelectorAll(OVERLAY_SELECTOR),
      function (el) {
        return isVisible(el) && !isAlwaysShownMenu(el);
      }
    );
  }

  // 0.106 的表单选择器使用始终可见的 .dropdown-menu.static.show，不能当成打开的浮层
  function isAlwaysShownMenu(menu) {
    if (!menu.classList.contains("static")) {
      return false;
    }

    const toggle = findDropdownToggle(menu);

    return !toggle || !isVisible(toggle);
  }

  // 记录弹窗打开的顺序，最后打开的在最上层
  function refreshOverlayStack() {
    const visible = getOpenOverlays();

    overlayStack = overlayStack.filter(function (el) {
      return visible.indexOf(el) !== -1;
    });

    visible.forEach(function (el) {
      if (overlayStack.indexOf(el) === -1) {
        overlayStack.push(el);
      }
    });

    return overlayStack;
  }

  function cancelRemoveGuard() {
    if (removeGuardTimer !== null) {
      clearTimeout(removeGuardTimer);
      removeGuardTimer = null;
    }
  }

  function pushGuard() {
    if (!enabled) {
      return;
    }

    cancelRemoveGuard();

    // 不能只看 guardPushed：应用可能在守卫之后又 pushState，
    // 此时需要重新把守卫压到最上面。
    if (hasGuardState()) {
      guardPushed = true;
      return;
    }

    try {
      const state = {};
      state[GUARD_STATE_KEY] = GUARD_TOKEN;
      history.pushState(state, "");
      guardPushed = true;
    } catch (e) {
      // 某些 WebView 可能不允许 pushState，此时只能依赖 popstate 尽力处理
    }
  }

  function scheduleRemoveGuard() {
    if (!enabled || !guardPushed || removeGuardTimer !== null) {
      return;
    }

    removeGuardTimer = setTimeout(function () {
      removeGuardTimer = null;

      if (!enabled || !guardPushed || getOpenOverlays().length > 0) {
        return;
      }

      // 确认当前历史条目确实是我们本次加载插入的守卫，避免误伤应用自己的历史
      if (!hasGuardState()) {
        guardPushed = false;
        return;
      }

      guardPushed = false;
      history.back();
    }, 150);
  }

  // 通过菜单本身找到它的触发按钮，避免误关其他下拉菜单。
  // 0.106 的 portal 菜单不在触发按钮的子树中，需要通过 aria-labelledby 反查。
  function findDropdownToggle(menu) {
    const labelledBy = menu.getAttribute("aria-labelledby");

    if (labelledBy) {
      const labelledToggle = document.getElementById(labelledBy);

      if (labelledToggle && !menu.contains(labelledToggle)) {
        return labelledToggle;
      }
    }

    // 只查父级的直接子元素，避免把菜单内部的子菜单触发元素误当成外层菜单的按钮
    let node = menu.parentElement;

    while (node && node !== document.body) {
      const children = node.children;

      for (let i = 0; i < children.length; i++) {
        const child = children[i];

        if (child === menu) {
          continue;
        }

        if (
          child.classList.contains("dropdown-toggle") ||
          child.matches('[data-bs-toggle="dropdown"], [data-toggle="dropdown"]')
        ) {
          return child;
        }
      }

      node = node.parentElement;
    }

    return null;
  }

  function dispatchEscape(target) {
    target.dispatchEvent(new KeyboardEvent("keydown", {
      key: "Escape",
      code: "Escape",
      keyCode: 27,
      which: 27,
      bubbles: true,
      cancelable: true
    }));
  }

  function forceHide(el) {
    el.classList.remove("show", "in");

    // modal 由 Bootstrap 通过内联 display 控制；其余浮层去掉 show 后恢复样式表默认值即可
    el.style.display = el.classList.contains("modal") ? "none" : "";
  }

  function hideBackdropsIfNoModal() {
    if (document.querySelector(".modal.show, .modal.in")) {
      return;
    }

    document.querySelectorAll(".modal-backdrop").forEach(function (backdrop) {
      backdrop.remove();
    });

    document.body.classList.remove("modal-open");
  }

  function forceHideDropdown(menu, toggle) {
    forceHide(menu);

    if (toggle) {
      toggle.classList.remove("show");
      toggle.setAttribute("aria-expanded", "false");
    }

    const portal = menu.closest(".tn-dropdown-portal");

    if (portal) {
      portal.querySelectorAll(".tn-dropdown-backdrop").forEach(function (backdrop) {
        backdrop.remove();
      });
    }
  }

  function closeDropdown(menu) {
    const toggle = findDropdownToggle(menu);

    if (toggle) {
      // Bootstrap 4/5 的菜单和 0.106 的自定义子菜单都由触发元素负责关闭
      toggle.click();
      return;
    }

    dispatchEscape(menu);

    setTimeout(function () {
      if (isVisible(menu)) {
        forceHideDropdown(menu, null);
      }
    }, 200);
  }

  function getContextMenuContainer(menu) {
    const container = document.getElementById("context-menu-container");

    if (container && (container === menu || container.contains(menu))) {
      return container;
    }

    return null;
  }

  function clearContextMenuCover() {
    const cover = document.getElementById("context-menu-cover");

    if (cover) {
      cover.classList.remove("show", "global-menu-cover");
    }

    document.body.classList.remove("context-menu-shown");
  }

  function closeContextMenuSubmenu(menu) {
    menu.classList.remove("show");
    menu.style.display = "";

    if (menu.parentElement) {
      const parentItem = menu.parentElement.closest(".dropdown-item");

      if (parentItem) {
        parentItem.classList.remove("submenu-open");
      }
    }
  }

  function closeContextMenu(menu) {
    const cover = document.getElementById("context-menu-cover");

    // 移动端由 cover 的点击处理器执行完整清理（含 onHide 回调）
    if (cover && isVisible(cover)) {
      cover.click();
    }

    if (!isVisible(menu)) {
      return;
    }

    menu.classList.remove("show");
    menu.style.display = "none";
    clearContextMenuCover();
  }

  function closeModal(overlay) {
    const closeButton = overlay.querySelector(
      '.modal-header [data-bs-dismiss="modal"], .modal-header [data-dismiss="modal"], .modal-header .btn-close, .modal-header .close'
    );

    if (closeButton) {
      closeButton.click();
    } else {
      dispatchEscape(overlay);
    }

    // Bootstrap 在打开动画期间会丢弃 hide()，稍后重试一次再兜底
    setTimeout(function () {
      if (!isVisible(overlay)) {
        return;
      }

      if (closeButton) {
        closeButton.click();
      }

      const jq = window.jQuery;

      if (jq && jq.fn.modal) {
        try {
          jq(overlay).modal("hide");
        } catch (e) {
          // 兜底在下面
        }
      } else if (!closeButton) {
        dispatchEscape(overlay);
      }

      setTimeout(function () {
        if (!isVisible(overlay)) {
          return;
        }

        forceHide(overlay);
        hideBackdropsIfNoModal();
        document.body.classList.remove("modal-open");
      }, 200);
    }, 200);
  }

  function closeOverlay(overlay) {
    const contextMenu = getContextMenuContainer(overlay);

    if (contextMenu) {
      if (contextMenu === overlay) {
        closeContextMenu(overlay);
      } else {
        closeContextMenuSubmenu(overlay);
      }

      return;
    }

    if (overlay.classList.contains("modal")) {
      closeModal(overlay);
      return;
    }

    if (overlay.classList.contains("dropdown-menu")) {
      closeDropdown(overlay);
      return;
    }

    const jq = window.jQuery;

    if (overlay.classList.contains("popover") && jq && jq.fn.popover) {
      try {
        jq(overlay).popover("hide");
      } catch (e) {
        // 兜底走下面的强制隐藏
      }
    }

    // popover / offcanvas 以及其他浮动层
    forceHide(overlay);
  }

  function syncGuard() {
    if (!enabled) {
      return;
    }

    const overlays = refreshOverlayStack();

    if (overlays.length > 0) {
      pushGuard();
    } else if (guardPushed) {
      scheduleRemoveGuard();
    }
  }

  function scheduleSync() {
    if (!enabled || syncScheduled) {
      return;
    }

    syncScheduled = true;

    setTimeout(function () {
      syncScheduled = false;
      syncGuard();
    }, 0);
  }

  window.addEventListener("popstate", function () {
    if (!enabled) {
      return;
    }

    cancelRemoveGuard();

    const overlays = refreshOverlayStack();

    if (overlays.length === 0) {
      // 没有需要关闭的浮层，让浏览器继续正常后退
      guardPushed = false;
      return;
    }

    // 只关闭最上层的浮层，嵌套弹窗可以一层一层返回
    const topOverlay = overlays[overlays.length - 1];
    const index = overlayStack.indexOf(topOverlay);

    if (index !== -1) {
      overlayStack.splice(index, 1);
    }

    closeOverlay(topOverlay);
    guardPushed = false;

    // 如果还有浮层，重新压入一条历史记录，保证下一次返回仍能被拦截
    if (refreshOverlayStack().length > 0) {
      pushGuard();
    }
  });

  window.addEventListener("pageshow", function () {
    if (!enabled) {
      return;
    }

    guardPushed = hasGuardState();
    scheduleSync();
  });

  function start() {
    guardPushed = hasGuardState();

    if (!enabled) {
      return;
    }

    if (!document.body) {
      document.addEventListener("DOMContentLoaded", start, { once: true });
      return;
    }

    if (!observer) {
      observer = new MutationObserver(scheduleSync);
      observer.observe(document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["class", "style", "aria-expanded"]
      });
    }

    scheduleSync();
  }

  // 设置切换后立即生效：关闭时移除观察器和守卫，避免影响原有返回行为
  window.__triliumBackCloseSetEnabled = function (value) {
    const next = !!value;

    if (next === enabled) {
      if (next) {
        scheduleSync();
      }
      return;
    }

    enabled = next;

    if (enabled) {
      start();
      return;
    }

    cancelRemoveGuard();
    syncScheduled = false;

    if (observer) {
      observer.disconnect();
      observer = null;
    }

    guardPushed = false;

    if (hasGuardState()) {
      try {
        history.back();
      } catch (e) {}
    }
  };

  if (document.body) {
    start();
  } else {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  }
})();
