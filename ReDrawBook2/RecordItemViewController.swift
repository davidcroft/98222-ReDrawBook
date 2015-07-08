//
//  RecordItemViewController.swift
//  ReDrawBook2
//
//  Created by Ding Xu on 10/14/14.
//  Copyright (c) 2014 Ding Xu. All rights reserved.
//
//  Parse server name:
//  audioName: username-bookname-pageIndex
//

import UIKit
import AVFoundation

class RecordItemViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, AVAudioRecorderDelegate, AVAudioPlayerDelegate {

    @IBOutlet var RecordItemPageImg: UIImageView!
    @IBOutlet var RecordItemPageTitle: UILabel!
    @IBOutlet var RecordItemPageDesp: UILabel!
    @IBOutlet var RecordItemPageTableView: UITableView!
    @IBOutlet var LoadingIndicator: UIActivityIndicatorView!
    
    var bookInfo: BookInfo!
    var pages:[PageInfo] = []
    
    
    // audio recorder and player
    var recorder: AVAudioRecorder!
    var player:AVAudioPlayer!
    // record meter
    var meterTimer:NSTimer!
    var timerStr:String!
    // play meter
    var playMeterTimer: NSTimer!
    var playTimeStr: String!
    var startPlayIndex: Int = -1
    
    var soundFileURL:NSURL?
    var currentFileName: String?
    var startRecIndex: Int = -1
    var deleteList:[String] = []
    var tempTimer:NSTimer!
    
    var uploadFlag:Bool = false
    
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.RecordItemPageTitle.text = self.bookInfo.title
        self.RecordItemPageDesp.text = self.bookInfo.description
        self.RecordItemPageImg.image = self.bookInfo.coverImage
        //self.RecordItemPageImg.image = UIImage(data: NSData(contentsOfURL: NSURL(string: self.albumInfo!.largeImageURL)!)!)
        
        // start loading indicator
        self.startLoadingIndicator()
        
