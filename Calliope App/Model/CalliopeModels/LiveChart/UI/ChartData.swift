/*
 *  Copyright 2019 Google LLC. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

import Foundation

/// Stores the data points for display in a chart.
class ChartData {

  // MARK: - Constants

  // The number of indicies that an approximate binary search may be off.
  private let defaultApproximateTolerance = 8

  // MARK: - Properties

  /// Data points in sequential order.
  var dataPoints = [DataPoint]()

  /// Data points corresponding to notes.
  var noteDataPoints = [DataPoint]()

  /// A threshold count for throwing away data points in bulk. Prevents editing the array of data
  /// points too frequently if the throwaway methods are called repeatedly.
  var throwAwayThreshold = 100

  // MARK: - Public

  convenience init(_ dataPoints: [DataPoint]) {
    self.init()
    self.dataPoints = dataPoints
  }

  var firstX: Int64? {
    guard let firstPoint = dataPoints.first else {
      return nil
    }
    return firstPoint.x
  }

  var lastX: Int64? {
    guard let lastPoint = dataPoints.last else {
      return nil
    }
    return lastPoint.x
  }

  /// The time between the first and last x data point.
  var lengthX: Int64? {
    guard let firstX = firstX, let lastX = lastX else {
      return nil
    }

    return lastX - firstX
  }

  var minY: Double? {
    return dataPointYExtrema(with: min)
  }

  var maxY: Double? {
    return dataPointYExtrema(with: max)
  }

  /// The distance between the min and max y data point.
  var lengthY: Double? {
    guard let minY = minY, let maxY = maxY else {
      return nil
    }

    return maxY - minY
  }

  var isEmpty: Bool {
    return dataPoints.isEmpty
  }

  /// Adds the array of data points to the chart data.
  ///
  /// - Parameter addedDataPoints: An array of data points.
  func addDataPoints(_ addedDataPoints: [DataPoint]) {
    dataPoints.append(contentsOf: addedDataPoints)
  }

  /// Adds a data point. Assumes data points are added sequentially, order is never checked.
  ///
  /// - Parameter dataPoint: A data point.
  func addDataPoint(_ dataPoint: DataPoint) {
    dataPoints.append(dataPoint)
  }

  /// Returns a Y-value from datapoints derrived with the comparison function provided. This should
  /// be passed either min() or max()
  func dataPointYExtrema(with extremaMethod: (Double, Double) -> Double) -> Double? {
    guard let firstPoint = dataPoints.first else {
      return nil
    }

    if dataPoints.count == 1 {
      return firstPoint.y
    }

    var extremaValue = firstPoint.y
    let lastIndex = dataPoints.count - 1
    for dataPoint in dataPoints[1...lastIndex] {
      extremaValue = extremaMethod(extremaValue, dataPoint.y)
    }
    return extremaValue
  }

  /// Removes all data points and notes.
  func removeAll() {
    removeAllDataPoints()
  }

  /// Removes all data points.
  func removeAllDataPoints() {
    dataPoints.removeAll()
  }

  /// Returns the closest data point to a given timestamp.
  ///
  /// - Parameter timestamp: The timestamp to search for.
  /// - Returns: A data point that is closest to this timestamp.
  func closestDataPointToTimestamp(_ timestamp: Int64) -> DataPoint? {
    guard !isEmpty else { return nil }
    let index = closestIndexToTimestamp(timestamp)
    return dataPoints[index]
  }

  /// Searches for the closest index to a given timestamp, rounding up or down if the search
  /// does not find an exact match.
  ///
  /// - Parameter timestamp: The timestamp to search for.
  /// - Returns: An index closest to the given timestamp.
  func closestIndexToTimestamp(_ timestamp: Int64) -> Int {
    return exactBinarySearch(forTimestamp: timestamp, startIndex: 0)
  }

  /// Searches for the index of the value that is equal to or just less than the search value, in
  /// the range of startIndex to the end of the data array.
  ///
  /// - Parameters:
  ///   - searchTimestamp: The timestamp for which to search.
  ///   - startIndex: The index where the search starts.
  /// - Returns: The exact index of the value at or just below the search value.
  func exactBinarySearch(forTimestamp searchTimestamp: Int64, startIndex: Int) -> Int {
    return binarySearch(forTimestamp: searchTimestamp,
                        startIndex: startIndex,
                        endIndex: dataPoints.count - 1,
                        preferStart: true,
                        tolerance: 0)
  }

  /// Performs a binary search with a default search tolerance.
  ///
  /// - Parameters:
  ///   - searchTimestamp: The timestamp for which to search.
  ///   - startIndex: The index where the search starts.
  ///   - preferStart: True if the result should prefer the start of a range, otherwise prefers
  ///                  the end of a range. This can be used to make sure the range is not
  ///                  too short.
  /// - Returns: The index of an approximate timestamp match in the array.
  func approximateBinarySearch(forTimestamp searchTimestamp: Int64,
                               startIndex: Int,
                               preferStart: Bool) -> Int {
    return binarySearch(forTimestamp: searchTimestamp,
                        startIndex: startIndex,
                        endIndex: dataPoints.count - 1,
                        preferStart: preferStart,
                        tolerance: defaultApproximateTolerance)
  }

  /// Searches for the index of the point with the closest value to the given search timestamp.
  /// If search tolerance is greater than zero it does not try for an exact match, rather it returns
  /// when the range is smaller than the tolerance. Assumes points are ordered.
  ///
  /// - Parameters:
  ///   - searchTimestamp: The timestamp for which to search.
  ///   - startIndex: The index where the search starts.
  ///   - endIndex: The index where the search ends.
  ///   - preferStart: True if the result should prefer the start of a range, otherwise prefers
  ///                  the end of a range. This can be used to make sure the range is not
  ///                  too short.
  ///   - searchTolerance: The size of the range at which we can stop searching and just return
  ///                      something, either at the start of the current range if preferStart,
  ///                      or the end of the current range if preferEnd. This function is often used
  ///                      to find the approximate start and end indices of a known range, when
  ///                      erring on the outside of that range is ok but erring on the inside of
  ///                      the range causes points to be clipped.
  /// - Returns: The index of an approximate timestamp match in the array.
  func binarySearch(forTimestamp searchTimestamp: Int64,
                    startIndex: Int,
                    endIndex: Int,
                    preferStart: Bool,
                    tolerance searchTolerance: Int) -> Int {
    guard !isEmpty else { return 0 }

    // If the search timestamp is outside the search range, return the nearest search index.
    let startValue = dataPoints[startIndex].x
    if searchTimestamp <= startValue {
      return startIndex
    }

    let endValue = dataPoints[endIndex].x
    if searchTimestamp >= endValue {
      return endIndex
    }

    // If the search range is within the search tolerance, return the preferred index.
    if endIndex - startIndex <= searchTolerance {
      return preferStart ? startIndex : endIndex
    }

    // For exact searches that have been reduced to two indexes, determine whether the start or
    // end index is appropriate.
    if searchTolerance == 0 && endIndex - startIndex == 1 {
      let distanceToStart = searchTimestamp - startValue
      let distanceToEnd = endValue - searchTimestamp

      if distanceToStart < distanceToEnd {
        return startIndex
      } else if distanceToStart == distanceToEnd {
        return preferStart ? startIndex : endIndex
      } else {
        return endIndex
      }
    }

    let midIndex = (startIndex + endIndex) / 2
    let midValue = dataPoints[midIndex].x
    if midValue < searchTimestamp {
      return binarySearch(forTimestamp: searchTimestamp,
                          startIndex: midIndex,
                          endIndex: endIndex,
                          preferStart: preferStart,
                          tolerance: searchTolerance)
    } else if midValue > searchTimestamp {
      return binarySearch(forTimestamp: searchTimestamp,
                          startIndex: startIndex,
                          endIndex: midIndex,
                          preferStart: preferStart,
                          tolerance: searchTolerance)
    } else {
      // The mid value is a match, so return it.
      return midIndex
    }
  }

  /// Throws away data points earlier than a timestamp.
  ///
  /// - Parameter timestamp: A timestamp before which all data points will be removed.
  func throwAwayBefore(_ timestamp: Int64) {
    let index = binarySearch(forTimestamp: timestamp,
                             startIndex: 0,
                             endIndex: dataPoints.count - 1,
                             preferStart: false,
                             tolerance: 1)
    guard index >= throwAwayThreshold else { return }
    dataPoints.removeSubrange(0..<index)
  }

  /// Throws away data points after a timestamp.
  ///
  /// - Parameter timestamp: A timestamp after which all data points will be removed.
  func throwAwayAfter(_ timestamp: Int64) {
    var index = binarySearch(forTimestamp: timestamp,
                             startIndex: 0,
                             endIndex: dataPoints.count - 1,
                             preferStart: false,
                             tolerance: 1)
    let endIndex = dataPoints.endIndex

    // Make sure only timestamps after the given timestamp are removed.
    let dataPointX = dataPoints[index].x
    if dataPointX == timestamp {
      index = min(index + 1, endIndex)
    }

    guard endIndex - index >= throwAwayThreshold else { return }
    dataPoints.removeSubrange(index..<endIndex)
  }

  /// Throws away data points between a min and a max value. An optional threshold value prevents
  /// ranges from being removed that are smaller than the threshold.
  ///
  /// - Parameters:
  ///   - throwAwayMinX: The minimum value to throw away.
  ///   - throwAwayMaxX: The maximum value to throw away.
  ///   - throwawayThreshold: The minimum number of points that can be removed.
  func throwAwayBetween(_ throwAwayMinX: Int64,
                        and throwAwayMaxX: Int64) {
    guard throwAwayMaxX > throwAwayMinX else { return }

    // This should be the index to the right of max.
    let indexEnd = binarySearch(forTimestamp: throwAwayMaxX,
                                startIndex: 0,
                                endIndex: dataPoints.count - 1,
                                preferStart: false,
                                tolerance: 1)
    let indexStart = binarySearch(forTimestamp: throwAwayMinX,
                                  startIndex: 0,
                                  endIndex: dataPoints.count - 1,
                                  preferStart: false,
                                  tolerance: 1)

    guard indexEnd - indexStart >= throwAwayThreshold else { return }
    dataPoints.removeSubrange(indexStart..<indexEnd)
  }
}
