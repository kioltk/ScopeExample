//
//  ViewController.swift
//  ScopeExamle
//
//  Created by David on 28/02/2019.
//  Copyright © 2019 JesusCodes. All rights reserved.
//

import UIKit
import RxSwift
import RxDataSources
import RxCocoa
import Alamofire

class ViewController: UIViewController {

    @IBOutlet var activationButton: UIButton!
    
    @IBOutlet var catsTable: UITableView!
    
    var enabled = true
    let disposeBag = DisposeBag()
    override func viewDidLoad() {
        super.viewDidLoad()
        let stringURL = "https://api.thecatapi.com/v1/images/search?size=full&limit=1"
        
        // MARK: URLSession simple and fast
        let session = URLSession.shared
        
        activationButton.rx.tap
            .subscribe(onNext: {
                self.enabled = !self.enabled
                self.activationButton.setTitle(self.enabled ? "Loading" : "Paused", for: .normal)
            })
            .disposed(by: disposeBag)


        Observable<Int>.interval(2.0, scheduler: MainScheduler.instance)
            .filter({ (interval) -> Bool in
                self.enabled
            })
            .flatMap { (interval) -> Observable<Any> in
                session.rx.json(url: URL(string: stringURL + "&page=\(interval / 2)")!)
            }
            .scan([], accumulator: { (cats, moreCats) -> [Cat] in
                
                var cats = cats
                if let parsed = moreCats as? [[String:Any]] {
                    let cet = parsed[0]
                    cats.append(Cat(id:cet["id"] as? String, photo: cet["url"] as? String))
                }
                
                return cats
            })
            
            .observeOn(MainScheduler.instance)
            .startWith([])
            
            .bind(to: catsTable.rx.items(cellIdentifier: "Cat")) { index, cat, cell in
                cell.textLabel?.text = cat.id
                if let photo = cat.photo {
                    do {
                    cell.imageView?.image = UIImage(data: try Data(contentsOf: URL(string:photo)!))
                    } catch {
                        
                    }
                }
            }
            .disposed(by: disposeBag)
        
    }


}
struct Cat {
    let id:String?
    let photo:String?
}

extension Reactive where Base: URLSession {
    public func response(request: URLRequest) -> Observable<(Data, HTTPURLResponse)> {
        return Observable.create { observer in
            let task = self.base.dataTask(with: request) { (data, response, error) in
                
                guard let response = response, let data = data else {
                    observer.on(.error(error ?? RxCocoaURLError.unknown))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    observer.on(.error(RxCocoaURLError.nonHTTPResponse(response: response)))
                    return
                }
                
                observer.on(.next((data, httpResponse)))
                observer.on(.completed)
            }
            
            task.resume()
            
            return Disposables.create(with: task.cancel)
        }
    }
}
