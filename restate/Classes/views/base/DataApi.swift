//
//  DataApi.swift
//  SampleApp
//
//  Created by Gabriel Mori Baleta on 7/29/21.
//

import Foundation
import RxSwift

protocol APIRequest {
    var method: RequestType { get }
    var path: String { get }
    var parameters: [String : String] { get }
}

public enum RequestType: String {
    case GET, POST
}

extension APIRequest {
    func request(with baseURL: URL) -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            fatalError("Unable to create URL components")
        }

        components.queryItems = parameters.map {
            URLQueryItem(name: String($0), value: String($1))
        }

        guard let url = components.url else {
            fatalError("Could not get url")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}


class UniversityRequest: APIRequest {
    var method = RequestType.GET
    var path = "search"
    var parameters = [String: String]()

    init(name: String) {
        parameters["name"] = name
    }
}


class APIClient {
    
    private static let apiKey = "c0116267d97147c4bb467508c813199a"
    
    private let baseURL = URL(string: "https://newsapi.org/v2/top-headlines?country=us&apiKey=\(apiKey)")!

    func send<T: Codable>(apiRequest: APIRequest) -> Observable<T> {
        let request = apiRequest.request(with: baseURL)
        return URLSession.shared.rx.data(request: request)
            .map {
                try JSONDecoder().decode(T.self, from: $0)
            }.observe(on: MainScheduler.asyncInstance)
    }
}
