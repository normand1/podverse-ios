//
//  MediaPlayerViewController.swift
//  Podverse
//
//  Created by Mitchell Downey on 5/17/17.
//  Copyright © 2017 Podverse LLC. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation

class MediaPlayerViewController: PVViewController {

    var playerSpeedRate:PlayingSpeed = .regular
    var shouldAutoplay = false
    
    @IBOutlet weak var clipsContainerView: UIView!
    @IBOutlet weak var progress: UISlider!
    @IBOutlet weak var currentTime: UILabel!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var podcastTitle: UILabel!
    @IBOutlet weak var episodeTitle: UILabel!
    @IBOutlet weak var viewSelector: UIButton!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var play: UIButton!
    @IBOutlet weak var speed: UIButton!
    @IBOutlet weak var device: UIButton!
    
    override func viewDidLoad() {
        let share = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.action, target: self, action: #selector(showShareMenu))
        let makeClip = UIBarButtonItem(title: "Make Clip", style: .plain, target: self, action: #selector(showMakeClip))
        let addToPlaylist = UIBarButtonItem(title: "Add to Playlist", style: .plain, target: self, action: #selector(showAddToPlaylist))
        navigationItem.rightBarButtonItems = [share, makeClip, addToPlaylist]
        
        // Make sure the Play/Pause button displays properly after returning from background
        //        NotificationCenter.default.addObserver(self, selector: #selector(MediaPlayerViewController.setPlayIcon), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        
        progress.isContinuous = false
        
        viewSelector.setTitle("Show Clips", for: .normal)
        clipsContainerView.isHidden = true
        
        setPlayerInfo()
        
        // TODO: does this need an unowned self or something?
        pvMediaPlayer.avPlayer.addPeriodicTimeObserver(forInterval: CMTimeMake(1, 1), queue: DispatchQueue.main) { time in
            self.updateCurrentTime(currentTime: CMTimeGetSeconds(time))
        }
        
        hidePlayerView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if (shouldAutoplay) {
            pvMediaPlayer.avPlayer.rate = 0
            pvMediaPlayer.playOrPause()
        }
        setPlayIcon()
    }
    
    override func viewWillAppear(_ animated: Bool) {}
    
    @IBAction func sliderAction(_ sender: UISlider) {
        if let currentItem = pvMediaPlayer.avPlayer.currentItem {
            let totalTime = CMTimeGetSeconds(currentItem.asset.duration)
            let newTime = Double(sender.value) * totalTime
            pvMediaPlayer.goToTime(seconds: newTime)
        }
    }
    
    @IBAction func toggleClipsView(_ sender: Any) {
        if clipsContainerView.isHidden {
            viewSelector.setTitle("Show About", for: .normal)
            clipsContainerView.isHidden = false
        }
        else {
            viewSelector.setTitle("Show Clips", for: .normal)
            clipsContainerView.isHidden = true
        }
    }
    
    @IBAction func play(_ sender: Any) {
        pvMediaPlayer.playOrPause()
        setPlayIcon()
    }

    @IBAction func timeJumpBackward(_ sender: Any) {
        if let currentItem = pvMediaPlayer.avPlayer.currentItem {
            let newTime = CMTimeGetSeconds(currentItem.currentTime())
            pvMediaPlayer.goToTime(seconds: newTime - 15)
            updateCurrentTime(currentTime: newTime)
        }
    }
    
    @IBAction func timeJumpForward(_ sender: Any) {
        if let currentItem = pvMediaPlayer.avPlayer.currentItem {
            let newTime = CMTimeGetSeconds(currentItem.currentTime())
            pvMediaPlayer.goToTime(seconds: newTime + 15)
            updateCurrentTime(currentTime: newTime)
        }
    }
    
    @IBAction func changeSpeed(_ sender: Any) {
        switch playerSpeedRate {
        case .regular:
            playerSpeedRate = .timeAndQuarter
            break
        case .timeAndQuarter:
            playerSpeedRate = .timeAndHalf
            break
        case .timeAndHalf:
            playerSpeedRate = .double
            break
        case .double:
            playerSpeedRate = .doubleAndHalf
            break
        case .doubleAndHalf:
            playerSpeedRate = .quarter
            break
        case .quarter:
            playerSpeedRate = .half
            break
        case .half:
            playerSpeedRate = .threeQuarts
            break
        case .threeQuarts:
            playerSpeedRate = .regular
            break
        }
        
        pvMediaPlayer.avPlayer.rate = playerSpeedRate.speedVaue
        updateSpeedLabel()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showClipsList" {
            if let clipListVC = segue.destination as? ClipsListContainerViewController {
                clipListVC.delegate = self
            }
        }
    }
    
    func setPlayIcon() {
        if pvMediaPlayer.avPlayer.rate == 0 {
            play.setImage(UIImage(named:"Play"), for: .normal)
        } else {
            play.setImage(UIImage(named:"Pause"), for: .normal)
        }
    }
    
    func setPlayerInfo() {
        if let item = pvMediaPlayer.currentlyPlayingItem {
            podcastTitle.text = item.podcastTitle
            episodeTitle.text = item.episodeTitle
            
            DispatchQueue.global().async {
                Podcast.retrievePodcastUIImage(item: item) { (podcastImage) -> Void in
                    DispatchQueue.main.async {
                        self.image.image = podcastImage
                    }
                }
            }
            
            let lastPlaybackPosition = item.lastPlaybackPosition ?? 0
            currentTime.text = Int(lastPlaybackPosition).toMediaPlayerString()
            if let currentItem = pvMediaPlayer.avPlayer.currentItem {
                let totalTime = Int(CMTimeGetSeconds(currentItem.asset.duration))
                duration.text = Int(totalTime).toMediaPlayerString()
                progress.value = Float(Int(lastPlaybackPosition) / totalTime)
            }
            
        }
        
        
    }
    
    func updateCurrentTime(currentTime: Double) {
        self.currentTime.text = Int(currentTime).toMediaPlayerString()
        if let currentItem = pvMediaPlayer.avPlayer.currentItem {
            let totalTime = CMTimeGetSeconds(currentItem.duration)
            progress.value = Float(currentTime / totalTime)
        } else {
            DispatchQueue.main.async {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func updateSpeedLabel() {
        speed.setTitle(playerSpeedRate.speedText, for: .normal)
    }
    
    func showAbout() {
        return
    }
    
    func showPodcastClips() {
        return
    }
    
    func showEpisodeClips() {
        return
    }
    
    func showSubscribedClips() {
        return
    }
    
    func showShareMenu() {
        return
    }
    
    func showMakeClip() {
        return
    }
    
    func showAddToPlaylist() {
        return
    }
}

extension MediaPlayerViewController:ClipsListDelegate {
    func didSelectClip(clip: MediaRef) {
        //Change the player data and info to the passed in clip
    }
}
