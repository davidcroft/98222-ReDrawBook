//
//  PlayItemViewController.swift
//  ReDrawBook2
//
//  Created by Ding Xu on 10/14/14.
//  Copyright (c) 2014 Ding Xu. All rights reserved.
//

import UIKit
import MediaPlayer
import CoreBluetooth
import AVFoundation

class PlayItemViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    @IBOutlet var PlayItemPageStatus: UILabel!
    @IBOutlet var PlayItemPageTitle: UILabel!
    @IBOutlet var PlayItemPageIndex: UILabel!
    @IBOutlet var PlayItemPageImg: UIImageView!
    
    // audio player
    //var mediaPlayer: MPMoviePlayerController = MPMoviePlayerController()
    var audioPlayer : AVAudioPlayer! = nil // will be Optional, must supply initializer
    
    var startPlayFlag: Bool = false
    
    // bluetooth
    let serviceUUID = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    let txCharUUID  = CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    let rxCharUUID  = CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    let deviceInfoServiceUUID   = CBUUID(string: "180A")
    let hardwareRevisionStrUUID = CBUUID(string: "2A27")
    
    //var peripheralManager: CBPeripheralManager!
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    var txCharacteristic: CBCharacteristic?
    var rxCharacteristic: CBCharacteristic?
    var uartService: CBService?
    
    // book page message
    var BLEName:NSString! = ""
    let BLEPageMsgStart:NSString! = ":"
    let BLEPageMsgEnd:NSString! = "#"
    
    var pageIndexCurr:Int! = 0
    var pageIndexTemp:Int! = 0
    var pageRecogCountFlag:Bool = false
    var pageRecogCounter:Int! = 0
    let pageRecogCounterInit = 2
    var isPlaying:Bool = false
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // alignment
        self.PlayItemPageStatus.textAlignment = NSTextAlignment.Center
        self.PlayItemPageStatus.sizeToFit()
        self.PlayItemPageTitle.textAlignment = NSTextAlignment.Center
        self.PlayItemPageTitle.sizeToFit()
        self.PlayItemPageIndex.textAlignment = NSTextAlignment.Center
        self.PlayItemPageIndex.sizeToFit()
        self.PlayItemPageImg.sizeToFit()
        
        // text
        self.PlayItemPageStatus.text = "connect to book ..."
        self.PlayItemPageStatus.backgroundColor = UIColor.redColor()
        self.PlayItemPageStatus.textColor = UIColor.whiteColor()
        //self.PlayItemPageTitle.text = albumInfo.title
        self.PlayItemPageTitle.text = BLEName
        self.PlayItemPageIndex.text = "0/10"
        
        // load image
        //self.PlayItemPageImg?.image = UIImage(named: "Blank52")
        
        // Grab the artworkUrl60 key to get an image URL for the app's thumbnail
        //let urlString = albumInfo.largeImageURL
        let urlString = "http://www.readingforpleasure.net/wp-content/uploads/2012/01/cat-reading-book.jpg"
        let imgURL: NSURL = NSURL(string: urlString)!
        // Download an NSData representation of the image at the URL
        let imgData: NSData = NSData(contentsOfURL: imgURL)!
        self.PlayItemPageImg?.image = UIImage(data: imgData)
        
        // get collection id and play song
        //UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        //ItunesAPI.lookupAlbum(self.albumInfo.collectionId)
        
        // play flag
        self.startPlayFlag = false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
    }
    
    override func viewWillDisappear(animated: Bool) {
    }
    
    //////////////////////////////////////////////////
    ///////////// Bluetooth connection ///////////////
    // Invoked when the central manager’s state is updated (required)
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        if central.state == .PoweredOn {
            NSLog("central on")
            // scanning
            centralManager.scanForPeripheralsWithServices([self.serviceUUID!], options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        }
    }
    
    // Invoked when the central manager discovers a peripheral while scanning
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        var periName:NSString! = peripheral!.valueForKey("name") as NSString
        if (periName == self.BLEName) {
            // Clear off any pending connections
            centralManager.stopScan()
            centralManager.cancelPeripheralConnection(peripheral)
            
            // find peripheral
            NSLog("Did discover peripheral: \(peripheral.name)")
            self.peripheral = peripheral
            
            //connectPeripheral
            let numberWithBool = NSNumber(bool: true)
            central.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey:false])
        }
    }
    
    // Invoked when a call to connectPeripheral:options: is successful.
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID, deviceInfoServiceUUID])
    }
    
    // Invoked when a call to discoverServices: method
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        if (error == nil) {
            for s:CBService in peripheral.services as [CBService] {
                if (s.UUID.UUIDString == serviceUUID.UUIDString) {
                    // service
                    NSLog("Found correct service")
                    uartService = s
                    // Discovers the specified characteristics of a service
                    peripheral.discoverCharacteristics([txCharUUID, rxCharUUID], forService: uartService)
                } else if (s.UUID.UUIDString == deviceInfoServiceUUID.UUIDString) {
                    peripheral.discoverCharacteristics([hardwareRevisionStrUUID], forService: s)
                }
            }
        } else {
            NSLog("Discover services error: \(error)")
            return
        }
    }
    
    // Invoked when the peripheral discovers one or more characteristics of the specified service
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        if (error == nil) {
            NSLog("Discover Characteristics For Service: \(service.description)")
            let services:[CBService] = peripheral.services as [CBService]
            let s = services[services.count - 1]
            if service.UUID.UUIDString == s.UUID.UUIDString {
                for s:CBService in peripheral.services as [CBService] {
                    for c:CBCharacteristic in s.characteristics as [CBCharacteristic] {
                        if (c.UUID.UUIDString == rxCharUUID.UUIDString) {
                            NSLog("Found RX Characteristics")
                            rxCharacteristic = c
                            peripheral.setNotifyValue(true, forCharacteristic: rxCharacteristic)
                            // send first message only after both rx and tx characters have been set
                            if (txCharacteristic != nil) {
                                self.sendBLEMsg("hello, world")
                                self.PlayItemPageStatus.text = "waiting for touch event on paper ..."
                            }
                        } else if (c.UUID.UUIDString == txCharUUID.UUIDString) {
                            NSLog("Found TX Characteristics")
                            txCharacteristic = c
                            peripheral.setNotifyValue(false, forCharacteristic: txCharacteristic)
                            // send first message only after both rx and tx characters have been set
                            if (rxCharacteristic != nil) {
                                self.sendBLEMsg("hello, world")
                                self.PlayItemPageStatus.text = "waiting for touch event on paper ..."
                            }
                        } else if (c.UUID.UUIDString == hardwareRevisionStrUUID.UUIDString) {
                            NSLog("Found Hardware Revision String characteristic")
                            peripheral.readValueForCharacteristic(c)
                        }
                    }
                }
            }
        }
    }
    
    // Invoked after write a characteristic with property .WriteWithResponse
    func peripheral(peripheral: CBPeripheral!, didWriteValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        NSLog("didWriteValueForCharacteristic")
    }
    
    // Invoked if there is a update with all the characteristics that setNotifyValue to be True
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        //NSLog("Did Update Value For Characteristic")
        if error == nil {
            // create a new thread to read characters
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { () -> Void in
                if (characteristic == self.rxCharacteristic) {
                    //NSLog("Recieved: \(characteristic.value)")
                    let rxStr:NSString! = NSString(data: characteristic.value, encoding:NSUTF8StringEncoding)
                    //NSLog("Received value is \(rxStr)")
                    let pageIndex:Int = self.readBookPage(rxStr)
                    if pageIndex >= 0 {
                        // if pageIndex is not identical with current page index, activate a new update process
                        if self.pageIndexCurr != pageIndex && !self.pageRecogCountFlag {
                            // init a new recognition process
                            println("start new recognition")
                            self.pageRecogCountFlag = true
                            self.pageRecogCounter = self.pageRecogCounterInit
                            self.pageIndexTemp = pageIndex
                        }
                        else if self.pageRecogCountFlag {
                            //println("during a recognition")
                            self.pageRecognition(pageIndex)
                        }
                    }
                }
                else if characteristic.UUID.UUIDString == self.hardwareRevisionStrUUID.UUIDString {
                    //NSLog("Did read hardware revision string")
                    var hwRevision:NSString = ""
                    var bytes:UnsafePointer<UInt8> = UnsafePointer<UInt8>(characteristic.value.bytes)
                    var i:Int
                    for (i = 0; i < characteristic.value.length; i++){
                        hwRevision = hwRevision.stringByAppendingFormat("0x%x, ", bytes[i])
                    }
                    //Once hardware revision string is read, connection to Bluefruit is complete
                    let hwStr = hwRevision.substringToIndex(hwRevision.length-2)
                    NSLog("HW Revision: \(hwStr)")
                }
            })
        } else {
            NSLog("Error receiving notification for characteristic: \(error)")
            return
        }
    }
    
    func sendBLEMsg(sendStr: NSString!) {
        // write char
        let newString: NSString = sendStr
        let txData: NSData = NSData(bytes: newString.UTF8String, length: newString.length)
        NSLog("Sending: \(txData)");
        NSLog(String(self.txCharacteristic!.properties.rawValue))
        if (self.txCharacteristic != nil) {
            //if (self.txCharacteristic!.properties & CBCharacteristicProperties.WriteWithoutResponse)
            if (self.txCharacteristic!.properties == CBCharacteristicProperties.WriteWithoutResponse) {
                self.peripheral!.writeValue(txData, forCharacteristic: self.txCharacteristic, type: .WithoutResponse)
            }
            else if (self.txCharacteristic!.properties == CBCharacteristicProperties.Write) {
                self.peripheral!.writeValue(txData, forCharacteristic: self.txCharacteristic, type: .WithResponse)
            }
            else {
                NSLog("No write property on TX characteristic, %d.", self.txCharacteristic!.properties.rawValue)
            }
        }
    }
    
    func readBookPage(recStr: String!) -> Int{
        // retrieve page number from recStr
        var startIndex=recStr.rangeOfString(BLEPageMsgStart)?.startIndex
        var endIndex=recStr.rangeOfString(BLEPageMsgEnd)?.startIndex
        // check availability
        //if (startIndex != nil && endIndex != nil) {
        if (startIndex != nil) {
            let index: String.Index = advance(recStr.startIndex, 6)
            var pageIndexStr:String = recStr.substringFromIndex(index)
            var pageIndex:Int = pageIndexStr.toInt()!
            //println(pageIndex)
            return pageIndex
        }
        return -1
    }
    
    // Successive pageRecogCounterInit exact pageIndex will update current page index
    func pageRecognition(pageIndex: Int!) {
        if (self.pageRecogCountFlag) {
            // during a recognition process
            // identify if counter comes to 0
            if (self.pageRecogCounter <= 0) {
                // yes, update current page
                self.pageIndexCurr = self.pageIndexTemp
                println("update page: index = \(self.pageIndexCurr)")
                // stop recognition
                self.pageRecogCountFlag = false
                // update UI
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if self.pageIndexCurr > 0 {
                        // page > 0
                        self.PlayItemPageStatus.text = "play sound track on page \(self.pageIndexCurr)"
                        self.PlayItemPageStatus.backgroundColor = UIColor(red: 0.298, green: 0.851, blue: 0.3922, alpha: 1.0)
                        self.PlayItemPageIndex.text = "\(self.pageIndexCurr)/20"
                    } else {
                        // page == 0
                        self.PlayItemPageStatus.text = "waiting for touch event on paper ..."
                        self.PlayItemPageStatus.backgroundColor = UIColor.redColor()
                        self.PlayItemPageIndex.text = "\(self.pageIndexCurr)/20"
                    }
                })
            } else {
                // not yet, identify if pageIndex and pageIndexTemp are identical
                if (self.pageIndexTemp == pageIndex) {
                    // yes, counter down counter and wait for next comparision
                    self.pageRecogCounter = self.pageRecogCounter - 1
                } else {
                    // no, not same with pageIndexTemp, not update page and reset recognition
                    self.pageRecogCountFlag = false
                }
            }
        }
    }
    
    func playAudio(pageIndex: Int!) {
        if(pageIndex == 0) {
            audioPlayer.stop()
            self.isPlaying = false;
            NSLog("stop play audio")
            self.PlayItemPageStatus.text = "waiting for touch event on paper ..."
            self.PlayItemPageStatus.backgroundColor = UIColor.redColor()
            self.PlayItemPageStatus.textColor = UIColor.whiteColor()
        }
        else if(pageIndex > 0) {
            if(!self.isPlaying) {
                // audio player
                /*var path = NSBundle.mainBundle().pathForResource("page1Audio", ofType:"mp3")
                switch pageIndex {
                case 1:
                    path = NSBundle.mainBundle().pathForResource("page1Audio", ofType:"mp3")
                case 2:
                    path = NSBundle.mainBundle().pathForResource("page2Audio", ofType:"mp3")
                case 3:
                    path = NSBundle.mainBundle().pathForResource("page3Audio", ofType:"mp3")
                case 4:
                    path = NSBundle.mainBundle().pathForResource("page4Audio", ofType:"mp3")
                case 5:
                    path = NSBundle.mainBundle().pathForResource("page5Audio", ofType:"mp3")
                case 6:
                    path = NSBundle.mainBundle().pathForResource("page6Audio", ofType:"mp3")
                case 7:
                    path = NSBundle.mainBundle().pathForResource("page7Audio", ofType:"mp3")
                case 8:
                    path = NSBundle.mainBundle().pathForResource("page8Audio", ofType:"mp3")
                default:
                    path = NSBundle.mainBundle().pathForResource("page1Audio", ofType:"mp3")
                }*/
                NSLog("play audio \(pageIndex)")
                
                //let fileURL = NSURL(fileURLWithPath: path!)
                //audioPlayer = AVAudioPlayer(contentsOfURL: fileURL, error: nil)
                //audioPlayer.prepareToPlay()
                //audioPlayer.play()
                self.isPlaying = true
            }
            self.PlayItemPageStatus.text = "play sound track on page \(pageIndex)"
            self.PlayItemPageStatus.backgroundColor = UIColor.greenColor()
            self.PlayItemPageStatus.textColor = UIColor.whiteColor()
        }
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
