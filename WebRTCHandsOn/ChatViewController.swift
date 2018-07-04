//
//  ChatViewController.swift
//  WebRTCHandsOn
//
//  Created by Takumi Minamoto on 2017/05/27.
//  Copyright © 2017 tnoho. All rights reserved.
//

import UIKit
import WebRTC
import Starscream
import SwiftyJSON

class ChatViewController: UIViewController, WebSocketDelegate, RTCPeerConnectionDelegate {
    
    func LOG(_ body: String = "",
             function: String = #function,
             line: Int = #line)
    {
        print("[\(function) : \(line)] \(body)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        
        LOG("-- peer.onaddstream()")
        DispatchQueue.main.async(execute: { () -> Void in
            // mainスレッドで実行
            if (stream.videoTracks.count > 0) {
                // ビデオのトラックを取り出して
                self.remoteVideoTrack = stream.videoTracks[0]
                // remoteVideoViewに紐づける
                self.remoteVideoTrack?.add(self.remoteVideoView)
            }
        })
    
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        if candidate.sdpMid != nil {
            sendIceCandidate(candidate)
        } else {
            LOG("empty ice event")
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        
    }
    
    func websocketDidConnect(socket: WebSocket) {
        print("connect")
        websocket?.write(string: "hello")
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        LOG("message: \(text)")
        // 受け取ったメッセージをJSONとしてパース
        let jsonMessage = JSON.parse(text)
        let type = jsonMessage["type"].stringValue
        switch (type) {
        case "answer":
            // answerを受け取った時の処理
            LOG("Received answer ...")
            let answer = RTCSessionDescription(
                type: RTCSessionDescription.type(for: type),
                sdp: jsonMessage["sdp"].stringValue)
            setAnswer(answer)
        case "candidate":
            LOG("Received ICE candidate ...")
            let candidate = RTCIceCandidate(
                sdp: jsonMessage["candidate"].stringValue,
                sdpMLineIndex: jsonMessage["sdpMLineIndex"].int32Value,
                sdpMid: jsonMessage["ice"]["sdpMid"].stringValue)
            addIceCandidate(candidate)
        default:
            return
        }
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        
    }
    
    
    func prepareNewConnection() -> RTCPeerConnection {
        // STUN/TURNサーバーの指定
        let configuration = RTCConfiguration()
        configuration.iceServers = [
            RTCIceServer.init(urlStrings:
                ["stun:stun.l.google.com:19302"])]
        // PeerConecctionの設定(今回はなし)
        let peerConnectionConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil)
        // PeerConnectionの初期化
        peerConnection = peerConnectionFactory?.peerConnection(
            with: configuration, constraints: peerConnectionConstraints, delegate: self)
        //...つづく...
        // 音声トラックの作成
        let localAudioTrack = peerConnectionFactory?
            .audioTrack(with: audioSource!, trackId: "ARDAMSa0")
        // PeerConnectionからAudioのSenderを作成
        let audioSender = peerConnection?.sender(
            withKind: kRTCMediaStreamTrackKindAudio,
            streamId: "ARDAMS")
        // Senderにトラックを設定
        audioSender?.track = localAudioTrack
        
        // 映像トラックの作成
        let localVideoTrack = peerConnectionFactory?.videoTrack(
            with: videoSource!, trackId: "ARDAMSv0")
        // PeerConnectionからVideoのSenderを作成
        let videoSender = peerConnection?.sender(
            withKind: kRTCMediaStreamTrackKindVideo,
            streamId: "ARDAMS")
        // Senderにトラックを設定
        videoSender?.track = localVideoTrack
        
        return peerConnection!
        
    }
    
    func hangUp() {
        if peerConnection != nil {
            if peerConnection?.iceConnectionState != RTCIceConnectionState.closed {
                peerConnection?.close()
            }
            peerConnection = nil
        
        }
    }
    
    var websocket: WebSocket?
    var peerConnectionFactory: RTCPeerConnectionFactory?
    var audioSource: RTCAudioSource?
    var videoSource: RTCAVFoundationVideoSource?
    var peerConnection: RTCPeerConnection?
    var remoteVideoTrack: RTCVideoTrack?

    @IBOutlet weak var cameraPreview: RTCCameraPreviewView!
    @IBOutlet weak var remoteVideoView: RTCEAGLVideoView!
    
    override func viewDidLoad() {
        print("start")
        super.viewDidLoad()
        websocket = WebSocket(url: URL(string: "ws://192.168.11.2:8182")!)
        websocket?.delegate = self
        websocket?.connect()
        
        
        peerConnectionFactory = RTCPeerConnectionFactory()
        startVideo()
        
        

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
  
    func startVideo(){
        let audioSourceConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        // 音声ソースの生成
        audioSource = peerConnectionFactory?
            .audioSource(with: audioSourceConstraints)
        
        let videoSourceConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        videoSource = peerConnectionFactory?
            .avFoundationVideoSource(with: videoSourceConstraints)
        
        
        cameraPreview.captureSession = videoSource?.captureSession
        
    }
    
    func sendSDP(_ desc: RTCSessionDescription) {
        
        let jsonSdp: JSON = [
            "sdp": desc.sdp, // SDP本体
            "type": RTCSessionDescription.string(
                for: desc.type) // offer か answer か
        ]
        // JSONを生成
        let message = jsonSdp.rawString()!
        // 相手に送信
        websocket?.write(string: message)
    }
    
    func makeOffer() {
        // PeerConnectionを生成
        peerConnection = prepareNewConnection()
        // Offerの設定 今回は映像も音声も受け取る
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true"
            ], optionalConstraints: nil)
        let offerCompletion = {
            (offer: RTCSessionDescription?, error: Error?) in
            // Offerの生成が完了した際の処理
            if error != nil { return }
            self.LOG("createOffer() succsess")
            
            let setLocalDescCompletion = {(error: Error?) in
                // setLocalDescCompletionが完了した際の処理
                if error != nil { return }
                self.LOG("setLocalDescription() succsess")
                // 相手に送る
                self.sendSDP(offer!)
            }
            // 生成したOfferを自分のSDPとして設定
            self.peerConnection?.setLocalDescription(offer!,
                                                    completionHandler: setLocalDescCompletion)
        }
        // Offerを生成
        self.peerConnection?.offer(for: constraints,
                                  completionHandler: offerCompletion)
    }
    
    func sendIceCandidate(_ candidate: RTCIceCandidate) {
        LOG("---sending ICE candidate ---")
        let jsonCandidate: JSON = [
            "type": "candidate",
            "candidate": candidate.sdp,
            " ": candidate.sdpMLineIndex,
            "sdpMid": candidate.sdpMid!
        ]
        let message = jsonCandidate.rawString()!
        LOG("sending candidate=" + message)
        websocket?.write(string: message)
    }
    
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        if peerConnection != nil {
            peerConnection?.add(candidate)
        } else {
            LOG("PeerConnection not exist!")
        }
    }


    
    
    @IBAction func connectButtonAction(_ sender: Any) {
        // Connectボタンを押した時
        if peerConnection == nil {
            LOG("make Offer")
            makeOffer()
        } else {
            LOG("peer already exist.")
        }
    }
    
    func setAnswer(_ answer: RTCSessionDescription) {
        if peerConnection == nil {
            LOG("peerConnection NOT exist!")
            return
        }
        // 受け取ったSDPを相手のSDPとして設定
        self.peerConnection?.setRemoteDescription(answer,
                 completionHandler: {
                    (error: Error?) in
                    if error == nil {
                        self.LOG("setRemoteDescription(answer) succsess")
                    } else {
                        self.LOG("setRemoteDescription(answer) ERROR: " + error.debugDescription)
                    }
                }
        )
    }

    
    
    @IBAction func hangupButtonAction(_ sender: Any) {
        hangUp()
    }
    
    @IBAction func closeButtonAction(_ sender: Any) {
        hangUp()
        websocket?.disconnect()
        _ = self.navigationController?.popToRootViewController(animated: true)
        
    }
}
