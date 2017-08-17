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
import StreamingKit

class MediaPlayerViewController: PVViewController {

    var playerSpeedRate:PlayingSpeed = .regular
    var timeOffset = Int64(0)
    var moveToOffset = false
    
    weak var currentChildViewController: UIViewController?
    private let aboutClipsStoryboardId = "AboutPlayingItemVC"
    private let clipsListStoryBoardId = "ClipsListVC"
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var clipsContainerView: UIView!
    @IBOutlet weak var currentTime: UILabel!
    @IBOutlet weak var device: UIButton!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var episodeTitle: UILabel!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var play: UIButton!
    @IBOutlet weak var podcastTitle: UILabel!
    @IBOutlet weak var progress: UISlider!
    @IBOutlet weak var speed: UIButton!
    
    override func viewDidLoad() {
        setupContainerView()
        
        let share = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.action, target: self, action: #selector(showShareMenu))
        let makeClip = UIBarButtonItem(title: "Make Clip", style: .plain, target: self, action: #selector(showMakeClip))
        let addToPlaylist = UIBarButtonItem(title: "Add to Playlist", style: .plain, target: self, action: #selector(showAddToPlaylist))
        navigationItem.rightBarButtonItems = [share, makeClip, addToPlaylist]

        self.progress.isContinuous = false
        
        setPlayerInfo()
        
        self.tabBarController?.hidePlayerView()
        
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
        setupNotificationListeners()
        
        activityIndicator.startAnimating()
        
        showProgressBar()
    }
    
    deinit {
        removeObservers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setPlayIcon()
    }
    
    override func viewWillAppear(_ animated: Bool) { /* Intentionally left blank so super won't get called */ }
    
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    @IBAction func pageControlAction(_ sender: Any) {
        if let sender = sender as? UIPageControl {
            if sender.currentPage == 1 {
                showClipsContainerView()
            } else {
                showAboutView()
            }
        }
    }
    
    @IBAction func sliderAction(_ sender: UISlider) {
        
        let duration = pvMediaPlayer.audioPlayer.duration
        var newTime = Double(sender.value) * duration
        
        pvMediaPlayer.audioPlayer.seek(toTime: newTime)
        
        updateCurrentTime(currentTime: newTime)

    }

    @IBAction func play(_ sender: Any) {
        pvMediaPlayer.playOrPause()
        setPlayIcon()
    }

    @IBAction func timeJumpBackward(_ sender: Any) {
        let newTime = pvMediaPlayer.audioPlayer.progress
        pvMediaPlayer.audioPlayer.seek(toTime: newTime)
        updateCurrentTime(currentTime: newTime)
    }
    
    @IBAction func timeJumpForward(_ sender: Any) {
        let newTime = pvMediaPlayer.audioPlayer.progress
        pvMediaPlayer.audioPlayer.seek(toTime: newTime)
        updateCurrentTime(currentTime: newTime)
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
        
        pvMediaPlayer.audioPlayer.rate = playerSpeedRate.speedValue

        updateSpeedLabel()
    }
    
    func pause() {
        pvMediaPlayer.pause()
        setPlayIcon()
    }
    
    fileprivate func setupNotificationListeners() {
        NotificationCenter.default.addObserver(self, selector: #selector(pause), name: .playerHasFinished, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideProgressBar), name: .playerIsLoading, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setPlayerTimeInfo), name: .playerReadyToPlay, object: nil)
    }
    
    fileprivate func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: .playerHasFinished, object: nil)
        NotificationCenter.default.removeObserver(self, name: .playerIsLoading, object: nil)
        NotificationCenter.default.removeObserver(self, name: .playerReadyToPlay, object: nil)
    }
    
    fileprivate func setupContainerView() {
        if let currentVC = self.storyboard?.instantiateViewController(withIdentifier: self.aboutClipsStoryboardId) {
            self.currentChildViewController = currentVC
            self.currentChildViewController?.view.translatesAutoresizingMaskIntoConstraints = false
            self.addChildViewController(currentVC)
            self.addSubview(subView: currentVC.view, toView: self.clipsContainerView)
        }
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(MediaPlayerViewController.showClipsContainerView))
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(MediaPlayerViewController.showAboutView))
        swipeLeft.direction = .left
        swipeRight.direction = .right
        self.clipsContainerView.addGestureRecognizer(swipeLeft)
        self.clipsContainerView.addGestureRecognizer(swipeRight)
        
        self.clipsContainerView.layer.borderColor = UIColor.lightGray.cgColor
        self.clipsContainerView.layer.borderWidth = 1.0
        
