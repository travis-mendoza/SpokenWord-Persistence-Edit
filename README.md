# SpokenWord-Persistence-Edit
This extension of [Apple's SpokenWord example project](https://developer.apple.com/documentation/speech/recognizing_speech_in_live_audio) provides a work-around to the limited duration of Apple's free speech recognition service, which is (as of this writing) throttled to intervals of ~1 minute at a time.

## Notes
  * Apple also throttles each device to 1000 speech recognition requests per hour.
    * Assuming your device is not making any other speech recognition requests, that means your resetTimeInterval can be a minimum of 2.77 seconds, but you probably wouldn't want such a short interval anyway because
  * Everytime the recognition service is reset, there is a period in which the outgoing task must finish processing its speech data into text before the incoming task can begin recording speech data
    * The duration of this downtime is printed to the console, for interest's sake
    
## From here
Hopefully some of you out there find this project useful for prototyping apps that include persistent speech recognition.

For a more final solution I recommend reaching out to Apple or finding another provider of speech recognition services. In all likelihood Apple probably won't approve of an app that circumvents their restrictions, and that is not to mention that the gaps in speech recognition of this solution will almost certainly be annoying to the end user.

I think it would be interesting to find a way to save the audio data that is currently lost in resetting the recognition task, but I do not have the intention of pursuing this. If you have an idea, or improvements to the project as it stands, please let me know in an email!

## Authors
Travis Mendoza & Apple Inc.

## License
This project is licensed under the MIT License. See [the license page](https://github.com/travis-mendoza/SpokenWord-Persistence-Edit/blob/master/LICENSE/MIT%20LICENSE.txt).
