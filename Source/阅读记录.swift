//
//  阅读记录.swift
//  Alamofire
//
//  Created by WangZHW on 16/4/6.
//  Copyright © 2016年 Alamofire. All rights reserved.
//

import Foundation

final class ReadRecordClass {
    init () {
    /**
 
    */
    }
    /**
     使用@我 来标示我的注释
     */
     /**
     使用@Delegate 来表示NSSessionTaskDelegate的
     */
    
    /**
     看不懂的代吗使用 //?? 来标识
     */
    func unKnowRecord() {
        /**
//??
        */
    }
    
    // MARK: 通用部分
    
    /**
     Alamofire.swift文件的用途
     */
    func AlamofireSwift() {
    /**
        1. 定义了URLStringConvertible协议，并且拓展了String、NSURL、NSURLRequest，实现了
        改协议
           作用提供一个URLString属性的get方法，类型为String，获得请求的路径
        
        2. 定义了URLRequestConvertible协议，并拓展了NSURLRequest，实现该协议
           作用提供了URLRequest属性的get方法，类型为NSMutableURLRequest
        
        3. 提供了请求的便利方法

    */
    }
    
    
    /**
     Error.swift文件的用途
     */
    func ErrorSwift() {
    /**
        提供简便方式创建NSError对象
    */
    }
    
    
    /**
     ParameterEncoding.swift文件的用途
     负责对HTTP请求的参数进行编码
     */
    func ParameterEncodingSwift() {
    /**
        1. 定义了Method枚举类型，关联值类型为String
        
        2. 定义了ParameterEncoding枚举类型，用于声明以什么方式进行编码
            encode(_:,_:) ->(_:,_:) 编码方法
            2.1 URL和URLEncodedInURL编码，针对于GET HEAD DELETE方法，将参数编码后拼接到请求首部
        
            2.2 JSON，将参数json序列化后配置request的HTTPBody，并设置Content-Type为
        application/json
        
            2.3 PropertyList主要是针对字典序列化为data，并设置application/x-plist
        为application/x-plist
    */
    }
    
    
    /**
     Result.swift文件用途
     */
    func ResultSwift() {
    /**
        定义枚举类型Result，用于表示请求成功或者错误
        public enum Result<Value, Error: ErrorType> {
            case success(Value)
            case Failure(Error)
        }
        使用范型类约束枚举
        示例
    */
        let a: TestResult<Int , String> = TestResult.TestOne(1)
        a.getValue()
    }
    
    // 尾随闭包初始化
    func ResponseClosure() ->ClosureInit{
        return ClosureInit{
            string in
            print(string)
        }
    }
}


public enum TestResult<One,Two> {
    case TestOne(One)
    case TestTwo(Two)
    
    func getValue() {
        switch self {
        case .TestOne(let a) :
            print(a)
        case .TestTwo(let b):
            print(b)
        }
    }
}
public struct ClosureInit {
    var closure: String ->Void
    // 有闭包的init方法
    public init(strClosure: String ->Void) {
        self.closure = strClosure
    }
}


