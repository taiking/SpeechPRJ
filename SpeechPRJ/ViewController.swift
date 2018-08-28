//
//  ViewController.swift
//  SpeechPRJ
//
//  Created by 辻林大揮 on 2018/08/02.
//  Copyright © 2018年 chocovayashi. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private func startRecording() throws {
        refreshTask()
        
        let audioSession = AVAudioSession.sharedInstance()
        // 録音用のカテゴリをセット
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else { fatalError("Error") }
        
        // 録音が完了する前のリクエストを作るかどうかのフラグ。
        // trueだと現在-1回目のリクエスト結果が返ってくる模様。falseだとボタンをオフにしたときに音声認識の結果が返ってくる設定。
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let `self` = self else { return }
            
            var isFinal = false
            
            if let result = result {
                print(result.bestTranscription.formattedString)
                print("--------------")
                self.analyzeText(text: result.bestTranscription.formattedString)
                print("--------------")
                isFinal = result.isFinal
            }
            
            // エラーがある、もしくは最後の認識結果だった場合の処理
            if error != nil || isFinal {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                print("停止しました")
            }
        }
        
        // マイクから取得した音声バッファをリクエストに渡す
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        try startAudioEngine()
    }
    
    private func refreshTask() {
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
    }
    
    private func startAudioEngine() throws {
        // startの前にリソースを確保しておく。
        audioEngine.prepare()
        
        try audioEngine.start()
        
        print("しゃべってください！！")
    }
    
    func tappedStartButton() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            print("停止しました")
        } else {
            try! startRecording()
            print("開始しました。")
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            // メインスレッドで処理したい内容のため、OperationQueue.main.addOperationを使う
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    print("許可されたよ")
                case .denied:
                    print("拒否されたよ")
                case .restricted:
                    print("クソ端末")
                case .notDetermined:
                    print("まだ許可されてないよー")
                }
            }
        }
        
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            self.tappedStartButton()
        }
    }
}

extension ViewController {
    func analyzeText(text: String) {
        let tagger = NSLinguisticTagger(tagSchemes: NSLinguisticTagger.availableTagSchemes(forLanguage: "ja"), options: 0)
        
        tagger.string = text
        
        // NSLinguisticTagSchemeTokenType
        // Word, Punctuation, Whitespace, Otherで判別が可能。今回はoptionsで.omitWhitespaceを設定して空白を無視するようにしています。
        tagger.enumerateTags(in: NSRange(location: 0, length: text.count), scheme: .tokenType, options: [.omitWhitespace]) { tag, tokenRange, sentenceRange, stop in
            
            let subString = (text as NSString).substring(with: tokenRange)
            print("\(subString) : \(tag!.rawValue)")
        }
    }
}
