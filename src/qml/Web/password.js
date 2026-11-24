// Password nel browser Vela: gira in un «mondo» separato da quello della pagina (le pagine non
// possono vederlo né usarlo) e parla con il browser tramite QWebChannel.
// - dice al browser se nella pagina c'è un modulo di accesso (per la chiave nella barra);
// - quando si preme «Accedi» manda nome utente e password, perché il browser chieda se salvarli;
// - __solidosRiempi(utente, password) compila i campi (anche nei siti fatti con React e simili).
(function () {
    "use strict";
    if (window.__solidosPassword) return;
    window.__solidosPassword = true;

    var ponte = null, coda = [];
    function manda(metodo, argomenti) {
        if (ponte) ponte[metodo].apply(ponte, argomenti);
        else coda.push([metodo, argomenti]);
    }
    if (typeof QWebChannel !== "undefined" && window.qt && qt.webChannelTransport) {
        new QWebChannel(qt.webChannelTransport, function (c) {
            ponte = c.objects.solidosPassword;
            coda.forEach(function (x) { ponte[x[0]].apply(ponte, x[1]); });
            coda = [];
        });
    } else if (window.__solidosFinto) {
        ponte = window.__solidosFinto;      // solo per le prove
    }

    function visibile(e) {
        var r = e.getBoundingClientRect();
        var s = getComputedStyle(e);
        return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none";
    }
    function campiPassword() {
        return Array.prototype.slice.call(document.querySelectorAll("input[type=password]")).filter(visibile);
    }
    function campoUtente(pw) {
        var radice = pw.form || document;
        var campi = Array.prototype.slice.call(radice.querySelectorAll(
            'input[type=email], input[type=text], input[type=tel], input:not([type])')).filter(visibile);
        var conNome = campi.filter(function (e) { return /username|email/.test(e.autocomplete || ""); });
        if (conNome.length) return conNome[0];
        var prima = campi.filter(function (e) { return e.compareDocumentPosition(pw) & Node.DOCUMENT_POSITION_FOLLOWING; });
        return prima.length ? prima[prima.length - 1] : null;
    }

    // ── c'è un modulo di accesso? (si ricontrolla quando la pagina cambia) ──
    var presente = null, attesa = null;
    function controlla() {
        attesa = null;
        var c = campiPassword().length > 0;
        if (c !== presente) {
            presente = c;
            manda("modulo", [location.href, c]);
        }
    }
    new MutationObserver(function () { if (!attesa) attesa = setTimeout(controlla, 400); })
        .observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ["type", "style", "class"] });
    controlla();

    // ── «Accedi»: nome e password al browser ──
    var ultimo = 0;
    function cattura(pw) {
        if (!pw || !pw.value) return;
        if (Date.now() - ultimo < 1500) return;
        ultimo = Date.now();
        var u = campoUtente(pw);
        manda("inviato", [JSON.stringify({ url: location.href, utente: u ? u.value.trim() : "", password: pw.value })]);
    }
    function ultimaPiena() {
        var piene = campiPassword().filter(function (p) { return p.value; });
        return piene.length ? piene[piene.length - 1] : null;     // registrazione: la conferma; cambio: la nuova
    }
    document.addEventListener("submit", function (e) {
        var pw = e.target && e.target.querySelectorAll ? Array.prototype.slice.call(e.target.querySelectorAll("input[type=password]")).filter(function (p) { return p.value; }).pop() : null;
        cattura(pw);
    }, true);
    // solo i tasti che inviano (non l'occhio «mostra password» o simili)
    var PAROLE = /accedi|entra|login|log in|sign in|signin|continua|avanti|next|invia|registr|sign up|crea|conferma|salva|submit|ok/i;
    document.addEventListener("click", function (e) {
        var b = e.target && e.target.closest ? e.target.closest('button, input[type=submit], input[type=button], [role=button], a') : null;
        if (!b) return;
        var invia = (b.tagName === "BUTTON" && (b.type === "submit" || (!b.getAttribute("type") && b.form))) ||
                    (b.tagName === "INPUT" && b.type === "submit") ||
                    PAROLE.test((b.innerText || b.value || b.getAttribute("aria-label") || "").trim().slice(0, 40));
        if (invia) cattura(ultimaPiena());
    }, true);
    document.addEventListener("keydown", function (e) {
        if (e.key === "Enter" && e.target && e.target.tagName === "INPUT") cattura(ultimaPiena());
    }, true);

    // ── compilazione ──
    window.__solidosRiempi = function (utente, password) {
        var pws = campiPassword();
        if (!pws.length) return false;
        var pw = pws[0];
        function metti(el, valore) {
            if (!el) return;
            el.focus();
            Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(el, valore);
            el.dispatchEvent(new Event("input", { bubbles: true }));
            el.dispatchEvent(new Event("change", { bubbles: true }));
        }
        var u = campoUtente(pw);
        if (u && utente) metti(u, utente);
        metti(pw, password);
        pw.blur();
        return true;
    };
})();
