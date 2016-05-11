// Download.swift
//
// Copyright (c) 2014–2016 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

extension Manager {
    private enum Downloadable {
        case Request(NSURLRequest)
        ///  用于断点续传
        case ResumeData(NSData)
    }

    /**
     最终发送下载请求是通过这个方法触发
     
     - parameter downloadable: 用于区分是从上次下载结束的地方开始下载，还是重头开始下载
     - parameter destination:  下载结束后文件放置的位置
     */
    private func download(downloadable: Downloadable, destination: Request.DownloadFileDestination) -> Request {
        var downloadTask: NSURLSessionDownloadTask!

        switch downloadable {
        case .Request(let request):
            dispatch_sync(queue) {
                // 重新下载数据，不需要端点续传
                downloadTask = self.session.downloadTaskWithRequest(request)
            }
        case .ResumeData(let resumeData):
            dispatch_sync(queue) {
                // 下载是从服务器文件哪里开始读取数据
                // 为什么这里没有设置下载的URL呢？
                // http://www.tuicool.com/articles/uyQrIzi
                //解释了如何从resumeData中,生成端点续传所需要的数据
                downloadTask = self.session.downloadTaskWithResumeData(resumeData)
            }
        }

        let request = Request(session: session, task: downloadTask)

        if let downloadDelegate = request.delegate as? Request.DownloadTaskDelegate {
            downloadDelegate.downloadTaskDidFinishDownloadingToURL = { session, downloadTask, URL in
                return destination(URL, downloadTask.response as! NSHTTPURLResponse)
            }
        }

        delegate[request.delegate.task] = request.delegate

        if startRequestsImmediately {
            request.resume()
        }

        return request
    }

    // MARK: Request

    /**
        Creates a download request for the specified method, URL string, parameters, parameter encoding, headers
        and destination.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter method:      The HTTP method.
        - parameter URLString:   The URL string.
        - parameter parameters:  The parameters. `nil` by default.
        - parameter encoding:    The parameter encoding. `.URL` by default.
        - parameter headers:     The HTTP headers. `nil` by default.
        - parameter destination: The closure used to determine the destination of the downloaded file.

        - returns: The created download request.
    */
    public func download(
        method: Method,
        _ URLString: URLStringConvertible,
        parameters: [String: AnyObject]? = nil,
        encoding: ParameterEncoding = .URL,
        headers: [String: String]? = nil,
        destination: Request.DownloadFileDestination)
        -> Request
    {
        let mutableURLRequest = URLRequest(method, URLString, headers: headers)
        let encodedURLRequest = encoding.encode(mutableURLRequest, parameters: parameters).0

        return download(encodedURLRequest, destination: destination)
    }

    /**
        Creates a request for downloading from the specified URL request.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter URLRequest:  The URL request
        - parameter destination: The closure used to determine the destination of the downloaded file.

        - returns: The created download request.
    */
    public func download(URLRequest: URLRequestConvertible, destination: Request.DownloadFileDestination) -> Request {
        return download(.Request(URLRequest.URLRequest), destination: destination)
    }

    // MARK: Resume Data

    /**
        Creates a request for downloading from the resume data produced from a previous request cancellation.

        If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.

        - parameter resumeData:  The resume data. This is an opaque data blob produced by `NSURLSessionDownloadTask` 
                                 when a task is cancelled. See `NSURLSession -downloadTaskWithResumeData:` for 
                                 additional information.
        - parameter destination: The closure used to determine the destination of the downloaded file.

        - returns: The created download request.
    */
    public func download(resumeData: NSData, destination: Request.DownloadFileDestination) -> Request {
        return download(.ResumeData(resumeData), destination: destination)
    }
}

// MARK: -

extension Request {
    /**
        A closure executed once a request has successfully completed in order to determine where to move the temporary
        下载结束后，临时文件移动到最终位置
        file written to during the download process. The closure takes two arguments: the temporary file URL and the URL 
        response, and returns a single argument: the file URL where the temporary file should be moved.
    */
    public typealias DownloadFileDestination = (NSURL, NSHTTPURLResponse) -> NSURL

