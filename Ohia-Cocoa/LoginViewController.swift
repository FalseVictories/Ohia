//
//  LoginViewController.swift
//  Bandcamp Collection Manager
//
//  Created by iain on 02/10/2023.
//

import AppKit
import Foundation
import WebKit

final class LoginViewController: NSViewController {
    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        webView.navigationDelegate = self
        
        if let url = URL(string: "https://bandcamp.com/login") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}

extension LoginViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, 
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("Requesting navigation to \(navigationAction.request.url)")
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("Provisional navigation started: \(navigation!)")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Did finish: \(navigation!)")
    }
}
