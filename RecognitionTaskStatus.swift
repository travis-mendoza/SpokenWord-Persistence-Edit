//
//  RecognitionTaskStatus.swift
//  SpokenWord Persistence Edit
//
//  Created by Travis's Macbook on 23/03/20.
//  Copyright © 2020 Travis Mendoza. All rights reserved.
//
/*
 Abstract:
 This enumeration allows the manual tracking of the state of a SFSpeechRecognitionTask
 */

enum RecognitionTaskStatus {
    case isListening
    case isFinishing
    case isInactive
}
