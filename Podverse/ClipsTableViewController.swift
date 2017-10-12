//
//  ClipsTableViewController.swift
//  Podverse
//
//  Created by Mitchell Downey on 6/6/17.
//  Copyright © 2017 Podverse LLC. All rights reserved.
//

import UIKit

class ClipsTableViewController: PVViewController {

    var clipsArray = [MediaRef]()
    let reachability = PVReachability.shared
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var tableViewHeader: FiltersTableHeaderView!
    
    @IBOutlet weak var clipQueryActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var clipQueryMessage: UILabel!
    @IBOutlet weak var clipQueryStatusView: UIView!
    
    var clipQueryPage: Int = 0
    var clipQueryIsLoading: Bool = false
    var clipQueryEndOfResultsReached: Bool = false
    
    var filterTypeSelected: ClipFilter = .allPodcasts {
        didSet {
            self.tableViewHeader.filterTitle = self.filterTypeSelected.text
            UserDefaults.standard.set(filterTypeSelected.text, forKey: kClipsTableFilterType)
        }
    }
    var sortingTypeSelected: ClipSorting = .topWeek {
        didSet {
            self.tableViewHeader.sortingTitle = sortingTypeSelected.text
            UserDefaults.standard.set(sortingTypeSelected.text, forKey: kClipsTableSortingType)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator.hidesWhenStopped = true
        showIndicator()
        
        self.tableViewHeader.delegate = self
        self.tableViewHeader.setupViews()
        
        self.clipQueryActivityIndicator.hidesWhenStopped = true
        self.clipQueryMessage.isHidden = true
        
        if let savedFilterType = UserDefaults.standard.value(forKey: kClipsTableFilterType) as? String, let clipFilterType = ClipFilter(rawValue: savedFilterType) {
            self.filterTypeSelected = clipFilterType
        } else {
            self.filterTypeSelected = .allPodcasts
        }
        
        if let savedSortingType = UserDefaults.standard.value(forKey: kClipsTableSortingType) as? String, let clipSortingType = ClipSorting(rawValue: savedSortingType) {
            self.sortingTypeSelected = clipSortingType
        } else {
            self.sortingTypeSelected = .topWeek
        }
        
        retrieveClips()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableViewHeader.filterTitle = self.filterTypeSelected.text
        self.tableViewHeader.sortingTitle = self.sortingTypeSelected.text
    }
    
    @IBAction func retryButtonTouched(_ sender: Any) {
        showIndicator()
        retrieveClips()
    }
    
    func resetClipQuery() {
        self.clipsArray.removeAll()
        self.clipQueryPage = 0
        self.clipQueryIsLoading = true
        self.clipQueryEndOfResultsReached = false
        self.tableView.reloadData()
    }
    
    func retrieveClips() {
        self.clipQueryPage += 1
        
        if self.filterTypeSelected == .subscribed {

            let subscribedPodcastFeedUrls = Podcast.retrieveSubscribedUrls()

            if subscribedPodcastFeedUrls.count < 1 {
                self.reloadClipData()
                return
            }

            MediaRef.retrieveMediaRefsFromServer(podcastFeedUrls: subscribedPodcastFeedUrls, sortingType: self.sortingTypeSelected, page: self.clipQueryPage) { (mediaRefs) -> Void in
                self.reloadClipData(mediaRefs: mediaRefs)
            }

        } else {

            MediaRef.retrieveMediaRefsFromServer(sortingType: self.sortingTypeSelected, page: self.clipQueryPage) { (mediaRefs) -> Void in
                self.reloadClipData(mediaRefs: mediaRefs)
            }

        }
        
    }
    
    func checkForConnectvity() {
        var message = "No clips available"
        
        if self.reachability.hasInternetConnection() == false {
            message = "You must connect to the internet to load clips."
        }
        
        if let noDataView = self.view.subviews.first(where: { $0.tag == kNoDataViewTag}) {
            if let messageView = noDataView.subviews.first(where: {$0 is UILabel}), let messageLabel = messageView as? UILabel {
                messageLabel.text = message
            }
        }
        else {
            self.addNoDataViewWithMessage(message, buttonTitle: "Retry", buttonImage: nil, retryPressed: #selector(ClipsTableViewController.retrieveClips))   
        }
    }
    
    func reloadClipData(mediaRefs: [MediaRef]? = nil) {
        self.clipQueryIsLoading = false
        self.clipQueryActivityIndicator.stopAnimating()
        
        guard let mediaRefArray = mediaRefs, mediaRefArray.count > 0 || clipsArray.count > 0 else {
            self.tableView.isHidden = true
            return
        }
        
        guard mediaRefArray.count > 0 else {
            self.clipQueryEndOfResultsReached = true
            self.clipQueryActivityIndicator.stopAnimating()
            self.clipQueryMessage.isHidden = false
            return
        }
        
        for mediaRef in mediaRefArray {
            self.clipsArray.append(mediaRef)
        }
        
        self.activityIndicator.stopAnimating()
        self.tableView.isHidden = false
        self.tableView.reloadData()
    }
    
    func showIndicator() {
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
    }
}

extension ClipsTableViewController:UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {        
        return clipsArray.count
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let clip = clipsArray[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "clipCell", for: indexPath) as! ClipTableViewCell
        
        cell.podcastTitle?.text = clip.podcastTitle
        cell.episodeTitle?.text = clip.episodeTitle
        cell.clipTitle?.text = clip.title
        
        if let time = clip.readableStartAndEndTime() {
            cell.time?.text = time
        }
        
        if let episodePubDate = clip.episodePubDate {
            cell.episodePubDate?.text = episodePubDate.toShortFormatString()
        }
        
        cell.podcastImage.image = Podcast.retrievePodcastImage(podcastImageURLString: clip.podcastImageUrl, feedURLString: clip.podcastFeedUrl, managedObjectID: nil, completion: { _ in
            cell.podcastImage.sd_setImage(with: URL(string: clip.podcastImageUrl ?? ""), placeholderImage: #imageLiteral(resourceName: "PodverseIcon"))
        })
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let clip = clipsArray[indexPath.row]
        let playerHistoryItem = self.playerHistoryManager.convertMediaRefToPlayerHistoryItem(mediaRef: clip)
        self.goToNowPlaying()
        self.pvMediaPlayer.loadPlayerHistoryItem(item: playerHistoryItem)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Bottom Refresh
        if scrollView == self.tableView {
            if ((scrollView.contentOffset.y + scrollView.frame.size.height) >= scrollView.contentSize.height) && !self.clipQueryIsLoading && !self.clipQueryEndOfResultsReached {
                self.clipQueryIsLoading = true
                self.clipQueryActivityIndicator.startAnimating()
                self.retrieveClips()
            }
        }
    }
    
    override func goToNowPlaying () {
        if let mediaPlayerVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MediaPlayerVC") as? MediaPlayerViewController {
            self.pvMediaPlayer.shouldAutoplayOnce = true
            self.navigationController?.pushViewController(mediaPlayerVC, animated: true)
        }
    }
    
}

extension ClipsTableViewController:FilterSelectionProtocol {
    func filterButtonTapped() {
        
        let alert = UIAlertController(title: "Clips From", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: ClipFilter.subscribed.text, style: .default, handler: { action in
            self.resetClipQuery()
            self.filterTypeSelected = .subscribed
            self.retrieveClips()
        }))
        
        alert.addAction(UIAlertAction(title: ClipFilter.allPodcasts.text, style: .default, handler: { action in
            self.resetClipQuery()
            self.filterTypeSelected = .allPodcasts
            self.retrieveClips()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func sortingButtonTapped() {
        self.tableViewHeader.showSortByMenu(vc: self)
    }
    
    func sortByRecent() {
        self.resetClipQuery()
        self.sortingTypeSelected = .recent
        self.retrieveClips()
    }
    
    func sortByTop() {
        self.tableViewHeader.showSortByTimeRangeMenu(vc: self)
    }
    
    func sortByTopWithTimeRange(timeRange: SortingTimeRange) {
        self.resetClipQuery()
        
        if timeRange == .day {
            self.sortingTypeSelected = .topDay
        } else if timeRange == .week {
            self.sortingTypeSelected = .topWeek
        } else if timeRange == .month {
            self.sortingTypeSelected = .topMonth
        } else if timeRange == .year {
            self.sortingTypeSelected = .topYear
        } else if timeRange == .allTime {
            self.sortingTypeSelected = .topAllTime
        }
        
        self.retrieveClips()
    }
    
}
