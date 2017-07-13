
class Backend {
    static let shared = Backend()
    
    private let session: SessionManager
    private let host = Constants.Backend.URL
    private lazy var component: URLComponents! = {
        return URLComponents(string: self.host)
    }()
    
    let onError = Signal<BackendError>()
    
    init() {
        var headers = SessionManager.defaultHTTPHeaders
        headers["Language"] = "EN"

        if let preferredLanguage = Locale.preferredLanguages.first {
            let locale = Locale(identifier: preferredLanguage)
            if let languageCode = locale.languageCode {
                headers["Language"] = languageCode
            }
        }
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpAdditionalHeaders = headers
        session = SessionManager(configuration: sessionConfiguration)
    }
    
    func createEndpointURL(path: String) throws -> URL {
        component.path = path
        return try component.asURL()
    }
    
    func load<Value>(
        resource: BackendResource<Value>,
        completion: @escaping (Result<Value>) -> Void
    ) {
        var endpointURL: URL? = nil
        
        do {
            endpointURL = try createEndpointURL(path: resource.route.path);
        } catch {
            completion(.error(error))
        }
        
        guard let url = endpointURL else {
            return
        }
        
        var headers: HTTPHeaders = resource.authorization ? authorizationHeader : [:]
        
        if let resourceHeaders = resource.headers {
            headers.update(resourceHeaders)
        }
        
        let responseHandler: (DefaultDataResponse) -> Void = { response in
            
            if let (shouldLog, message) = resource.logResponse,
                shouldLog == true {
                Logger.log(response: response, message: message)
            }

            complete(completion) {
                do {
                    let data = try validate(response: response)
                    return try resource.parse(data)
                }
                
                catch let error as BackendError {
                    self.onError.fire(error)
                    throw error
                }
                
                catch {
                    throw error
                }
            }
        }
        
        if let multipartConstructor = resource.multipartConstructor {
            let encodingCompletion: (SessionManager.MultipartFormDataEncodingResult) -> Void = { encodingResult in
                
                switch encodingResult {
                case .success(let upload, _, _):
                    upload
                        .debugLog()
                        .response(completionHandler: responseHandler)
                case .failure(let error):
                    completion(.error(error))
                }
            }
            
            session.upload(multipartFormData: multipartConstructor,
                           usingThreshold: SessionManager.multipartFormDataEncodingMemoryThreshold,
                           to: url,
                           method: resource.method,
                           headers: headers,
                           encodingCompletion: encodingCompletion)
        } else {
            session
                .request(url,
                         method: resource.method,
                         parameters: resource.parameters,
                         encoding: resource.encoding,
                         headers: headers)
                .debugLog()
                .response(completionHandler: responseHandler)
        }
    }
}

fileprivate func validate(response: DefaultDataResponse) throws -> Data? {
    if let error = response.error {
        throw error
    }
    
    guard let httpResponse = response.response else {
        throw BackendError.applicationError
    }
    
    switch httpResponse.statusCode {
    case 400..<500:
        guard let data = response.data else { throw BackendError.applicationError }
        
        guard let error = ServerError(json: JSON(data: data)) else {
            throw BackendError.applicationError
        }
        
        throw BackendError.serverError(error)
    case 200..<300:
        return response.data
    default:
        throw BackendError.applicationError
    }
}
