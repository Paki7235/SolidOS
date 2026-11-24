// Corpo del messaggio con il motore web: JavaScript spento, profilo senza memoria (niente
// cookie), i collegamenti si aprono fuori (nel browser) e non qui dentro.
import QtQuick
import QtWebEngine

WebEngineView {
    id: vista
    property string pagina: ""
    signal collegamento(string url)
    backgroundColor: "transparent"
    profile: WebEngineProfile { httpCacheType: WebEngineProfile.MemoryHttpCache; persistentCookiesPolicy: WebEngineProfile.NoPersistentCookies }
    settings.javascriptEnabled: false
    settings.javascriptCanOpenWindows: false
    settings.localContentCanAccessRemoteUrls: false
    settings.localContentCanAccessFileUrls: false
    settings.pluginsEnabled: false
    settings.autoLoadImages: true
    settings.focusOnNavigationEnabled: false
    onPaginaChanged: loadHtml(pagina, "about:blank")
    onNavigationRequested: function (richiesta) {
        if (richiesta.navigationType === WebEngineNavigationRequest.LinkClickedNavigation) {
            vista.collegamento(richiesta.url.toString())
            if (richiesta.reject) richiesta.reject(); else richiesta.action = WebEngineNavigationRequest.IgnoreRequest
        }
    }
    onNewWindowRequested: function (richiesta) { vista.collegamento(richiesta.requestedUrl.toString()) }
}
