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
    
    var bookInfo: BookInfo!
    var pages:[PageInfo] = []
    
    
    // recording
    var recorder: AVAudioRecorder!
    var player:AVAudioPlayer!
    var meterTimer:NSTimer!
    var timerStr:String!
    
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
        self.RecordItemPageImg.image = self.bookInfo.coverImage?
        //self.RecordItemPageImg.image = UIImage(data: NSData(contentsOfURL: NSURL(string: self.albumInfo!.largeImageURL)!)!)
        
        // get all the pages info, display
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { () -> Void in
            var query = PFQuery(className: "page")
            query.whereKey("bookName", equalTo:self.bookInfo.title)
            query.addAscendingOrder("pageIndex")
            query.findObjectsInBackgroundWithBlock {
                (objects:[AnyObject]!, error: NSError!) ->Void in
                if (error == nil) {
                    for object in objects {
                        var bookName: String = object.objectForKey("bookName") as String
                        if (bookName == self.bookInfo.title) {
                            var pageIndex: Int = object.objectForKey("pageIndex") as Int
                            var pageTitle: String = object.objectForKey("pageTitle") as String
                            var pageImagePF: PFFile? = object.objectForKey("pageImage") as PFFile?
                            var pageImageData: NSData? = pageImagePF?.getData() as NSData?
                            var pageCoverImage: UIImage!
                            if (pageImageData != nil ) {
                                pageCoverImage = UIImage(data: pageImageData!)!
                            } else {
                                pageCoverImage = UIImage(named:"bookThumbDefault.jpg")!
                            }
                            var newPageItem:PageInfo = PageInfo(title: pageTitle, index: pageIndex, pageImage: pageCoverImage)
                            /*dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                self.pages.append(newPageItem)
                            })*/
                            self.pages.append(newPageItem)
                        }
                        self.RecordItemPageTableView.reloadData()
                        self.RecordItemPageTableView.rowHeight = 50
                    }
                }
            }
        })
        
        // init recording
        self.setSessionPlayback()
        //self.askForNotifications()
        self.deleteAllRecordings()
    }
    
    func updateAudioMeter(timer:NSTimer) {
        if self.recorder.recording {
            let dFormat = "%02d"
            let min:Int = Int(self.recorder.currentTime / 60)
            let sec:Int = Int(self.recorder.currentTime % 60)
            timerStr = "\(String(format: dFormat, min)):\(String(format: dFormat, sec))"
            self.RecordItemPageTableView.reloadData()
            self.recorder.updateMeters()
            var apc0 = self.recorder.averagePowerForChannel(0)
            var peak0 = self.recorder.peakPowerForChannel(0)
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
        cell.titleLabel.text = page.pageTitle
        cell.pageIndex.text = String(page.pageIndex) + "/" + String(bookInfo.pagesNum)
        cell.pageCoverImage.image = page.pageImage
        cell.titleLabel.textColor = UIColor.blackColor()
        cell.pageIndex.textColor = UIColor.blackColor()
        cell.backgroundColor = UIColor.whiteColor()
        
        // customized selection style
        let cellBGView = UIView()
        // don't forget to divide by 255 from R G B value
        //cellBGView.backgroundColor = UIColor(red: 140/255, green: 206/255, blue: 110/255, alpha: 1)
        cellBGView.backgroundColor = UIColor(red: 0.298, green: 0.851, blue: 0.3922, alpha: 1.0)
        // must set to a style and then customize the background, because style set to be none later
        cell.selectionStyle = UITableViewCellSelectionStyle.Blue        // important
        cell.selectedBackgroundView = cellBGView
        
        if self.startRecIndex == indexPath.row {
            cell.titleLabel.textColor = UIColor.whiteColor()
            cell.pageIndex.textColor = UIColor.whiteColor()
            cell.backgroundColor = UIColor.redColor()
            cell.selectionStyle = UITableViewCellSelectionStyle.None
            
            cell.pageIndex.text = timerStr
        }
        
        // after start recording, select table view cell will has no effect but to pop up action sheet
        if self.startRecIndex >= 0 {
            cell.selectionStyle = UITableViewCellSelectionStyle.None
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (self.startRecIndex >= 0) {
            // is recording
            let cell = tableView.dequeueReusableCellWithIdentifier("AlbumItem") as?
                RecordAlbumTableViewCell ?? RecordAlbumTableViewCell()
            
            // pausing recording
            if self.recorder != nil && self.recorder.recording {
                println("pausing")
                self.recorder.pause()
            }
            
            // update alert view
            let alertController = UIAlertController(title: "Recording", message: timerStr, preferredStyle: .ActionSheet)
            
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
                
                else {
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
        
        else {
            // not recording, play audio after click on corresponding table view cell
            let cell = tableView.dequeueReusableCellWithIdentifier("AlbumItem") as?
                RecordAlbumTableViewCell ?? RecordAlbumTableViewCell()
            
            // stop recording (should never be true)
            if self.recorder != nil {
                self.recorder.stop()
            }
            
            // stop playing if player is playing audio track
            if self.player != nil && self.player.playing {
                self.player.stop()
            }
            
            // retrieve audio track and play
            let pageIndex:String = String(indexPath.row)
            println("PLAY: pageIndex = \(pageIndex)")
            var query = PFQuery(className: "soundtracks")
            // generate the audioName of clicked page for query (username-bookTitle-pageIndex.m4a)
            query.whereKey("audioName", equalTo:"username-\(self.bookInfo.title)-Page\(pageIndex).m4a")
            query.findObjectsInBackgroundWithBlock {
                (objects:[AnyObject]!, error: NSError!) ->Void in
                if (error == nil) {
                    if objects.count != 0 {
                        // has record in the server
                        let userObject:PFObject = objects.first as PFObject
                        let audioFile: PFFile! = userObject.objectForKey("audioFile") as PFFile
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
                    }
                    else {
                        // has no record in the server
                        let alertController = UIAlertController(title: nil, message: "Found no record in server, record now?", preferredStyle: .Alert)
                        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
                        let recordAction = UIAlertAction(title: "Record", style: .Default, handler: {
                            action in
                            // start recording for table view cell
                            self.startRecording(indexPath.row)
                            
                        })
                        alertController.addAction(recordAction)
                        alertController.addAction(cancelAction)
                        self.presentViewController(alertController, animated: true, completion: nil)
                    }
                }
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
        
        var moreRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "More", handler:{action, indexpath in
            println("MORE•ACTION");

            // Action menu
            // destructiveButtonTitle: display on red options (delete etc...)
            /*let actionSheetMore = UIActionSheet(title: "More", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Delete Aduio in Server", "Download Locally")
            actionSheetMore.showInView(self.view)*/
            
            //
            let alertController = UIAlertController(title: "More", message: "00:00", preferredStyle: .ActionSheet)
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
            let callAction = UIAlertAction(title: "Delete Audio in Server", style: .Default, handler: {
                action in
                //let alertMessage = UIAlertController(title: "Service Unavailable", message: "Sorry, the call feature is not available yet. Please retry later.", preferredStyle: .Alert)
                //alertMessage.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                alertController.setValue("00:01", forKey: "message")
                self.presentViewController(alertController, animated: true, completion: nil)
                }
            )
            alertController.addAction(callAction)
            alertController.addAction(cancelAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        });
        moreRowAction.backgroundColor = UIColor(red: 0.298, green: 0.851, blue: 0.3922, alpha: 1.0);
        
        var deleteRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: "Delete", handler:{action, indexpath in
            println("DELETE•ACTION");
        });
        
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
                self.startRecording(indexPath.row)
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
        self.recorder = AVAudioRecorder(URL: soundFileURL!, settings: recordSettings, error: &error)
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
        NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        var fileManager = NSFileManager.defaultManager()
        var error: NSError?
        var files = fileManager.contentsOfDirectoryAtPath(docsDir, error: &error) as [String]
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
        NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
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
                        userAudio = objects.first as PFObject
                    }
                    
                    userAudio["audioName"] = "username-\(self.currentFileName!)"
                    userAudio["audioFile"] = userAudioFile
                    
                    // add the url into delete list
                    self.deleteList.append(docsDir + "/" + self.currentFileName!)
                    
                    var error:NSError
                    var succeeded:Bool!
                    userAudio.saveInBackgroundWithBlock({
                        (succeeded: Bool!, error: NSError!) -> Void in
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
                            let alertController = UIAlertController(title: "Upload finished!", message: "", preferredStyle: .Alert)
                            // dismiss view controller automatically in a 1s
                            self.presentViewController(alertController, animated: true, completion: { () -> Void in
                                self.tempTimer = NSTimer.scheduledTimerWithTimeInterval(1.5,
                                    target:self,
                                    selector:"updateTempTimer:",
                                    userInfo:nil,
                                    repeats:false)
                            })
                        }
                    })
                    // set flag
                    self.uploadFlag = false
                }
            }
        }
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
    }
    
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer!, error: NSError!) {
        println("\(error.localizedDescription)")
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


