//
//  WebView.swift
//  Ohia
//
//  Created by iain on 08/10/2023.
//

import Dependencies
import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> some NSView {
        return webView
    }
        
    func updateNSView(_ nsView: NSViewType, context: Context) {
    }
}

protocol WebViewModelDelegate : AnyObject {
    func webViewDidLogin()
}

class WebViewModel: NSObject, ObservableObject {
    @Dependency(\.cookieService) var cookieService: any CookieService

    let webView: WKWebView
    let cookieStore: WKHTTPCookieStore
    let url: URL
    weak var delegate: (any WebViewModelDelegate)?

    override init() {
        webView = WKWebView()
        url = URL(string: "https://bandcamp.com/login")!
        cookieStore = webView.configuration.websiteDataStore.httpCookieStore

        super.init()

        webView.navigationDelegate = self
        cookieStore.add(self)
    }
    
    func clear() {
        webView.load(URLRequest(url: URL(string:"about:blank")!))
    }
    
    func loadUrl() {
        webView.load(URLRequest(url: url))
    }

    func clearCookies() async {
        cookieService.clearCookies()
        for cookie in await cookieStore.allCookies() {
            await cookieStore.deleteCookie(cookie)
        }
    }
}

extension WebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, 
                 didFinish navigation: WKNavigation!) {
        print("Navigation finished")
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("Decide policy for action: \(navigationAction)")
        if let url = navigationAction.request.mainDocumentURL?.absoluteString {
            print("URL: \(url)")
            if url.hasSuffix(".bandcamp.com/dashboard") {
                decisionHandler(.cancel)
                print("Logged in")

                delegate?.webViewDidLogin()
                return
            } else if url.hasSuffix("bandcamp.com/login") {
                print("Allow login page")
                decisionHandler(.allow)
                return
            }
        }

        if let url = navigationAction.request.mainDocumentURL {
            let host = url.host(percentEncoded: false)
            decisionHandler(host == "www.google.com" ? .allow : .cancel)
            return
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, 
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        print("Decide policy for response: \(navigationResponse)")
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, 
                 didStartProvisionalNavigation navigation: WKNavigation!) {
        print("Provo nav")
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("Commit")
    }

    func webView(_ webView: WKWebView,
                 navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        print("Became download")
    }

    func webView(_ webView: WKWebView,
                 didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("Redirect")
    }

    func webView(_ webView: WKWebView, 
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        print("Fail 1")
    }

    func webView(_ webView: WKWebView, 
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        print("Fail 2")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print("Terminate")
    }
}

extension WebViewModel: WKHTTPCookieStoreObserver {
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self else {
                return
            }

            cookies.forEach {
                self.cookieService.addCookie($0)
            }
        }
    }
}

#Preview {
    WebView(webView: WebViewModel().webView)
}