    /**
        Creates a download file destination closure which uses the default file manager to move the temporary file to a 
        file URL in the first available directory with the specified search path directory and search path domain mask.

        - parameter directory: The search path directory. `.DocumentDirectory` by default.
        - parameter domain:    The search path domain mask. `.UserDomainMask` by default.

        - returns: A download file destination closure.
    */
    public class func suggestedDownloadDestination(
        directory directory: NSSearchPathDirectory = .DocumentDirectory,
        domain: NSSearchPathDomainMask = .UserDomainMask)
        -> DownloadFileDestination
    {
        return { temporaryURL, response -> NSURL in
            let directoryURLs = NSFileManager.defaultManager().URLsForDirectory(directory, inDomains: domain)

            if !directoryURLs.isEmpty {
                // NSResponse中desuggestedFilename属性是文件名
                // HTTP 首部中的 Content-Disposition 域里的 filename 部分实现的
                return directoryURLs[0].URLByAppendingPathComponent(response.suggestedFilename!)
            }

            return temporaryURL
        }
    }

    /// The resume data of the underlying download task if available after a failure.
    ///  当下载出现问题中断后，可能存在的可以端点续传的data
    public var resumeData: NSData? {
        var data: NSData?

        if let delegate = delegate as? DownloadTaskDelegate {
            data = delegate.resumeData
        }

        return data
    }

    // MARK: - DownloadTaskDelegate

    class DownloadTaskDelegate: TaskDelegate, NSURLSessionDownloadDelegate {
        var downloadTask: NSURLSessionDownloadTask? { return task as? NSURLSessionDownloadTask }
        var downloadProgress: ((Int64, Int64, Int64) -> Void)?

        ///  如果暂停了下载，而且关闭程序，需要缓存这个数据，这样，启动程序是可以获得这个data，继续下载
        var resumeData: NSData?
        override var data: NSData? { return resumeData }

        // MARK: - NSURLSessionDownloadDelegate

        // MARK: Override Closures

        var downloadTaskDidFinishDownloadingToURL: ((NSURLSession, NSURLSessionDownloadTask, NSURL) -> NSURL)?
        var downloadTaskDidWriteData: ((NSURLSession, NSURLSessionDownloadTask, Int64, Int64, Int64) -> Void)?
        var downloadTaskDidResumeAtOffset: ((NSURLSession, NSURLSessionDownloadTask, Int64, Int64) -> Void)?

        // MARK: Delegate Methods

        /**
        下载完成完回调
        - parameter location:     将临时路径文件移动到指定的路径
        */
        func URLSession(
            session: NSURLSession,
            downloadTask: NSURLSessionDownloadTask,
            didFinishDownloadingToURL location: NSURL)
        {
            if let downloadTaskDidFinishDownloadingToURL = downloadTaskDidFinishDownloadingToURL {
                do {
                    let destination = downloadTaskDidFinishDownloadingToURL(session, downloadTask, location)
                    try NSFileManager.defaultManager().moveItemAtURL(location, toURL: destination)
                } catch {
                    self.error = error as NSError
                }
            }
        }
        /**
         下载的task代理，获得数据的代理，这里可以用于记录下载进度
         */
        func URLSession(
            session: NSURLSession,
            downloadTask: NSURLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64)
        {
            if let downloadTaskDidWriteData = downloadTaskDidWriteData {
                downloadTaskDidWriteData(
                    session,
                    downloadTask,
                    bytesWritten,
                    totalBytesWritten, 
                    totalBytesExpectedToWrite
                )
            } else {
                ///  服务器文件总大小
                progress.totalUnitCount = totalBytesExpectedToWrite
                ///  已经写入文件的大小
                progress.completedUnitCount = totalBytesWritten

                downloadProgress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
            }
        }
        
        /**
         当下载失败后，fileOffset为下载的偏移量
         - parameter fileOffset:         在失败后记录的已经下载量
         */
        func URLSession(
            session: NSURLSession,
            downloadTask: NSURLSessionDownloadTask,
            didResumeAtOffset fileOffset: Int64,
            expectedTotalBytes: Int64)
        {
            if let downloadTaskDidResumeAtOffset = downloadTaskDidResumeAtOffset {
                downloadTaskDidResumeAtOffset(session, downloadTask, fileOffset, expectedTotalBytes)
            } else {
                progress.totalUnitCount = expectedTotalBytes
                // 记录失败后的下载偏移量
                progress.completedUnitCount = fileOffset
            }
        }
    }
}
