//
//  NetworkClient.swift
//  NetworkService
//
//  Created by Tbxark on 26/04/2017.
//  Copyright © 2017 Tbxark. All rights reserved.
//

import Foundation
import Alamofire
import RxSwift
import JsonMapper


class NetworkService {
    public static let jsonEncoder = JSONEncoder()
    public static let jsonDecoder = JSONDecoder()
}

public struct NetworkClientConfig {
    public let name: String
    public var schema: String
    public let host: String
    public var port: Int?
    public init(name: String, schema: String, host: String, port: Int? = nil) {
        self.name = name
        self.schema = schema
        self.host = host
        self.port = port
    }
}


public protocol RequestManager: class {
    func configure(request: URLRequest) -> URLRequest
    func errorHandle(request: URLRequest, error: Error?)
}

func NSBuildError(code: Int, message: String) -> Error {
    return NSError(domain: "com.everydo.networkClient", code: code, userInfo: [NSLocalizedDescriptionKey: message])
}

public struct ClientError {
    public static let statusCodeNotFound = 9000
    public static let dataNotFound = 9001
    public static let transformError = 9002
    public static let urlError = 9003
}


public struct HTTPResponseModel<T: Codable>: Codable {
    public let code: Int
    public let data: T?
    public let message: String?
    public var isSuccess: Bool { return code == 1 }
    
    public init(from decoder: Decoder) throws {
        let conatiner = try decoder.container(keyedBy: CodingKeys.self)
        code = try conatiner.decode(Int.self, forKey: CodingKeys.code)
        do {
            data = try conatiner.decode(T.self, forKey: CodingKeys.data)
        } catch {
            print((error as NSError).userInfo)
            data = nil
        }
        message = try? conatiner.decode(String.self, forKey: CodingKeys.message)
    }
    
}


public struct KeyValueStore<Store>: Codable where Store: Codable {
    
    public let key: String
    public let store: Store
    
    
    public init(from decoder: Decoder) throws {
        let conatiner = try decoder.singleValueContainer()
        let value = try conatiner.decode([String: Store].self)
        guard let k = value.keys.first, let v = value[k] else {
            throw NSError()
        }
        key = k
        store = v
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(["\(key)": store])
    }
}




public class NetworkClient {
    
    public let sessionManager: Alamofire.SessionManager
    public var configure: NetworkClientConfig
    private weak var requestManager: RequestManager?
    private let networkQueue: OperationQueueScheduler
    
    private  let decoder: JSONDecoder = {
        let jd = JSONDecoder()
        jd.dateDecodingStrategy = .millisecondsSince1970
        return jd
    }()

    
    public init(config: NetworkClientConfig) {
        configure = config
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpAdditionalHeaders = Alamofire.SessionManager.defaultHTTPHeaders
        sessionConfig.timeoutIntervalForRequest = 15.0
        sessionConfig.timeoutIntervalForResource = 15.0
        sessionConfig.allowsCellularAccess = true
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        let delegate = SessionDelegate()
        let policy = ServerTrustPolicyManager(policies: [config.host: .disableEvaluation])
        sessionManager = SessionManager(configuration: sessionConfig,
                                        delegate: delegate,
                                        serverTrustPolicyManager: policy)
        
        let queue = OperationQueue()
        queue.name = "com.network.\(config.name)"
        networkQueue =  OperationQueueScheduler(operationQueue: queue)
        
    }
    
    
    public func setRequestManager(_ rm: RequestManager) -> NetworkClient  {
        requestManager = rm
        return self
    }
    
    
    // MARK: - Create
    public func createURLRequest(_ method: HTTPMethod,
                                 _ url: URL,
                                 parameters: [String: Any]? = nil,
                                 encoding: ParameterEncoding = JSONEncoding.default,
                                 headers: [String: String]? = nil)  -> URLRequest? {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (headerField, headerValue) in headers ?? [:] {
            request.setValue(headerValue, forHTTPHeaderField: headerField)
        }
        if let parameters = parameters,
            let encoded = try? encoding.encode(request, with: parameters) {
            request = encoded
        }
        request.timeoutInterval = 15
        return request
    }
    
    
    public func createURLRequest(type: RequestParameters) -> URLRequest? {
        let entity = type.toRequestEntity()
        var urlComponents = URLComponents()
        urlComponents.scheme = configure.schema
        urlComponents.host = configure.host
        urlComponents.path = entity.version == nil ? "/\(entity.path)" : "/\(entity.version!)/\(entity.path)"
        urlComponents.port = configure.port
        if !entity.query.isEmpty {
            var data = [URLQueryItem]()
            for (k, v) in entity.query {
                data.append(URLQueryItem(name: k, value: v))
            }
            urlComponents.queryItems = data
        }
        
        guard let url = try? urlComponents.asURL(),
            let req = createURLRequest(entity.method,
                                       url,
                                       parameters: entity.body,
                                       encoding: JSONEncoding.default,
                                       headers: nil) else { return nil }
        if let m = requestManager {
            return m.configure(request: req)
        } else {
            return req
        }
    }

