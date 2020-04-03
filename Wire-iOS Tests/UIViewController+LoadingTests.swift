//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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

import XCTest
@testable import Wire
import SnapshotTesting

final class MockLoadingViewController: SpinnerViewController {
    var dismissSpinner: Completion?
}

final class LoadingViewControllerTests: XCTestCase {
    var sut: MockLoadingViewController!
    
    override func setUp() {
        super.setUp()
        sut = MockLoadingViewController()
        sut.view.backgroundColor = .white
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testThatItShowsLoadingIndicator() {
        // Given
        
        // when
        sut.showSpinner = true
        
        // then
        verifyInAllDeviceSizes(matching: sut)
    }

    func testThatItDismissesLoadingIndicator() {
        // given & when
        sut.showSpinner = true
        sut.showSpinner = false

        // then
        verify(matching: sut)
    }

    func testThatItShowsLoadingIndicatorWithSubtitle() {
        // Given
        
        // when
        sut.showSpinner(title: "RESTORING…")

        // then
        verifyInAllDeviceSizes(matching: sut)
    }
    
}
