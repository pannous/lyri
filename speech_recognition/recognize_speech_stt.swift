#!/usr/bin/env xcrun swift
// compile: xcrun swiftc record.swift && ./record

import AVFoundation
import Foundation

let DatamarketAccessUri = "https://datamarket.accesscontrol.windows.net/v2/OAuth2-13";
let client_secret=NSProcessInfo.processInfo().environment['BING_CLIENT_SECRET']
let http_body = "grant_type=client_credentials&scope=https://speech.platform.bing.com&client_id=lyri&client_secret="+client_secret
var bearer_token_session = NSURLSession.sharedSession()
var err: NSError?
var token_url =  NSURL(string: DatamarketAccessUri);
var token_request = NSMutableURLRequest(URL:token_url! ) // NSURLRequest
token_request.HTTPMethod = "POST"
token_request.HTTPBody = http_body.dataUsingEncoding(NSUTF8StringEncoding)!

func got_result(data:NSData?, response:NSURLResponse?, error:NSError? ){
    print("ANSWER")
    let result=NSString(data:data!, encoding:NSUTF8StringEncoding)
    do {
        if let jsonResult = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? NSDictionary {
            // print(jsonResult)
            let result=jsonResult["header"]!["lexical"]!;
            print(result!)
        }
    }
    catch {
        print(result)
        print("got_result error");
        print(error)
    }        
    exit(0)
}


func fix_apple_wav(var data:NSData)->NSData{
    var bytes=[UInt8](count: data.length, repeatedValue: 0)
    data.getBytes(&bytes,length:data.length) // Apple FLLR WTF
    let fix:[UInt8]=[1,0,8,0,0x64,0x61,0x74,0x61,0xcc,0x0f,0,0]// WAV data block header 
    for i in 0...fix.count-1 {
        bytes[0x20+i]=fix[i]
    }
    data=NSData(bytes:bytes,length:data.length)
    return data
}

func post_wav(token: String){
    let host = "speech.platform.bing.com";
    let contentType = "audio/wav; codec=\"audio/pcm\"; samplerate=16000; sourcerate=16000; trustsourcerate=false";
    // "audio/wav; codec=\"audio/pcm\"; samplerate=16000; sourcerate=16000; trustsourcerate=true" 
    let base="https://speech.platform.bing.com/recognize"
    let uuid = NSUUID().UUIDString
    let auth="&instanceid=6B01A9E9-EF87-4E13-9DA8-6EA846F12E76&requestid="+uuid
    let appid="D4D52672-91D7-4C74-8AD8-42B1D98141A5"
    let recognize_url=base+"?version=3.0&format=json&scenarios=ulm&appid="+appid+"&locale=en-US&device.os=Ubuntu"+auth
    let auth_string="Bearer "+token
    let request = NSMutableURLRequest(URL: NSURL(string: recognize_url)! ) // NSURLRequest
    let session = NSURLSession.sharedSession()
    // request.SendChunked = true;
    request.HTTPMethod = "POST"
    // var err: NSError?
    request.addValue(host, forHTTPHeaderField: "Host")
    request.addValue(contentType, forHTTPHeaderField: "Content-Type")
    request.addValue("application/json;text/xml", forHTTPHeaderField: "Accept") //-encoding")
    request.addValue(auth_string, forHTTPHeaderField: "Authorization")
    request.addValue("Keep-Alive", forHTTPHeaderField: "Connection")
    request.addValue("chunked", forHTTPHeaderField: "Transfer-Encoding")
    let path="record.wav"
    let data: NSData = NSData(contentsOfFile: path)!
    request.HTTPBody = fix_apple_wav(data)
    let task = session.dataTaskWithRequest(request, completionHandler: got_result);
    task.resume()
}

var access_token:String=""
func get_token(){
    let task = bearer_token_session.dataTaskWithRequest(token_request, completionHandler: {(data, response, error) in
    do {
        if let jsonResult = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? NSDictionary {
            access_token=jsonResult["access_token"] as! String
            // print(access_token)
        }
        } catch {
            print(data)
            print(error)
            exit(0)
        }
        })

    task.resume()
}

func recognize(){
            post_wav(access_token)
}

let opt=[AVLinearPCMBitDepthKey: 8, AVNumberOfChannelsKey: 1, AVSampleRateKey: 16000, AVLinearPCMIsBigEndianKey: 0,AVLinearPCMIsFloatKey: 0]
// "AVAudioSession alternative on OSX to get audio driver sample rate" WTF
print("prepare recorder")
var recorder: AVAudioRecorder? // FLLR WTF
let filePaths = NSSearchPathForDirectoriesInDomains(.TrashDirectory, .UserDomainMask, true)// .CachesDirectory, 
let firstPath = "" // filePaths[0]
// let fileName="/tmp/record.caf"
let fileName="record.wav"
let recordingPath = firstPath.stringByAppendingString(fileName)
let url = NSURL(fileURLWithPath: recordingPath)
do {
  recorder = try AVAudioRecorder(URL: url, settings: opt)
  print("recorder OK")
  }catch {
    print("nope")
}
recorder!.meteringEnabled = true
recorder!.prepareToRecord()
recorder?.record()
// print("TALK!")
get_token() // Before speech recognition is done
var good=0
var bad=0
while(true){
  NSThread.sleepForTimeInterval(NSTimeInterval(0.05))//   Milli seconds !
  recorder!.updateMeters()
  let pow=recorder!.averagePowerForChannel(0)
    // print(recorder!.peakPowerForChannel(0))
  if(pow < -25){
    if(good>3 && bad>3){
        print("ENOUGH");
        recorder!.stop();
        NSThread.sleepForTimeInterval(NSTimeInterval(1.05))
        // var fix_apple_fllr_wtf="printf '\\x01\\x00\\x08\\x00data\\x18l\\x00\\x00' | dd of=record.wav bs=1 seek=32 count=8 conv=notrunc"        
        //         NSAppleScript(source: "do shell script \"\(fix_apple_fllr_wtf)\"")!.executeAndReturnError(nil)
        recognize(); 
        break;}
    else{bad++}  
  }else{good++;bad=0}
  if(pow > -10){print("X")}
  else if(pow > -20){print("=");}
  else if(pow > -25){print("-");}
  else if(pow > -30){print("_");}
  // print(pow)
}
print("Waiting 10 seconds for result")
var i=0
while(i<10){
    i=i+1
  NSThread.sleepForTimeInterval(NSTimeInterval(1.05))
}