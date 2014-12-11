//
//  AppDelegate.swift
//  Grower
//
//  Created by Lukasz Kwoska on 10/12/14.
//  Copyright (c) 2014 Spinal Development. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!
  @IBOutlet weak var imageView: NSImageView!

  let sim = Simulator(width: 640, height: 480)

  func applicationDidFinishLaunching(aNotification: NSNotification) {
    // Insert code here to initialize your application
    dispatch_async(dispatch_get_main_queue(), { () -> Void in
      self.sim?.step();
      return;
    });
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your application
  }


}

