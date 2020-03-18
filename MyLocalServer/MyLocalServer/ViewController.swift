//
//  ViewController.swift
//  MyLocalServer
//
//  Created by lufei on 2020/3/17.
//  Copyright © 2020 test. All rights reserved.
//

import UIKit
import NIO
import NIOHTTP1
import NIOTransportServices
import WebKit

final class DummyHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        
        let reqPart = unwrapInboundIn(data)

        switch reqPart {
            case .head(let header):
                  print("req:", header)
            
                  let head = HTTPResponseHead(version: header.version,
                                              status: .ok)
                                    
                  let part = HTTPServerResponsePart.head(head)
                  _ = context.channel.write(part)
                  
                  /// 准备测试数据
                  let path = "file:///myWeb.html"
                  let myData = try? Data.init(contentsOf: URL(string: path)!)
                  let str = String.init(data: myData ?? Data(), encoding: .utf8)
                  
                  var buffer = context.channel.allocator.buffer(capacity: 140)
                  buffer.writeString(str ?? "error")
                                  
                  let bodypart = HTTPServerResponsePart.body(.byteBuffer(buffer))
                  _ = context.channel.write(bodypart)
                  
                  let endpart = HTTPServerResponsePart.end(nil)
                  _ = context.channel.writeAndFlush(endpart)
            
            case .body, .end: break
        }
        
    }
}

class Server {

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    func start() {
        do {
            let bootstrap = NIOTSListenerBootstrap(group: group)
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline()
                        .flatMap {
                            channel.pipeline.addHandler(DummyHandler())
                    }
            }
            let channel = try bootstrap
                .bind(host: host, port: port)
                .wait()
            
            try channel.closeFuture.wait()
        } catch {
            print("An error happed \(error.localizedDescription)")
            exit(0)
        }
    }
    
    func stop() {
        do {
            try group.syncShutdownGracefully()
        } catch {
            print("An error happed \(error.localizedDescription)")
            exit(0)
        }
    }
    
    // MARK: - Private properties
    private let group = NIOTSEventLoopGroup()
    private var host: String
    private var port: Int
}

class ViewController: UIViewController {
    
    @IBOutlet weak var wkWebView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
                
        let button = UIButton()
        button.frame = view.bounds
        button.setTitle("加载", for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.addTarget(self, action: #selector(loadWeb(button:)), for: .touchUpInside)
        view.addSubview(button)
        
        DispatchQueue.global().async {
            
            let app = Server(host: "localhost", port: 8888)
            app.start()
            
        }
                
    }
    
    @objc func loadWeb(button:UIButton) {
        
        button.removeFromSuperview()
        
        let url = URL(string: "http://localhost:8888")
        let req = URLRequest(url: url!)
        self.wkWebView.load(req)
        
    }

}

