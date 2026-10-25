/* webui client glue.
 *
 * htmx and idiomorph own the DOM updates; this file only reacts to
 * out-of-band messages (toasts, focus, reloads), keeps the revision guard and
 * derives the event kind from the htmx trigger that fired. No eval, no inline
 * handlers, so the page can run under a strict CSP.
 */
(function () {
    "use strict";

    function root() {
        return document.getElementById("webui-root");
    }

    function revision() {
        var el = root();
        var value = el && el.getAttribute("data-rev");
        return value ? parseInt(value, 10) : 0;
    }

    function toast(payload) {
        var host = document.getElementById("webui-toasts");
        if (!host) {
            return;
        }
        var item = document.createElement("div");
        item.className = "webui-toast webui-toast-" + (payload.kind || "info");
        item.setAttribute("role", "status");
        item.textContent = payload.text || "";
        host.appendChild(item);
        var ms = payload.ms === undefined ? 3000 : payload.ms;
        if (ms > 0) {
            window.setTimeout(function () {
                if (item.parentNode) {
                    item.parentNode.removeChild(item);
                }
            }, ms);
        }
    }

    function parseJson(text, fallback) {
        try {
            return JSON.parse(text);
        } catch (err) {
            return fallback;
        }
    }

    function ssePayload(event) {
        var data = event.detail && event.detail.data;
        if (typeof data !== "string") {
            return data || {};
        }
        return parseJson(data, {});
    }

    function onSse(name, handler) {
        document.body.addEventListener("htmx:sseMessage", function (event) {
            if (event.detail && event.detail.type === name) {
                handler(ssePayload(event), event);
            }
        });
    }

    // Inputs and textareas send the htmx trigger name as the event kind, so a
    // single element can report both `input` and `change`.
    document.body.addEventListener("htmx:configRequest", function (event) {
        var el = event.detail.elt;
        if (!el || !el.getAttribute || !el.getAttribute("data-webui-trigger-kind")) {
            return;
        }
        var spec = event.detail.triggerSpec;
        var trigger = (spec && spec.trigger) || "change";
        event.detail.parameters.kind = trigger;
    });

    // The POST response and the SSE push race; the newest revision wins.
    document.body.addEventListener("htmx:beforeSwap", function (event) {
        var target = event.detail.target;
        if (!target || target.id !== "webui-root") {
            return;
        }
        var response = event.detail.serverResponse;
        if (typeof response !== "string") {
            return;
        }
        var match = /data-rev="(\d+)"/.exec(response);
        if (!match) {
            return;
        }
        if (parseInt(match[1], 10) <= revision()) {
            event.detail.shouldSwap = false;
        }
    });

    // <dialog open> only marks the element; modal behaviour needs showModal().
    document.body.addEventListener("htmx:afterSettle", function () {
        var dialogs = document.querySelectorAll("dialog.webui-dialog[open]");
        for (var index = 0; index < dialogs.length; index += 1) {
            var dialog = dialogs[index];
            if (!dialog.open) {
                dialog.showModal();
            }
        }
    });

    document.addEventListener("DOMContentLoaded", function () {
        if (!window.htmx) {
            return;
        }

        onSse("toast", toast);

        onSse("title", function (payload) {
            if (payload.text) {
                document.title = payload.text;
            }
        });

        onSse("focus", function (payload) {
            var el = payload.id && document.querySelector('[data-id="' + payload.id + '"]');
            if (el && el.focus) {
                el.focus();
            }
        });

        onSse("reload", function () {
            window.location.reload();
        });

        // htmx restores cached history snapshots without asking the server.
        document.body.addEventListener("htmx:historyRestore", function () {
            window.htmx.ajax("GET", window.location.pathname, {
                target: "#webui-root",
                swap: "morph:outerHTML",
            });
        });

        document.body.addEventListener("htmx:afterRequest", function (event) {
            var xhr = event.detail.xhr;
            if (!xhr || !xhr.getResponseHeader) {
                return;
            }
            var trigger = xhr.getResponseHeader("HX-Trigger");
            if (!trigger) {
                return;
            }
            var data = parseJson(trigger, null);
            if (!data) {
                return;
            }
            var toasts = data["webui:toasts"];
            if (toasts) {
                for (var index = 0; index < toasts.length; index += 1) {
                    toast(toasts[index]);
                }
            }
            var focus = data["webui:focus"];
            if (focus && focus.id) {
                var el = document.querySelector('[data-id="' + focus.id + '"]');
                if (el && el.focus) {
                    el.focus();
                }
            }
        });

        document.body.addEventListener("htmx:responseError", function () {
            toast({ kind: "error", text: "server error", ms: 5000 });
        });
    });
})();
