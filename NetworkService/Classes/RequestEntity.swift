//
//  RequestEntity.swift
//  NetworkService
//
//  Created by Tbxark on 26/04/2017.
//  Copyright © 2017 Tbxark. All rights reserved.
//

import Foundation
import Alamofire




public typealias HTTPMethod = Alamofire.HTTPMethod

public protocol URLQueryValue {
    var urlQueryValue: String { get }
}
extension String: URLQueryValue {
    public var urlQueryValue: String { return self }
}
extension Int: URLQueryValue {
    public var urlQueryValue: String { return self.description }
}


public struct RequestEntity {
    
    public static let defaultVersion = "v1"
    
    // 请求类型
    public let method: HTTPMethod
    // 请求路径
    public let path: String
    // 请求版本
    public var version: String? = "v1"
    // 请求体
    public var body: [String: Any]?
    /// 查询参数
    public var query = [String: String]()
    
    
    public init(GET aPath: String,
                version aVersion: String = RequestEntity.defaultVersion ) {
        method = HTTPMethod.get
        path = aPath
        version = aVersion
    }
    
    public init(POST aPath: String,
                version aVersion: String = RequestEntity.defaultVersion ) {
        method = HTTPMethod.post
        path = aPath
        version = aVersion
    }
    
    public init(DELETE aPath: String,
                version aVersion: String = RequestEntity.defaultVersion ) {
        method = HTTPMethod.delete
        path = aPath
        version = aVersion
    }
    
    public init(_ aMethod: HTTPMethod,
                _ aPath: String,
                version aVersion: String = RequestEntity.defaultVersion ) {
        method = aMethod
        path = aPath
        version = aVersion
    }
    
    public init(_ aMethod: HTTPMethod,
                _ aPath: String,
                version aVersion: String = RequestEntity.defaultVersion,
                query aQuery: [String: URLQueryValue?],
                body aBody: [String: Any]? ) {
        method = aMethod
        path = aPath
        version = aVersion
        for (k, v) in aQuery {
            guard let value = v?.urlQueryValue else { continue }
            query[k] = value
        }
        body = aBody
    
    }
    
    public func changeVersion(_ ver: String) -> RequestEntity {
        var data = self
        data.version = ver
        return data
    }
    
    public func addMapBody<T: Codable>(_ map: T?, forKey key: String? = nil) -> RequestEntity {
        guard let m = map,
            let json = try? NetworkService.jsonEncoder.encode(m),
            let res =  try? JSONSerialization.jsonObject(with: json, options: []),
            let dict = res as? [String: Any]  else { return self}
       
        var data = self
        var body = data.body ?? [String: Any]()
        if let k = key {
            var dict = [String: Any]()
            for (k, v) in dict {
                dict[k] = v
            }
            body[k] = dict
        } else {
            for (k, v) in dict {
                body[k] = v
            }
        }
        data.body = body
        return data
    }
    
    public func addDictBody(_ dict: [String: Any]) -> RequestEntity {
        var data = self
        var body = data.body ?? [String: Any]()
        for (k, v) in dict {
            body[k] = v
        }
        data.body = body
        return data
    }
    
    
    public func addQuery(_ key: String, value: URLQueryValue?) -> RequestEntity {
        var data = self
        if let v = value?.urlQueryValue {
            data.query[key] = v
        } else {
            _ = data.query.removeValue(forKey: key)
        }
        return data
    }
    
    public func addQuerys(_ querys: [String: URLQueryValue?]) -> RequestEntity {
        var data = self
        for (k, v) in querys {
            if let _v = v?.urlQueryValue {
                data.query[k] = _v
            } else {
                _ = data.query.removeValue(forKey: k)
            }
        }
        return data
    }
    
    public func removeEmptyQueryParamater() -> RequestEntity {
        var data = self
        var temp = [String: String]()
        for (k,v) in data.query {
            guard !v.isEmpty else { continue }
            temp[k] = v
        }
        data.query = temp
        return data
    }
    
}


public protocol RequestParameters {
    func toRequestEntity() -> RequestEntity
}

extension RequestParameters {
    public var request: RequestEntity {
        return self.toRequestEntity()
    }
}