    public func netRequest<T: Codable>(_ type: RequestParameters) -> Observable<(T)> {
        guard let request = createURLRequest(type: type) else {
            return Observable.error(NSBuildError(code: ClientError.urlError,
                                                 message: "URL error"))
        }
        return sessionManager.rx
            .request(urlRequest: request)
            .flatMap({
                $0.rx.responseData()
            })
            .flatMap({ (response: HTTPURLResponse, data: Data) -> Observable<T> in
                do {
                    let model = try NetworkService.jsonDecoder.decode(HTTPResponseModel<T>.self, from: data)
//                    print(model)
                    if let data = model.data {
                        return Observable.just(data)
                    } else if let msg = model.message {
                        return Observable.error(NSBuildError(code: model.code, message: msg))
                    } else {
                        return Observable.error(NSBuildError(code: ClientError.transformError,
                                                             message: "Data Transform Error"))
                    }
                } catch {
                    print("Tranform Error: \((error as NSError).userInfo)")
                    return Observable.error(error)
                }
            })
            .do(onError: { (error) in
                self.requestManager?.errorHandle(request: request, error: error)
            })
            .subscribeOn(networkQueue)
            .observeOn(MainScheduler.asyncInstance)
    }
    
    
    public func netDataRequest(_ type: RequestParameters) -> Observable<Data> {
        guard let request = createURLRequest(type: type) else {
            return Observable.error(NSBuildError(code: ClientError.urlError,
                                                 message: "URL error"))
        }
        return sessionManager.rx
            .request(urlRequest: request)
            .flatMap({
                $0.rx.data()
            })
    }
    
    public func netDefaultRequest(_ type: RequestParameters) -> Observable<Any> {
        guard let request = createURLRequest(type: type) else {
            return Observable.error(NSBuildError(code: ClientError.urlError,
                                                 message: "URL error"))
        }
        return sessionManager.rx
            .request(urlRequest: request)
            .flatMap {
                $0.rx.responseJSON()
            }
            .flatMap { (response: HTTPURLResponse, json: Any) -> Observable<Any> in
                
                let jsonMapper = JsonMapper(data: json)
                if HTTPStatusCode(rawValue: response.statusCode)?.isSuccess ?? false, (jsonMapper["code"].intValue ?? 0) == 1  {
                    return Observable.just(json)
                } else {
                    let errorReason = jsonMapper["message"].stringValue ?? "Status Error"
                    let error = NSBuildError(code: response.statusCode, message: errorReason)
                    return Observable.error(error)
                }
            }
            .do(onError: { (error) in
                self.requestManager?.errorHandle(request: request, error: error)
            })
            .subscribeOn(networkQueue)
            .observeOn(MainScheduler.asyncInstance)
    }
    
}


public struct Reachability {
    public static var defaultReachability = NetworkReachabilityManager()
    public static var isUseCellular: Bool {
        if let r = defaultReachability {
            return r.isReachableOnWWAN
        } else if let reach = NetworkReachabilityManager() {
            defaultReachability = reach
            return reach.isReachableOnWWAN
        } else {
            return false
        }
    }
}
