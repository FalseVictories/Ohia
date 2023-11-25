//
//  WebView.swift
//  Ohia
//
//  Created by iain on 08/10/2023.
//

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

class WebViewModel: ObservableObject {
    let webView: WKWebView
    let url: URL
    
    init() {
        webView = WKWebView()
        url = URL(string: "https://bandcamp.com/login")!
        
        loadUrl()
    }
    
    func loadUrl() {
        webView.load(URLRequest(url: url))
    }
}

#Preview {
    WebView(webView: WebViewModel().webView)
}
