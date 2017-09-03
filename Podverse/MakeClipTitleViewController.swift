//
//  MakeClipTitleViewController.swift
//  Podverse
//
//  Created by Mitchell Downey on 8/31/17.
//  Copyright © 2017 Podverse LLC. All rights reserved.
//

import UIKit

class MakeClipTitleViewController: UIViewController, UITextFieldDelegate {

    var endTime: Int?
    var playerHistoryItem: PlayerHistoryItem?
    var startTime: Int?
    
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var endTimeLabel: UILabel!
    @IBOutlet weak var episodeTitle: UILabel!
    @IBOutlet weak var podcastImage: UIImageView!
    @IBOutlet weak var podcastTitle: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var titleInput: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let item = playerHistoryItem {
            
            self.podcastTitle.text = item.podcastTitle
            self.episodeTitle.text = item.episodeTitle
            
            self.podcastImage.image = Podcast.retrievePodcastImage(podcastImageURLString: item.podcastImageUrl, feedURLString: item.podcastFeedUrl) { (podcastImage) -> Void in
                self.podcastImage.image = podcastImage
            }
            
            if let startTime = self.startTime {
                self.startTimeLabel.text = "Start: " + PVTimeHelper.convertIntToHMSString(time: startTime)
            } else {
                self.startTimeLabel.text = ""
            }
            
            if let endTime = self.endTime {
                self.endTimeLabel.text = "End: " + PVTimeHelper.convertIntToHMSString(time: endTime)
            } else {
                self.endTimeLabel.text = "End:"
            }
            
            if let startTime = self.startTime, let endTime = self.endTime {
                self.duration.text = "Duration: " + PVTimeHelper.convertIntToReadableHMSDuration(seconds: endTime - startTime)
            } else {
                self.duration.text = "Duration:"
            }
            
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

}
