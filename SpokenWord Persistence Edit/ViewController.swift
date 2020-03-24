//  ViewController.swift
//  SpokenWord Persistence Edit
//
//  Created by Travis Mendoza on 23/03/20.
//  Copyright © 2020 Travis Mendoza. All rights reserved.
//
/*
Abstract:
This is the app's root view controller.
 
 Interface - It provides a button that allows the user to start and stop recording from their iPhone mic and a text field that displays live speech-to-text data transcribed from the recording.
 
 Backend - The speech-to-text functionality is also all housed in this file. Because Apple's Speech Recognition service can only be accessed for ~1 minute by default, a behind-the-scenes timer stops and restarts the recognition task without input from the user. For sake of interest, the app prints the time its recognition task spent offline to the console every time it resets.
*/

import UIKit
import Speech

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    // MARK: Properties
    
    // Interface
    @IBOutlet var textView: UITextView!
    @IBOutlet var recordButton: UIButton!
    
    // Recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private lazy var inputNode: AVAudioInputNode = audioEngine.inputNode
    
    // Timing
    private var resetTimer: Timer?
    private let resetInterval = 15.0 // seconds between resets of speech recognition task in background
    private var timeTaskStartedListening: Date?
    private var timeTaskStoppedListening: Date?
    
    // Stop/Start/Reset variables
    // Does the user want the conversation recognized right now?
    private var recognitionIsActive = false
    // What is the Apple Speech Recognition task currently doing? Used for resetting behind the scenes
    private var recognitionTaskStatus = RecognitionTaskStatus.isInactive {
        didSet {
            switch recognitionTaskStatus {
            case .isInactive:
                // If recognition service has ended, break down its setup so that it is prepared to build and run again
                inputNode.removeTap(onBus: 0)
                recognitionRequest = nil
                recognitionTask = nil
                
                // Begin recognition again if user has not stopped the recording
                if recognitionIsActive {
                    do {
                        try startRecording()
                        setResetTimer()
                    } catch {
                        print("Incoming error from recognitionTaskStatus observer\n =>" + error.localizedDescription)
                    }
                }
            case .isListening:
                // Save time task starts to quantify the time that is lost between tasks
                timeTaskStartedListening = Date()
                guard let timeLastTaskStoppedListening = timeTaskStoppedListening else {
                    return
                }
                timeTaskStoppedListening = nil // clean-up, stops count when user ends recording
                let timeLost = timeTaskStartedListening!.timeIntervalSince(timeLastTaskStoppedListening)
                let roundedTimeLost = round(timeLost * 1000) / 1000
                print("Time lost between recognition task finishing and beginning again was \(roundedTimeLost) seconds")
            case .isFinishing:
                timeTaskStoppedListening = Date() // For quantifying time lost in downtime
            }
        }
    }
    
    
    // MARK: View Controller Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        
        // The tap gesture recognizer allows dismissal of pop-up keyboard by tapping outside of the text field
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        speechRecognizer.delegate = self
        
        // Asynchronously make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in

            // Divert to the app's main thread so that the UI
            // can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                    
                default:
                    self.recordButton.isEnabled = false
                }
            }
        }
    }
    
    
    // MARK: Speech-to-Text
    private func startRecording() throws {
        // Cancel the previous task if it's running.
        recognitionTask?.cancel() // Extra precaution
        self.recognitionTask = nil // Extra precaution
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = false
        
        // Keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            // We won't be working with partial results, so this statement only updates the status of the result
            if let result = result {
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                // Add the recognition result to the text view and scroll to the bottom
                if let result = result {
                    self.textView.text += result.bestTranscription.formattedString + " "
                    let bottom = NSMakeRange(self.textView.text.count - 1, 1)
                    self.textView.scrollRangeToVisible(bottom)
                }
                // Error can result from silence, so all we want to do with it here is print to console. If it affects UX that would be bad
                if let error = error {
                    print("\nDEBUG: Error thrown in recognition task completion handler\n => \(error)\n")
                }
                // If user has stopped recognition, reactivate the start button so they can begin again if they wish
                if !self.recognitionIsActive {
                    self.recordButton.isEnabled = true
                    self.recordButton.setTitle("Start Recording", for: [])
                }
                // This recognition task has finished completely, as we have reached the end of its completion handler
                self.recognitionTaskStatus = .isInactive
            }
        }

        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        recognitionTaskStatus = .isListening
    }
    
    
    // MARK: Timing
    func reset(timer: Timer) {
        // breakdown
        if recognitionIsActive {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recognitionTask!.finish() // probably unnecessary
            recognitionTaskStatus = .isFinishing
        }
    }
    
    func setResetTimer() {
        resetTimer = Timer(timeInterval: resetInterval, repeats: false, block: reset(timer:))
        RunLoop.current.add(resetTimer!, forMode: .common)
    }
    
    
    // MARK: SFSpeechRecognizerDelegate
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }
    
    
    // MARK: Interface Builder actions
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            // Stop recognition service and the timer that would restart it
            resetTimer?.invalidate()
            resetTimer = nil
            recognitionIsActive = false
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                // Begin recognition service and set the timer that will reset recognition for the purpose of persistence.
                try startRecording()
                recognitionIsActive = true
                setResetTimer()
                recordButton.setTitle("Stop Recording", for: [])
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
}

