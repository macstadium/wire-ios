
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation

protocol SpinnerCapable: class {
    var dismissSpinner: SpinnerCompletion? { get set }
}

extension SpinnerCapable where Self: UIViewController {
    var showSpinner: Bool {
        set {
            if newValue {
                dismissSpinner = presentSpinner()
            } else {
                dismissSpinner?(nil)
            }
        }
        
        get {
            return dismissSpinner != nil
        }
    }
}

typealias SpinnerViewController = UIViewController & SpinnerCapable
typealias SpinnerCompletion = ((Completion?) -> Void)

extension UIViewController {
    
    func presentSpinner(title: String? = nil) -> SpinnerCompletion {
        // Starts animating when it appears, stops when it disappears
        let spinnerView = createSpinner(title: title)
        spinnerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinnerView)

        NSLayoutConstraint.activate([
            spinnerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            spinnerView.topAnchor.constraint(equalTo: view.topAnchor),
            spinnerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spinnerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])

        UIAccessibility.post(notification: .announcement, argument: "general.loading".localized)
        spinnerView.spinnerSubtitleView.spinner.startAnimation()

        return { completeion in
            spinnerView.removeFromSuperview()
            completeion?()
        }
    }
    
    fileprivate func createSpinner(title: String? = nil) -> LoadingSpinnerView {
        let loadingSpinnerView = LoadingSpinnerView()
        loadingSpinnerView.backgroundColor = UIColor(white: 0, alpha: 0.5)

        loadingSpinnerView.spinnerSubtitleView.subtitle = title
        
        return loadingSpinnerView
    }
    
}

fileprivate final class LoadingSpinnerView: UIView {
    let spinnerSubtitleView: SpinnerSubtitleView = SpinnerSubtitleView()
    
    init() {
        super.init(frame: .zero)
        addSubview(spinnerSubtitleView)
        createConstraints()
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createConstraints() {
        spinnerSubtitleView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            spinnerSubtitleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinnerSubtitleView.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }
}