        self.pageControl.currentPage = 0
    }
    
    func setPlayIcon() {
        if pvMediaPlayer.audioPlayer.rate == 0 {
            play.setImage(UIImage(named:"Play"), for: .normal)
        } else {
            play.setImage(UIImage(named:"Pause"), for: .normal)
        }
    }
    
    func setPlayerInfo() {
        if let item = pvMediaPlayer.nowPlayingItem {
            podcastTitle.text = item.podcastTitle
            episodeTitle.text = item.episodeTitle
            
            self.image.image = Podcast.retrievePodcastImage(podcastImageURLString: item.podcastImageUrl, feedURLString: item.podcastFeedUrl) { (podcastImage) -> Void in
                self.image.image = podcastImage
            }
        }
    }
    
    // This method should only be called in the event of the AVPlayerItem "ready to play" notification.
    func setPlayerTimeInfo () {
        let playbackPosition = pvMediaPlayer.audioPlayer.progress
        currentTime.text = Int64(playbackPosition).toMediaPlayerString()
        let dur = pvMediaPlayer.audioPlayer.duration
        duration.text = Int64(dur).toMediaPlayerString()
        progress.value = Float(playbackPosition / dur)

        showProgressBar()
    }

    func updateCurrentTime(currentTime: Double) {
        let dur = pvMediaPlayer.audioPlayer.duration
        self.currentTime.text = Int64(dur).toMediaPlayerString()
        progress.value = Float(currentTime / dur)
    }
    
    func showProgressBar () {
        DispatchQueue.main.async {
            self.activityIndicator.isHidden = true
            self.progress.isHidden = false
            self.duration.isHidden = false
            self.currentTime.isHidden = false
        }
    }
    
    func hideProgressBar () {
        DispatchQueue.main.async {
            self.activityIndicator.isHidden = false
            self.progress.isHidden = true
            self.duration.isHidden = true
            self.currentTime.isHidden = true
        }
    }
    
    func updateSpeedLabel() {
        speed.setTitle(playerSpeedRate.speedText, for: .normal)
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
    
    func showAboutView() {
        if let newViewController = self.storyboard?.instantiateViewController(withIdentifier: self.aboutClipsStoryboardId), self.currentChildViewController is ClipsListContainerViewController {
            newViewController.view.translatesAutoresizingMaskIntoConstraints = false
            self.cycleFromViewController(oldViewController: self.currentChildViewController!, toViewController: newViewController)
            self.currentChildViewController = newViewController
            pageControl.currentPage = 0
        }
    }
    
    func showClipsContainerView() {
        if let newViewController = self.storyboard?.instantiateViewController(withIdentifier: self.clipsListStoryBoardId) as? ClipsListContainerViewController, self.currentChildViewController is AboutPlayingItemViewController {
            newViewController.view.translatesAutoresizingMaskIntoConstraints = false
            self.cycleFromViewController(oldViewController: self.currentChildViewController!, toViewController: newViewController)
            self.currentChildViewController = newViewController
            newViewController.delegate = self
            pageControl.currentPage = 1
        }    
    }
    
    private func addSubview(subView:UIView, toView parentView:UIView) {
        parentView.addSubview(subView)
        
        var viewBindingsDict = [String: AnyObject]()
        viewBindingsDict["subView"] = subView
        parentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[subView]|",
                                                                                 options: [], metrics: nil, views: viewBindingsDict))
        parentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[subView]|",
                                                                                 options: [], metrics: nil, views: viewBindingsDict))
    }
    
    private func cycleFromViewController(oldViewController: UIViewController, toViewController newViewController: UIViewController) {
        oldViewController.willMove(toParentViewController: nil)
        self.addChildViewController(newViewController)
        self.addSubview(subView: newViewController.view, toView:self.clipsContainerView)
        
        let initialX = newViewController is ClipsListContainerViewController ? self.clipsContainerView.frame.maxX : -self.clipsContainerView.frame.maxX
        newViewController.view.frame = CGRect(x: initialX, 
                                              y: 0.0, 
                                              width: newViewController.view.frame.width, 
                                              height: newViewController.view.frame.height)
        
        UIView.animate(withDuration: 0.5, animations: {
            if newViewController is ClipsListContainerViewController {
                oldViewController.view.frame = CGRect(x: -oldViewController.view.frame.width, 
                                                      y: 0.0, 
                                                      width: oldViewController.view.frame.width, 
                                                      height: oldViewController.view.frame.height)
            }
            else {
                oldViewController.view.frame = CGRect(x: oldViewController.view.frame.width, 
                                                      y: 0.0, 
                                                      width: oldViewController.view.frame.width, 
                                                      height: oldViewController.view.frame.height)
            }
            newViewController.view.frame = CGRect(x: 0.0, 
                                                  y: 0.0, 
                                                  width: newViewController.view.frame.width, 
                                                  height: newViewController.view.frame.height)
        },
           completion: { finished in
            oldViewController.view.removeFromSuperview()
            oldViewController.removeFromParentViewController()
            newViewController.didMove(toParentViewController: self)
        })
    }
}

extension MediaPlayerViewController:ClipsListDelegate {
    func didSelectClip(clip: MediaRef) {
        //Change the player data and info to the passed in clip
    }
}