        // get all the pages info, display
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { () -> Void in
            var query = PFQuery(className: "page")
            query.whereKey("bookName", equalTo:self.bookInfo.title)
            query.addAscendingOrder("pageIndex")
            query.findObjectsInBackgroundWithBlock {
                (objects:[AnyObject]!, error: NSError!) ->Void in
                if (error == nil) {
                    for object in objects {
                        var bookName: String = object.objectForKey("bookName") as! String
                        if (bookName == self.bookInfo.title) {
                            var pageIndex: Int = object.objectForKey("pageIndex") as! Int
                            var pageTitle: String = object.objectForKey("pageTitle") as! String
                            var pageImagePF: PFFile? = object.objectForKey("pageImage") as! PFFile?
                            var pageImageData: NSData? = pageImagePF?.getData() as NSData?
                            var pageCoverImage: UIImage!
                            if (pageImageData != nil ) {
                                pageCoverImage = UIImage(data: pageImageData!)!
                            } else {
                                pageCoverImage = UIImage(named:"bookThumbDefault.jpg")!
                            }
                            
                            // retrieve page audio length: block method
                            let audioName = "username-\(self.bookInfo.title)-Page\(pageIndex).m4a"
                            let pageLength: String = self.queryBlockForAudioTrackLength(audioName)
                            
                            // create a new pageItem and append it to pages
                            var newPageItem:PageInfo = PageInfo(title: pageTitle, index: pageIndex, pageImage: pageCoverImage, length: pageLength)
                            /*dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.pages.append(newPageItem)
                            })*/
                            self.pages.append(newPageItem)
                        }
                    }
                    
                    // reload table view
                    self.RecordItemPageTableView.rowHeight = 50
                    self.RecordItemPageTableView.reloadData()
                    
                    // stop loading indicator
                    self.stopLoadingIndicator()
                }
            }
        })
        
        // init recording
        self.setSessionPlayback()
        //self.askForNotifications()
        self.deleteAllRecordings()
    }
    
    // recording audio meter
    func updateAudioMeter(timer:NSTimer) {
        if self.recorder.recording {
            let dFormat = "%02d"
            let min:Int = Int(self.recorder.currentTime / 60)
            let sec:Int = Int(self.recorder.currentTime % 60)
            self.timerStr = "\(String(format: dFormat, min)):\(String(format: dFormat, sec))"
            self.RecordItemPageTableView.reloadData()
            self.recorder.updateMeters()
            //var apc0 = self.recorder.averagePowerForChannel(0)
            //var peak0 = self.recorder.peakPowerForChannel(0)
        }
    }
    
    func updateAudioPlayMeter(timer:NSTimer) {
        // playing audio meter
        if self.player.playing {
            let dFormat = "%02d"
            let min:Int = Int(self.player.currentTime / 60)
            let sec:Int = Int(self.player.currentTime % 60)
            self.playTimeStr = "\(String(format: dFormat, min)):\(String(format: dFormat, sec))"
            self.RecordItemPageTableView.reloadData()
            self.player.updateMeters()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        self.recorder = nil
        self.player = nil
    }
    
    // MARK: UITableViewDataSource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.pages.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("AlbumItem") as? RecordAlbumTableViewCell ?? RecordAlbumTableViewCell()
        
        let page = pages[indexPath.row]
        cell.titleLabel.text = "\(page.pageIndex)/\(bookInfo.pagesNum): \(page.pageTitle)"
        cell.pageLength.text = page.pageLength
        cell.pageCoverImage.image = page.pageImage
        cell.titleLabel.textColor = UIColor.blackColor()
        cell.pageLength.textColor = UIColor.blackColor()
        cell.backgroundColor = UIColor.whiteColor()
        
        // customized selection style
        let cellBGView = UIView()
        // don't forget to divide by 255 from R G B value
        //cellBGView.backgroundColor = UIColor(red: 140/255, green: 206/255, blue: 110/255, alpha: 1)
        cellBGView.backgroundColor = UIColor(red: 0.298, green: 0.851, blue: 0.3922, alpha: 1.0)
        // must set to a style and then customize the background, because style set to be none later
        cell.selectionStyle = UITableViewCellSelectionStyle.Blue        // important
        cell.selectedBackgroundView = cellBGView
        
        if self.startRecIndex == page.pageIndex {
            cell.titleLabel.textColor = UIColor.whiteColor()
            cell.pageLength.textColor = UIColor.whiteColor()
            cell.backgroundColor = UIColor.redColor()
            cell.selectionStyle = UITableViewCellSelectionStyle.None
            
            cell.pageLength.text = self.timerStr
        }
        
        // after start recording, select table view cell will has no effect but to pop up action sheet
        if self.startRecIndex > 0 {
            cell.selectionStyle = UITableViewCellSelectionStyle.None
        }
        
        // if playing audio, display the meter in length field
        if self.player != nil && self.player.playing && self.startPlayIndex == page.pageIndex {
            cell.pageLength.text = self.playTimeStr
            cell.backgroundColor = UIColor(red: 0.298, green: 0.851, blue: 0.3922, alpha: 1.0)
            cell.titleLabel.textColor = UIColor.whiteColor()
            cell.pageLength.textColor = UIColor.whiteColor()
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {

        // ############## //
        //  is recording  //
        // ############## //
        if (self.startRecIndex > 0) {
            let cell = tableView.dequeueReusableCellWithIdentifier("AlbumItem") as?
                RecordAlbumTableViewCell ?? RecordAlbumTableViewCell()
            
            // pausing recording
            if self.recorder != nil && self.recorder.recording {
                println("pausing")
                self.recorder.pause()
            }
            
            // update alert view
            let alertController = UIAlertController(title: "Recording", message: self.timerStr, preferredStyle: .ActionSheet)
            
            ////////////// continue recording ////////////
            let continueAction = UIAlertAction(title: "Continue", style: .Cancel, handler: {
                action in
                if self.recorder != nil {
                    println("continue recording")
                    self.recorder.record()
                    //self.recordWithPermission(false)
                } else {
                    println("recording has finished")
                    println("startRecIndex:\(self.startRecIndex)")
                    self.RecordItemPageTableView.reloadData()
                }
                
            })
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            
            ////////////// play audio ////////////
            let playAction = UIAlertAction(title: "Play", style: .Default, handler: {
                action in
                // stop first if wanna playing audio
                //println(self.recorder.recording)
                if self.recorder != nil {
                    NSLog("stop recording")
                    self.recorder.stop()
                    self.meterTimer.invalidate()
                    
                    // disable audio session
                    let session:AVAudioSession = AVAudioSession.sharedInstance()
                    var error: NSError?
                    if !session.setActive(false, error: &error) {
                        println("could not make session inactive")
                        if let e = error {
                            println(e.localizedDescription)
                            return
                        }
                    }
                    self.recorder = nil
                    
                    // update startRecIndex
                    self.startRecIndex = -1
                }
                
                // start playing
                var error: NSError?
                self.player = AVAudioPlayer(contentsOfURL: self.soundFileURL!, error: &error)
                if self.player == nil {
                    if let e = error {
                        println(e.localizedDescription)
                    }
                }
                self.player.delegate = self
                self.player.prepareToPlay()
                self.player.volume = 1.0
                self.player.play()
                self.presentViewController(alertController, animated: true, completion: nil)
            })
            
            /////////////// upload audio file ////////////
            let uploadAction = UIAlertAction(title: "Upload", style: .Default, handler: {
                action in
                // stop first if wanna upload audio
                
                // hit upload button directly
                if self.recorder != nil {
                    NSLog("stop recording")
                    self.recorder.stop()
                    self.meterTimer.invalidate()
                    
                    // disable audio session
                    let session:AVAudioSession = AVAudioSession.sharedInstance()
                    var error: NSError?
                    if !session.setActive(false, error: &error) {
                        println("could not make session inactive")
                        if let e = error {
                            println(e.localizedDescription)
                            return
                        }
                    }
                    self.recorder = nil
                    
                    // update startRecIndex
                    self.startRecIndex = -1
                    
                    // upload file
                    self.uploadFlag = true
                }
                
                // hit upload button after playing
                else {
                    // stop playing if player is playing audio track
                    if self.player != nil && self.player.playing {
                        self.player.stop()
                        //self.playMeterTimer.invalidate()
                    }
                    
                    // upload file
                    self.uploadFlag = true
                    self.uploadAudioTrack()
                }
                
                // reload ui
                self.RecordItemPageTableView.reloadData()

            })
            
            //alertController.addAction(StopAction)
            alertController.addAction(playAction)
            alertController.addAction(uploadAction)
            alertController.addAction(continueAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        }
        
        // ########### //
        //   PLAYING   //
        // ########### //
        else {
            // not recording, play audio after click on corresponding table view cell
            let cell = tableView.dequeueReusableCellWithIdentifier("AlbumItem") as?
                RecordAlbumTableViewCell ?? RecordAlbumTableViewCell()
            let page = pages[indexPath.row]
            
            // stop recording (should never be true)
            if self.recorder != nil {
                self.recorder.stop()
            }
            
            // stop playing if player is playing audio track
            if self.player != nil && self.player.playing {
                self.player.stop()
                self.playMeterTimer.invalidate()
                
                // check stop playing or play another record
                if self.startPlayIndex == page.pageIndex {
                    // stop playing
                    self.clearPlayIndex()
                    return
                }
                
                // play another track
                self.clearPlayIndex()
                
            }
            
            // start loading indicator
            self.startLoadingIndicator()
            
            // retrieve audio track and play, pageIndex in server starts from 1 instead of 0
            let pageIndex:String = String(indexPath.row + 1)
            println("PLAY: pageIndex = \(pageIndex)")
            var query = PFQuery(className: "soundtracks")
            // generate the audioName of clicked page for query (username-bookTitle-pageIndex.m4a)
            query.whereKey("audioName", equalTo:"username-\(self.bookInfo.title)-Page\(pageIndex).m4a")
            query.findObjectsInBackgroundWithBlock {
                (objects:[AnyObject]!, error: NSError!) ->Void in
                if (error == nil) {
                    if objects.count != 0 {
                        // has record in the server
                        let userObject:PFObject = objects.first as! PFObject
                        let audioFile: PFFile! = userObject.objectForKey("audioFile") as! PFFile
                        let recordURL: NSURL = NSURL(string: audioFile.url)!
                        let recordData: NSData = NSData(contentsOfURL: recordURL)!
                        var error: NSError?
                        
                        // play remote audio with URL, use AVAudioPlayer(data: recordData, error: &error)
                        self.player = AVAudioPlayer(data: recordData, error: &error)
                        if self.player == nil {
                            if let e = error {
                                println(e.localizedDescription)
                                return
                            }
                        }
                        self.player.delegate = self
                        self.player.prepareToPlay()
                        self.player.volume = 1.0
                        self.player.play()
                        
                        // update play meter
                        self.startPlayIndex = indexPath.row + 1
                        self.playMeterTimer = NSTimer.scheduledTimerWithTimeInterval(0.1,
                            target:self,
                            selector:"updateAudioPlayMeter:",
                            userInfo:nil,
                            repeats:true)

                    }
                    else {
                        // has no record in the server
                        let alertController = UIAlertController(title: nil, message: "Found no record in server, record now?", preferredStyle: .Alert)
                        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
                        let recordAction = UIAlertAction(title: "Record", style: .Default, handler: {
                            action in
                            // start recording for table view cell, pageIndex start from 1 instead of 0, so indexPath.row + 1
                            self.startRecording(indexPath.row + 1)
                            
                        })
                        alertController.addAction(recordAction)
                        alertController.addAction(cancelAction)
                        self.presentViewController(alertController, animated: true, completion: nil)
                    }
                }
                
                // stop loading indicator
                self.stopLoadingIndicator()
                
            }
        }
    }

    /////////////// swipe left to appear buttons /////////////
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        /*if editingStyle == .Delete {
            println("COMMIT-DELETE")
        } else if editingStyle == .Insert {
            println("COMMIT-INSERT")
        }*/
        return
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        
        let page = pages[indexPath.row]
    
        var moreRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "More", handler:{action, indexpath in
            println("MORE•ACTION");

            // Action menu
            // destructiveButtonTitle: display on red options (delete etc...)
            /*let actionSheetMore = UIActionSheet(title: "More", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Delete Aduio in Server", "Download Locally")
            actionSheetMore.showInView(self.view)*/
            
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            let deleteAction = UIAlertAction(title: "Delete Audio in Server", style: .Destructive, handler:{
                action in
                
                //alertController.setValue("00:01", forKey: "message")
                // find object in server
                let audioName = "username-\(self.bookInfo.title)-Page\(page.pageIndex).m4a"
                let deleteRes = self.deleteBlockForAudioTrack(audioName)
                
                if deleteRes == 0 {
                    // delete succeed
                    let alertControllerMsg = UIAlertController(title: nil, message: "Delete Succeed", preferredStyle: .Alert)
                    // dismiss view controller automatically in a 1s
                    self.presentViewController(alertControllerMsg, animated: true, completion: { () -> Void in
                        // set a timer for notification
                        self.tempTimer = NSTimer.scheduledTimerWithTimeInterval(1.5,
                            target:self,
                            selector:"updateTempTimer:",
                            userInfo:nil,
                            repeats:false)
                    })
                    // upload page info (length) and reload page
                    self.updatePageLength()
                    
                } else if deleteRes > 0 {
                    // delete fail
                    let alertControllerMsg = UIAlertController(title: nil, message: "Delete Fail", preferredStyle: .Alert)
                    // dismiss view controller automatically in a 1s
                    self.presentViewController(alertControllerMsg, animated: true, completion: { () -> Void in
                        // set a timer for notification
                        self.tempTimer = NSTimer.scheduledTimerWithTimeInterval(1.5,
                            target:self,
                            selector:"updateTempTimer:",
                            userInfo:nil,
                            repeats:false)
                    })
                    // do not need to upload page info (length) but reload page
                    self.RecordItemPageTableView.reloadData()
                    
                } else if deleteRes < 0 {
                    // cannot find record in server
                    let alertControllerMsg = UIAlertController(title: nil, message: "No Record in Server", preferredStyle: .Alert)
                    // dismiss view controller automatically in a 1s
                    self.presentViewController(alertControllerMsg, animated: true, completion: { () -> Void in
                        // set a timer for notification
                        self.tempTimer = NSTimer.scheduledTimerWithTimeInterval(1.5,
                            target:self,
                            selector:"updateTempTimer:",
                            userInfo:nil,
                            repeats:false)
                    })
                    // do not need to upload page info (length) but reload page
                    self.RecordItemPageTableView.reloadData()
                }
            })
            
            alertController.addAction(deleteAction)
            alertController.addAction(cancelAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        });
        moreRowAction.backgroundColor = UIColor(red: 0.298, green: 0.851, blue: 0.3922, alpha: 1.0);
        
        var recordRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Record", handler:{action, indexpath in
            println("RECORD•ACTION");
            // alert controller
            let alertController = UIAlertController(title: "Start Recording", message: nil, preferredStyle: .Alert)
            // cancel action
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            // start action
            let startAction = UIAlertAction(title: "Start", style: .Default, handler: {
                action in
                // start recording for table view cell
                self.startRecording(indexPath.row+1)
            })
            
            alertController.addAction(startAction)
            alertController.addAction(cancelAction)
            
            self.presentViewController(alertController, animated: true, completion: nil)
        });
        
        //return [deleteRowAction, deleteAllRowAction, moreRowAction];
        return [recordRowAction, moreRowAction];
    }
    
    ///////////////////
    

    //////////////////
    // recording
    func setSessionPlayback() {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        var error: NSError?
        if !session.setCategory(AVAudioSessionCategoryPlayback, error:&error) {
            NSLog("could not set session category")
            if let e = error {
                println(e.localizedDescription)
            }
        }
        if !session.setActive(true, error: &error) {
            NSLog("could not make session active")
            if let e = error {
                println(e.localizedDescription)
            }
        }
    }
    
    func setSessionPlayAndRecord() {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        var error: NSError?
        if !session.setCategory(AVAudioSessionCategoryPlayAndRecord, error:&error) {
            NSLog("could not set session category")
            if let e = error {
                println(e.localizedDescription)
            }
        }
        if !session.setActive(true, error: &error) {
            NSLog("could not make session active")
            if let e = error {
                println(e.localizedDescription)
            }
        }
    }
    
    func askForNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector:"background:",
            name:UIApplicationWillResignActiveNotification,
            object:nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector:"foreground:",
            name:UIApplicationWillEnterForegroundNotification,
            object:nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector:"routeChange:",
            name:AVAudioSessionRouteChangeNotification,
            object:nil)
    }
    
    func setupRecorder() {
        self.currentFileName = "\(bookInfo.title)-Page\(startRecIndex).m4a"
        println(self.currentFileName)
        var dirPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        var docsDir: AnyObject = dirPaths[0]
        var soundFilePath = docsDir.stringByAppendingPathComponent(self.currentFileName!)
        self.soundFileURL = NSURL(fileURLWithPath: soundFilePath)
        println("soundFileURL: \(self.soundFileURL)")
        let filemanager = NSFileManager.defaultManager()
        if filemanager.fileExistsAtPath(soundFilePath) {
            // probably won't happen. want to do something about it?
            println("sound exists")
        }
        
        var recordSettings = [
            AVFormatIDKey: kAudioFormatAppleLossless,
            AVEncoderAudioQualityKey : AVAudioQuality.Max.rawValue,
            AVEncoderBitRateKey : 320000,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey : 44100.0
        ]
        var error: NSError?
        self.recorder = AVAudioRecorder(URL: soundFileURL!, settings: recordSettings as [NSObject : AnyObject], error: &error)
        if let e = error {
            println(e.localizedDescription)
        } else {
            self.recorder.delegate = self
            self.recorder.meteringEnabled = true
            self.recorder.prepareToRecord() // creates/overwrites the file at soundFileURL
        }
    }
    
    func startRecording(pageIndex:Int) {
        // set startRecIndex
        self.startRecIndex = pageIndex
        // stop playing if player is playing audio track
        if self.player != nil && self.player.playing {
            self.player.stop()
            self.playMeterTimer.invalidate()
            self.clearPlayIndex()
        }
        if (self.recorder == nil) {
            NSLog("recorder nil, start recording")
            self.recordWithPermission(true)
        }
        else if (self.recorder != nil && !self.recorder.recording) {
            // should never come to here
            NSLog("SHOULD NEVER COME TO HERE: recorder not nil, continue recording")
            self.recordWithPermission(false)
        }
        self.RecordItemPageTableView.reloadData()
    }
    
    func recordWithPermission(setup:Bool) {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        // ios 8 and later
        if (session.respondsToSelector("requestRecordPermission:")) {
            AVAudioSession.sharedInstance().requestRecordPermission({(granted: Bool)-> Void in
                if granted {
                    println("Permission to record granted")
                    self.setSessionPlayAndRecord()
                    if setup {
                        self.setupRecorder()
                    }
                    self.recorder.record()
                    self.meterTimer = NSTimer.scheduledTimerWithTimeInterval(0.1,
                        target:self,
                        selector:"updateAudioMeter:",
                        userInfo:nil,
                        repeats:true)
                } else {
                    println("Permission to record not granted")
                }
            })
        } else {
            println("requestRecordPermission unrecognized")
        }
    }
    
    func deleteAllRecordings() {
        var docsDir =
        NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
        var fileManager = NSFileManager.defaultManager()
        var error: NSError?
        var files = fileManager.contentsOfDirectoryAtPath(docsDir, error: &error) as! [String]
        if let e = error {
            println(e.localizedDescription)
        }
        var recordings = files.filter( { (name: String) -> Bool in
            return name.hasSuffix("m4a")
        })
        for var i = 0; i < recordings.count; i++ {
            var path = docsDir + "/" + recordings[i]
            
            println("removing \(path)")
            if !fileManager.removeItemAtPath(path, error: &error) {
                NSLog("could not remove \(path)")
            }
            if let e = error {
                println(e.localizedDescription)
            }
        }
    }
    
    // MARK: AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder!,
        successfully flag: Bool) {
            println("finished recording \(flag)")
            if self.uploadFlag {
                self.uploadAudioTrack()
            }
    }
    
    // upload a file into server of Parse
    func uploadAudioTrack() {
        var fileManager = NSFileManager.defaultManager()
        var docsDir =
        NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
        let fileExist = fileManager.fileExistsAtPath(docsDir + "/" + self.currentFileName!)
        if fileExist && self.uploadFlag {
            // upload file
            // check if there is an item in server
            var query = PFQuery(className: "soundtracks")
            query.whereKey("audioName", equalTo:"username-\(self.currentFileName!)")
            query.findObjectsInBackgroundWithBlock {
                (objects:[AnyObject]!, error: NSError!) ->Void in
                if (error == nil) {
                    var userAudio:PFObject
                    let audioPath: NSURL = self.soundFileURL!
                    let audioData: NSData = NSData(contentsOfURL: audioPath)!
                    let userAudioFile: PFFile  = PFFile(name: self.currentFileName, data: audioData)
                    
                    if objects.count == 0 {
                        // not exist in server
                        userAudio = PFObject(className:"soundtracks")
                    } else {
                        userAudio = objects.first as! PFObject
                    }
                    
                    userAudio["audioName"] = "username-\(self.currentFileName!)"
                    userAudio["audioFile"] = userAudioFile
                    userAudio["audioLength"] = self.timerStr
                    
                    // add the url into delete list
                    self.deleteList.append(docsDir + "/" + self.currentFileName!)
                    
                    var error:NSError
                    var succeeded:Bool!
                    userAudio.saveInBackgroundWithBlock({
                        (succeeded: Bool, error: NSError!) -> Void in
                        if succeeded == true {
                            println("upload successfully")
                            // delete all files in delete list
                            var error:NSError?
                            for deleteFile in self.deleteList {
                                if fileManager.fileExistsAtPath(deleteFile) {
                                    if !fileManager.removeItemAtPath(deleteFile, error: &error) {
                                        NSLog("could not remove file")
                                    } else {
                                        NSLog("remove file")
                                    }
                                    if let e = error {
                                        println(e.localizedDescription)
                                    }
                                }
                            }
                            // alert controller
                            let alertController = UIAlertController(title: "Upload finished!", message: nil, preferredStyle: .Alert)
                            // dismiss view controller automatically in a 1s
                            self.presentViewController(alertController, animated: true, completion: { () -> Void in
                                // upload page info (length) and reload page
                                self.updatePageLength()
                                // set a timer for notification
                                self.tempTimer = NSTimer.scheduledTimerWithTimeInterval(1.5,
                                    target:self,
                                    selector:"updateTempTimer:",
                                    userInfo:nil,
                                    repeats:false)
                            })
                        }
                        
                        ///////////////////////
                        ////    UNDEBUG    ////
                        ///////////////////////
                        else {
                            // upload fail, re-upload
                            NSLog("Upload fail")
                            // alert controller
                            let alertController = UIAlertController(title: "Upload failed", message: nil, preferredStyle: .Alert)
                            // cancel upload, delete local file
                            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler:{
                                action in
                                // delete all files in delete list
                                var error:NSError?
                                for deleteFile in self.deleteList {
                                    if fileManager.fileExistsAtPath(deleteFile) {
                                        if !fileManager.removeItemAtPath(deleteFile, error: &error) {
                                            NSLog("could not remove file")
                                        } else {
                                            NSLog("remove file")
                                        }
                                        if let e = error {
                                            println(e.localizedDescription)
                                        }
                                    }
                                }
                            })
                            // retry upload, call uploadAudioTrack again
                            let retryAction = UIAlertAction(title: "Retry", style: .Default, handler:{
                                action in
                                // set flag to true to re-upload
                                self.uploadFlag = true      // might have some bugs here
                                self.uploadAudioTrack()
                            })
                            self.presentViewController(alertController, animated: true, completion: nil)
                        }
                    })
                    
                    // set flag
                    self.uploadFlag = false
                }
            }
        }
    }
    
    func queryBlockForAudioTrackLength(audioName: String) -> String {
        let queryAudio = PFQuery(className: "soundtracks")
        queryAudio.whereKey("audioName", equalTo:audioName)
        var error: NSError?
        let userAudioObjects: [PFObject] = queryAudio.findObjects(&error) as! [PFObject]
        var pageLength: String
        if userAudioObjects.count != 0 {
            let userAudioObject: PFObject = userAudioObjects.first!
            pageLength = userAudioObject.objectForKey("audioLength") as! String
        } else {
            pageLength = "00:00"
        }
        return pageLength
    }
    
    // return 0-delete succeed; 1-delete false; -1-cannot find file in the server
    func deleteBlockForAudioTrack(audioName: String) -> Int {
        let queryAudio = PFQuery(className: "soundtracks")
        queryAudio.whereKey("audioName", equalTo:audioName)
        var error: NSError
        let userAudioObjects: [PFObject] = queryAudio.findObjects() as! [PFObject]
        var pageLength: String
        if userAudioObjects.count != 0 {
            for userAudioObject in userAudioObjects {
                var error:NSError?
                userAudioObject.delete(&error)
                if error == nil {
                    // delete succeed
                    continue
                } else {
                    // delete fail
                    println(error)
                    return 1
                }
            }
        } else {
            // cannot find record in server
            return -1
        }
        return 0
    }
    
    func updatePageLength() {
        for page in pages {
            // retrieve page audio length: block method
            let audioName = "username-\(self.bookInfo.title)-Page\(page.pageIndex).m4a"
            page.pageLength = self.queryBlockForAudioTrackLength(audioName)
            //println("\(page.pageIndex): \(page.pageLength)")
        }
        // reload page info
        self.RecordItemPageTableView.reloadData()
    }
    
    func updateTempTimer(timer:NSTimer) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func audioRecorderEncodeErrorDidOccur(recorder: AVAudioRecorder!,
        error: NSError!) {
            println("\(error.localizedDescription)")
    }

    // MARK: AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
        println("finished playing \(flag)")
        if self.startPlayIndex > 0 {
            self.clearPlayIndex()
        }
    }
    
    func clearPlayIndex() {
        self.startPlayIndex = -1
        self.RecordItemPageTableView.reloadData()
    }
    
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer!, error: NSError!) {
        println("\(error.localizedDescription)")
    }
    
    func startLoadingIndicator() {
        // start loading indicator
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.LoadingIndicator.hidden = false
            self.LoadingIndicator.startAnimating()
        })
    }
    
    func stopLoadingIndicator() {
        // hide loading indicator
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.LoadingIndicator.stopAnimating()
            self.LoadingIndicator.hidden = true
        })
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
}


