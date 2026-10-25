/* webui client glue.
 *
 * This file is served as /__webui/app.js and only reacts to out-of-band
 * messages sent by the Lua side: toasts, titles, navigation, focus and
 * protocol reloads.  DOM updates are owned by htmx and idiomorph.
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

    function route() {
        var el = root();
        return (el && el.getAttribute("data-route")) || "/";
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
        var ms = payload.ms || 3000;
        if (ms > 0) {
            window.setTimeout(function () {
                if (item.parentNode) {
                    item.parentNode.removeChild(item);
                }
            }, ms);
        }
    }

    function payloadOf(event) {
        try {
            return typeof event.detail.data === "string"
                ? JSON.parse(event.detail.data)
                : event.detail.data || {};
        } catch (err) {
            return {};
        }
    }

    function handleSse(name, handler) {
        document.body.addEventListener("htmx:sseMessage", function (event) {
            if (event.detail.type === name) {
                handler(payloadOf(event));
            }
        });
    }

    document.addEventListener("DOMContentLoaded", function () {
        handleSse("toast", toast);

        handleSse("title", function (payload) {
            if (payload.text) {
                document.title = payload.text;
            }
        });

        handleSse("focus", function (payload) {
            var el = payload.id && document.querySelector('[data-id="' + payload.id + '"]');
            if (el) {
                el.focus();
            }
        });

        handleSse("reload", function () {
            window.location.reload();
        });

        // Ignore pushed HTML for another route or an older revision. The POST
        // response and the SSE push may race; the revision guard keeps the
        // newest tree.
        document.body.addEventListener("htmx:sseMessage", function (event) {
            if (event.detail.type !== "html") {
                return;
            }
            var payload = payloadOf(event);
            if (payload.route && payload.route !== route()) {
                event.preventDefault();
                return;
            }
            if (payload.rev && payload.rev <= revision()) {
                event.preventDefault();
            }
        });

        // htmx restores cached history snapshots without asking the server.
        // Ask once so the server-side tree and the DOM agree again.
        document.body.addEventListener("htmx:historyRestore", function () {
            if (window.htmx) {
                window.htmx.ajax("GET", window.location.pathname, {
                    target: "#webui-root",
                    swap: "morph:innerHTML",
                });
            }
        });

        document.body.addEventListener("htmx:responseError", function () {
            toast({ kind: "error", text: "server error", ms: 5000 });
        });
    });

    document.body.addEventListener("htmx:afterRequest", function (event) {
        var trigger = event.detail.xhr.getResponseHeader("HX-Trigger");
        if (!trigger) {
            return;
        }
        var data;
        try {
            data = JSON.parse(trigger);
        } catch (err) {
            return;
        }
        if (data["webui:toast"]) {
            toast(data["webui:toast"]);
        }
        if (data["webui:error"]) {
            toast({ kind: "error", text: data["webui:error"].text, ms: 5000 });
        }
        if (data["webui:navigate"] && data["webui:navigate"].path) {
            window.history.pushState({}, "", data["webui:navigate"].path);
            if (window.htmx) {
                window.htmx.ajax("GET", data["webui:navigate"].path, {
                    target: "#webui-root",
                    swap: "morph:innerHTML",
                });
            }
        }
    });
})();
