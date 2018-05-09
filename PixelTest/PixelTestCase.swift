//
//  PixelTestCase.swift
//  PixelTest
//
//  Created by Kane Cheshire on 13/09/2017.
//  Copyright © 2017 Kane Cheshire. All rights reserved.
//

import UIKit
import XCTest

/// Subclass `PixelTestCase` after `import PixelTest`
open class PixelTestCase: XCTestCase {
    
    // MARK: - Properties -
    // MARK: Open
    
    open var mode: Mode = .test
    
    // MARK: Internal
    
    var layoutCoordinator: LayoutCoordinatorType = LayoutCoordinator()
    var testCoordinator: TestCoordinatorType = TestCoordinator()
    var fileCoordinator: FileCoordinatorType = FileCoordinator()
    
    // MARK: - Functions -
    
    /// Verifies a view.
    /// If this is called while in record mode, a new snapshot are recorded, overwriting any existing recorded snapshot.
    /// If this is called while in test mode, a new snapshot is created and compared to a previously recorded snapshot.
    /// If tests fail while in test mode, a failure and diff image are stored locally, which you can find in the same directory as the snapshot recording. This should show up in your git changes.
    /// If tests succeed after diffs and failures have been stored, PixelTest will automatically remove them so you don't have to clear them from git yourself.
    ///
    /// - Parameters:
    ///   - view: The view to verify.
    ///   - layoutStyle: The layout style to verify the view with.
    ///   - scale: The scale to record/test the snapshot with.
    open func verify(_ view: UIView, layoutStyle: LayoutStyle,
                     scale: Scale = .native, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        layoutCoordinator.layOut(view, with: layoutStyle)
        XCTAssertTrue(view.bounds.width > 0, "View has no width after layout", file: file, line: line)
        XCTAssertTrue(view.bounds.height > 0, "View has no height after layout", file: file, line: line)
        switch mode {
        case .record:
            record(view, scale: scale, file: file, function: function, line: line, layoutStyle: layoutStyle)
        case .test:
            test(view, scale: scale, file: file, function: function, line: line, layoutStyle: layoutStyle)
        }
    }
    
    /// Verifies the color contrast of all visible labels within the view.
    ///
    /// - Parameters:
    ///   - view: <#view description#>
    ///   - layoutStyle: <#layoutStyle description#>
    ///   - standard: <#standard description#>
    ///   - fallbackBackgoundColor: <#fallbackBackgoundColor description#>
    ///   - file: <#file description#>
    ///   - line: <#line description#>
    open func verifyColorContrast(for view: UIView, layoutStyle: LayoutStyle, standard: WCAGStandard,
                                  fallbackBackgoundColor: UIColor = .white, file: StaticString = #file, line: UInt = #line) {
        layoutCoordinator.layOut(view, with: layoutStyle)
        let results = testCoordinator.verifyColorContrast(for: view, standard: standard, fallbackBackgoundColor: fallbackBackgoundColor)
        guard !results.isEmpty else { fatalError("Results should never be empty") }
        results.forEach { result in
            switch result {
            case .success: XCTAssert(true)
            case .fail(let failed):
                addAttachment(named: "Failed", image: failed.image)
                XCTFail(failed.message, file: file, line: line)
            }            
        }
    }
    
}

extension PixelTestCase {
    
    // MARK: Private
    
    private func record(_ view: UIView, scale: Scale, file: StaticString, function: StaticString, line: UInt, layoutStyle: LayoutStyle) {
        let result = testCoordinator.record(view, layoutStyle: layoutStyle, scale: scale, testCase: self, function: function)
        switch result {
        case .success(let image):
            addAttachment(named: "Recorded image", image: image)
            XCTFail("Snapshot recorded (see recorded image in logs), disable record mode and re-run tests to verify.", file: file, line: line)
        case .fail(let errorMessage):
            XCTFail(errorMessage, file: file, line: line)
        }
    }
    
    private func test(_ view: UIView, scale: Scale, file: StaticString, function: StaticString, line: UInt, layoutStyle: LayoutStyle) {
        let result = testCoordinator.test(view, layoutStyle: layoutStyle, scale: scale, testCase: self, function: function)
        switch result {
        case .success:
            fileCoordinator.removeDiffAndFailureImages(for: self, function: function, scale: scale, layoutStyle: layoutStyle)
        case .fail(let failed):
            if let testImage = failed.test, let oracleImage = failed.oracle {
                storeDiffAndFailureImages(from: testImage, recordedImage: oracleImage, function: function, scale: scale, layoutStyle: layoutStyle)
            }
            XCTFail(failed.message, file: file, line: line)
        }
    }
    
    private func storeDiffAndFailureImages(from failedImage: UIImage, recordedImage: UIImage, function: StaticString, scale: Scale, layoutStyle: LayoutStyle) {
        guard let diffImage = failedImage.diff(with: recordedImage) else { return }
        fileCoordinator.storeDiffImage(diffImage, failedImage: failedImage, for: self, function: function, scale: scale, layoutStyle: layoutStyle)
        addAttachment(named: "Diff image", image: diffImage)
        addAttachment(named: "Failed image", image: failedImage)
        addAttachment(named: "Original image", image: recordedImage)
    }
    
}
