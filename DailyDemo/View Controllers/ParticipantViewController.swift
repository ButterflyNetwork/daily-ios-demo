//

import Combine
import Daily
import UIKit

final class ParticipantViewController: UIViewController {
    var isViewHidden: Bool = false {
        didSet {
            UIView.animate(withDuration: 0.25, delay: 0.0) {
                self.view.isHidden = self.isViewHidden
            }
        }
    }

    var participant: Participant? = nil {
        didSet {
            if self.participant != oldValue {
                self.didUpdate(participant: self.participant)
            }
        }
    }

    var callClient: CallClient?

    private(set) var videoSize: CGSize = .zero

    var videoSizePublisher: AnyPublisher<CGSize, Never> {
        self.videoSizeSubject.eraseToAnyPublisher()
    }

    private let videoSizeSubject: CurrentValueSubject<CGSize, Never> = .init(
        .zero
    )

    @IBOutlet private weak var label: UILabel!
    private lazy var videoView: VideoView = {
        let v = VideoView()
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.delegate = self
        return v
    }()
    private lazy var secondaryVideoView: VideoView = {
        let v = VideoView()
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.delegate = self
        return v
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

//        view.addSubview(videoView)
//        view.addSubview(secondaryVideoView)
//
//        NSLayoutConstraint.activate([
//            videoView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
//            videoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
//            videoView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
//            videoView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.5),
//
//            secondaryVideoView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
//            secondaryVideoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
//            secondaryVideoView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
//            secondaryVideoView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.5),
//        ])

        let stackView = UIStackView(arrangedSubviews: [videoView, secondaryVideoView])
        stackView.axis = .horizontal
        stackView.frame = view.bounds
        stackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(stackView)
    }

    // MARK: - Handlers

    private func didUpdate(participant: Participant?) {
        let customVideoTrack = participant?.media?.customVideo.firstPlayableTrack
        let cameraTrack = participant?.media?.camera.track
        let screenTrack = participant?.media?.screenVideo.track
        let videoTrack = cameraTrack
        let secondaryVideoTrack = screenTrack ?? customVideoTrack
        let username = participant?.info.username

//        let isScreenOrCustomVideoTrack = screenTrack != nil || customVideoTrack != nil
        let hasVideo = videoTrack != nil
        let hasSecondaryVideo = secondaryVideoTrack != nil

        // Assign name to label:
        self.label.text = username ?? "Guest"

        // Hide label if there's video to play:
        self.label.isHidden = hasVideo

        // Assign track to video view:
        self.videoView.track = videoTrack

        // Hide video view if there's no video to play:
        self.videoView.isHidden = !hasVideo

        // Change video's scale mode based on track type:
//        self.videoView.videoScaleMode = isScreenOrCustomVideoTrack ? .fit : .fill
        self.videoView.videoScaleMode = .fill

        self.secondaryVideoView.track = secondaryVideoTrack
        self.secondaryVideoView.isHidden = !hasSecondaryVideo
//        self.secondaryVideoView.videoScaleMode = .fit
        self.secondaryVideoView.videoScaleMode = .fill

        // Don't change subscriptions for local view controller otherwise
        // it conflicts with the changes from the remote one.
        if
            let participant = participant,
            !participant.info.isLocal
        {
            let customVideoTrackToSubscribeTo = participant.media?.customVideo.firstSubscribableTrackName
            self.updateSubscriptions(
                participant: participant,
                subscribeToCustomVideoTrack: customVideoTrackToSubscribeTo
            )
        }
    }

    private func updateSubscriptions(
        participant: Participant,
        subscribeToCustomVideoTrack customVideoTrackName: String?
    ) {
        guard let callClient else { return }

        Task { @MainActor in

            // Reduce video quality of remote participants not currently displayed:
            //
            // This is done by moving participants from one pre-defined profile to another,
            // rather than changing each participant's settings individually:
            var mediaUpdates: [String : Update<CameraSubscriptionSettingsUpdate>] = [:]
            if let customVideoTrackName {
                mediaUpdates = [
                    customVideoTrackName: .set(
                        subscriptionState: .set(.subscribed),
                        receiveSettings: .set(maxQuality: .set(.high))
                    )
                ]
//                mediaUpdates = [customVideoTrackName: .set(subscriptionState: .set(.subscribed))]
            }
            _ = try await callClient.updateSubscriptions(
                forParticipants: .set(
                    [
                        participant.id: .set(
                            profile: .set(.activeRemote),
                            media: .set(
                                camera: nil,
                                customVideo: mediaUpdates
                            )
                        ),
                    ]
                )
//                participantsWithProfiles: .set(
//                    [
//                        .activeRemote: .set(
//                            profile: .set(.base),
//                            media: nil
//                        )
//                    ]
//                ),
            )
        }
    }
}

extension ParticipantViewController: VideoViewDelegate {
    func videoView(_ videoView: VideoView, didChangeVideoSize size: CGSize) {
        self.videoSizeSubject.send(size)
    }
}
