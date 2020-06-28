//
//  MyViewController.swift
//  SBBottomPanel
//
//  Created by Simon Bromberg on 2020-06-21.
//  Copyright © 2020 SBromberg. All rights reserved.
//

import UIKit

class MyViewController: UIViewController, SBBottomPanelViewControllerDelegate {

    private var bottomPanel: SBBottomPanelViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpBottomPanel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.showBottomPanel()
        }
    }

    private func setUpBottomPanel() {
        bottomPanel?.willMove(toParent: self)

        if bottomPanel == nil {
            let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "BottomPanel") as! SBBottomPanelViewController
            navigationController?.addChild(vc)
            navigationController?.view.addSubview(vc.view)

            let offScreenY = view.frame.maxY
            vc.view.frame = CGRect(origin: CGPoint(x: 0, y: offScreenY), size: view.frame.size)

            bottomPanel = vc
            bottomPanel?.delegate = self
        }

        bottomPanel?.safeAreaMaxY = view.safeAreaLayoutGuide.layoutFrame.maxY

        bottomPanel?.isEnabled = false

        bottomPanel?.snap(to: .peeking) { [weak self] _ in
            self?.bottomPanel?.didMove(toParent: self)
            self?.adjustScrollViewInsetsForBottomPanel()
        }
    }

    private func showBottomPanel(_ completion: ((Bool) -> Void)? = nil) {
        bottomPanel?.isEnabled = true

        if bottomPanel?.isEnabled == true {
            bottomPanel?.snap(to: .short, completion: { [weak self] completed in
                self?.adjustScrollViewInsetsForBottomPanel()
                completion?(completed)
            })
        }
    }

    private func adjustScrollViewInsetsForBottomPanel() {
//        if let minY = bottomPanel?.view.frame.minY {
//            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIScreen.main.bounds.height - minY, right: 0)
//        }
    }

    // MARK: - SBBottomPanelViewControllerDelegate

    func bottomPanelDidFinish(_ controller: SBBottomPanelViewController) {
        print("Hello world!")
    }
}

